'use strict';

const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');
const { AllocationService } = require('./allocation.service');
const { CycleRepository } = require('../repositories/cycle.repository');
const { FinanceRepository } = require('../repositories/finance.repository');

const POLICY_VERSION = '1.0';
const CALCULATION_VERSION = '1.0';

function lastDayOfMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function clampDay(day, year, month) {
  return Math.min(day, lastDayOfMonth(year, month));
}

function computeCycleDates(paymentDay, today) {
  const y = today.getUTCFullYear();
  const m = today.getUTCMonth() + 1;

  const candidateDay = clampDay(paymentDay, y, m);
  const candidate = new Date(Date.UTC(y, m - 1, candidateDay));

  let startDate;
  if (candidate <= today) {
    startDate = candidate;
  } else {
    let prevYear = y;
    let prevMonth = m - 1;
    if (prevMonth === 0) { prevMonth = 12; prevYear -= 1; }
    const prevDay = clampDay(paymentDay, prevYear, prevMonth);
    startDate = new Date(Date.UTC(prevYear, prevMonth - 1, prevDay));
  }

  const nextYear = startDate.getUTCMonth() === 11 ? startDate.getUTCFullYear() + 1 : startDate.getUTCFullYear();
  const nextMonth = (startDate.getUTCMonth() + 1) % 12 + 1;
  const nextDay = clampDay(paymentDay, nextYear, nextMonth);
  const nextDate = new Date(Date.UTC(nextYear, nextMonth - 1, nextDay));

  const endDate = new Date(nextDate);
  endDate.setUTCDate(endDate.getUTCDate() - 1);

  return { startDate, endDate };
}

function toMySQLDate(date) {
  return date.toISOString().split('T')[0];
}

function getTodayInTimezone(timezone, now = new Date()) {
  if (!timezone || typeof timezone !== 'string' || timezone.trim() === '') {
    throw new AppError('Timezone must be a non-empty string', 422, 'INVALID_TIMEZONE');
  }
  let formatter;
  try {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: 'numeric',
      day: 'numeric'
    });
  } catch (err) {
    throw new AppError('Invalid timezone', 422, 'INVALID_TIMEZONE');
  }

  const parts = formatter.formatToParts(now);
  const year = parseInt(parts.find(p => p.type === 'year').value, 10);
  const month = parseInt(parts.find(p => p.type === 'month').value, 10);
  const day = parseInt(parts.find(p => p.type === 'day').value, 10);

  return new Date(Date.UTC(year, month - 1, day));
}

function generateCommitmentDueDates({ nextDueDate, frequency, cycleStart, cycleEnd }) {
  if (!nextDueDate) return [];

  const start = new Date(cycleStart);
  const end = new Date(cycleEnd);
  let current = new Date(nextDueDate);
  if (isNaN(current.getTime())) {
    throw new AppError('Invalid next_due_date', 500, 'COMMITMENT_DUE_DATE_MISSING');
  }

  const originalDay = current.getUTCDate();
  let monthOffset = 0;
  const originalYear = current.getUTCFullYear();
  const originalMonth = current.getUTCMonth();

  const results = [];
  let iterations = 0;

  while (current <= end) {
    if (iterations++ > 100) throw new AppError('Too many occurrences generated', 500, 'INTERNAL_ERROR');

    if (current >= start) {
      results.push(current.toISOString().split('T')[0]);
    }

    if (frequency === 'weekly') {
      current.setUTCDate(current.getUTCDate() + 7);
    } else if (frequency === 'monthly') {
      monthOffset += 1;
      const targetMonth = originalMonth + monthOffset;
      const targetYear = originalYear + Math.floor(targetMonth / 12);
      const normalizedMonth = ((targetMonth % 12) + 12) % 12;
      const clampedDay = clampDay(originalDay, targetYear, normalizedMonth + 1);
      current = new Date(Date.UTC(targetYear, normalizedMonth, clampedDay));
    } else if (frequency === 'quarterly') {
      monthOffset += 3;
      const targetMonth = originalMonth + monthOffset;
      const targetYear = originalYear + Math.floor(targetMonth / 12);
      const normalizedMonth = ((targetMonth % 12) + 12) % 12;
      const clampedDay = clampDay(originalDay, targetYear, normalizedMonth + 1);
      current = new Date(Date.UTC(targetYear, normalizedMonth, clampedDay));
    } else if (frequency === 'yearly') {
      monthOffset += 12;
      const targetMonth = originalMonth + monthOffset;
      const targetYear = originalYear + Math.floor(targetMonth / 12);
      const normalizedMonth = ((targetMonth % 12) + 12) % 12;
      const clampedDay = clampDay(originalDay, targetYear, normalizedMonth + 1);
      current = new Date(Date.UTC(targetYear, normalizedMonth, clampedDay));
    } else {
      throw new AppError('Unsupported commitment frequency', 422, 'UNSUPPORTED_COMMITMENT_FREQUENCY');
    }
  }

  return results;
}

function resolveAllocationBps(income, allocationPref) {
  if (allocationPref) {
    const nNeeds = Number(allocationPref.needs_bps);
    const nWants = Number(allocationPref.wants_bps);
    const nSavings = Number(allocationPref.savings_bps);

    if (!Number.isSafeInteger(nNeeds) || nNeeds < 0 ||
      !Number.isSafeInteger(nWants) || nWants < 0 ||
      !Number.isSafeInteger(nSavings) || nSavings < 0) {
      throw new AppError('Allocation preference BPS must be non-negative integers', 500, 'INVALID_PREF_BPS');
    }
    if (nNeeds + nWants + nSavings !== 10000) {
      throw new AppError('Allocation preference BPS must sum to 10000', 500, 'INVALID_PREF_BPS_SUM');
    }

    const { tier, tierCode } = AllocationService.calculateTierAndBps(income);

    const allowedSources = ['user_adjusted', 'transition_plan', 'system_tier'];
    let source = allocationPref.source;
    if (!allowedSources.includes(source)) {
      source = 'user_adjusted';
    }

    return {
      needsBps: nNeeds,
      wantsBps: nWants,
      savingsBps: nSavings,
      source: source,
      tierCode: tierCode || tier,
      tierLabel: tier
    };
  }

  const { tier, needs_bps, wants_bps, savings_bps } = AllocationService.calculateTierAndBps(income);

  return {
    needsBps: needs_bps,
    wantsBps: wants_bps,
    savingsBps: savings_bps,
    source: 'system_tier',
    tierCode: tier,
    tierLabel: tier
  };
}

function shapeCycleResponse(row) {
  if (!row) return null;
  return {
    id: Number(row.id),
    userId: Number(row.user_id),
    startDate: row.start_date,
    endDate: row.end_date,
    status: row.status,
    expectedIncome: Number(row.expected_income || 0),
    policyVersion: row.policy_version,
    createdAt: row.created_at,
    snapshot: row.allocation_base_income != null ? {
      allocationBaseIncome: Number(row.allocation_base_income),
      tierCode: row.tier_code,
      tierLabel: row.tier_label,
      allocationSource: row.allocation_source,
      needsBps: Number(row.needs_bps),
      wantsBps: Number(row.wants_bps),
      savingsBps: Number(row.savings_bps),
      needsTarget: Number(row.needs_target),
      wantsTarget: Number(row.wants_target),
      savingsTarget: Number(row.savings_target),
      policyVersion: row.snapshot_policy_version || row.policy_version,
      calculationVersion: row.calculation_version,
    } : null,
  };
}

class CycleService {
  static async createCycle(userId, { idempotencyKey } = {}) {
    let finalIdempotencyKey = null;
    if (idempotencyKey !== undefined && idempotencyKey !== null) {
      if (typeof idempotencyKey !== 'string') {
        throw new AppError('idempotencyKey must be a string', 400, 'INVALID_IDEMPOTENCY_KEY');
      }
      finalIdempotencyKey = idempotencyKey.trim();
      if (finalIdempotencyKey.length < 8 || finalIdempotencyKey.length > 128) {
        throw new AppError('idempotencyKey length must be between 8 and 128 characters', 400, 'INVALID_IDEMPOTENCY_KEY');
      }
    }

    const conn = await db.getConnection();
    let transactionFinished = false;
    try {
      await conn.beginTransaction();

      if (finalIdempotencyKey) {
        const existing = await CycleRepository.findCycleByIdempotencyKey(
          conn, userId, finalIdempotencyKey
        );
        if (existing) {
          await conn.rollback();
          transactionFinished = true;
          const full = await CycleRepository.findCycleById(null, userId, existing.id);
          return { cycle: shapeCycleResponse(full), replayed: true };
        }
      }

      const profile = await CycleRepository.lockFinancialProfile(conn, userId);
      if (!profile) {
        throw new AppError('Financial profile not found.', 422, 'PROFILE_NOT_FOUND');
      }

      const income = AllocationService.normalizeIncome(
        profile.expected_monthly_income
      );

      const paymentDay = Number(profile.payment_day);
      if (!Number.isSafeInteger(paymentDay) || paymentDay < 1 || paymentDay > 31) {
        throw new AppError('payment_day must be set between 1 and 31', 422, 'PAYMENT_DAY_NOT_SET');
      }

      let tz = profile.timezone;
      if (!tz || typeof tz !== 'string' || tz.trim() === '') {
        tz = 'Asia/Amman';
      }

      const openCycle = await CycleRepository.findOpenCycle(conn, userId);
      if (openCycle) {
        throw new AppError('An open cycle already exists.', 409, 'CYCLE_ALREADY_OPEN');
      }

      const allocationPref = await CycleRepository.lockAllocationPreference(conn, userId);

      const { needsBps, wantsBps, savingsBps, source, tierCode, tierLabel } =
        resolveAllocationBps(income, allocationPref);

      if (needsBps + wantsBps + savingsBps !== 10000) {
        throw new AppError(`BPS values do not sum to 10000 (got ${needsBps + wantsBps + savingsBps}).`, 500, 'BPS_INVARIANT_VIOLATED');
      }

      const { needsAmount, wantsAmount, savingsAmount } =
        AllocationService.calculateAmounts(income, needsBps, wantsBps, savingsBps);

      if (needsAmount + wantsAmount + savingsAmount !== income) {
        throw new AppError(`Target amounts do not sum to income.`, 500, 'TARGET_INVARIANT_VIOLATED');
      }

      const todayMidnight = getTodayInTimezone(tz, new Date());
      const { startDate, endDate } = computeCycleDates(paymentDay, todayMidnight);

      const cycleId = await CycleRepository.createCycle(conn, {
        userId,
        startDate: toMySQLDate(startDate),
        endDate: toMySQLDate(endDate),
        expectedIncome: income,
        policyVersion: POLICY_VERSION,
        idempotencyKey: finalIdempotencyKey,
      });

      await CycleRepository.createSnapshot(conn, {
        cycleId,
        allocationBaseIncome: income,
        tierCode,
        tierLabel,
        allocationSource: source,
        needsBps,
        wantsBps,
        savingsBps,
        needsTarget: needsAmount,
        wantsTarget: wantsAmount,
        savingsTarget: savingsAmount,
        policyVersion: POLICY_VERSION,
        calculationVersion: CALCULATION_VERSION,
      });

      const activeCommitments = await FinanceRepository.getActiveCommitmentsForUser(conn, userId);
      for (const commitment of activeCommitments) {
        if (!commitment.next_due_date) {
          throw new AppError('Commitment is missing next_due_date', 500, 'COMMITMENT_DUE_DATE_MISSING');
        }
        const dates = generateCommitmentDueDates({
          nextDueDate: commitment.next_due_date,
          frequency: commitment.frequency,
          cycleStart: startDate,
          cycleEnd: endDate
        });

        for (const dueDateStr of dates) {
          await FinanceRepository.createOccurrence(conn, {
            commitmentId: commitment.id,
            cycleId,
            dueDate: dueDateStr,
            amount: commitment.amount,
            status: 'upcoming'
          });
        }
      }

      await conn.commit();
      transactionFinished = true;

      const full = await CycleRepository.findCycleById(null, userId, cycleId);
      return { cycle: shapeCycleResponse(full), replayed: false };

    } catch (err) {
      if (!transactionFinished) {
        await conn.rollback();
      }

      if (err.code === 'ER_DUP_ENTRY') {
        if (err.message.includes('uq_one_open_cycle_per_user')) {
          throw new AppError('An open cycle already exists (concurrent creation detected).', 409, 'CYCLE_ALREADY_OPEN');
        }
        if (err.message.includes('uq_cycles_user_idempotency')) {
          const existing = await CycleRepository.findCycleByIdempotencyKey(db, userId, finalIdempotencyKey);
          if (existing) {
            const full = await CycleRepository.findCycleById(null, userId, existing.id);
            return { cycle: shapeCycleResponse(full), replayed: true };
          }
        }
      }

      throw err;
    } finally {
      conn.release();
    }
  }

  static async getCurrentCycle(userId) {
    const row = await CycleRepository.findCurrentCycle(null, userId);
    if (!row) {
      throw new AppError('No open cycle found.', 404, 'CYCLE_NOT_FOUND');
    }
    return shapeCycleResponse(row);
  }

  static async getCycleById(userId, cycleId) {
    const row = await CycleRepository.findCycleById(null, userId, cycleId);
    if (!row) {
      throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
    }
    return shapeCycleResponse(row);
  }
}

module.exports = { CycleService, computeCycleDates, getTodayInTimezone, generateCommitmentDueDates, resolveAllocationBps, POLICY_VERSION, CALCULATION_VERSION };
