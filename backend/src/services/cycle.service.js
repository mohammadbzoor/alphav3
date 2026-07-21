/**
 * CycleService – Phase 3A.1
 *
 * Implements:
 *   - createCycle()      POST /financial-cycles
 *   - getCurrentCycle()  GET  /financial-cycles/current
 *   - getCycleById()     GET  /financial-cycles/:id
 *
 * Cycle-date rule
 * ---------------
 * Given payment_day D and "today" (UTC date of the request):
 *
 *   cycleStart = the most recent occurrence of day-D that is ≤ today.
 *                If today IS day-D → start = today.
 *                If today is after day-D in the current month → start = day-D this month.
 *                If today is before day-D in the current month → start = day-D in the previous month.
 *                Months shorter than D clamp to the last day of that month.
 *
 *   cycleEnd   = the day immediately before the NEXT occurrence of day-D after cycleStart.
 *                i.e. nextPaymentDate - 1 day (both stored at 00:00:00 UTC).
 *
 * Invariants enforced before INSERT:
 *   needsBps + wantsBps + savingsBps === 10 000
 *   needsTarget + wantsTarget + savingsTarget === allocationBaseIncome
 */

'use strict';

const { db }              = require('../config/database');
const { AppError }        = require('../utils/app-error');
const { AllocationService } = require('./allocation.service');
const { CycleRepository }   = require('../repositories/cycle.repository');
const { FinanceRepository } = require('../repositories/finance.repository');

// Versions stamped into every snapshot row
const POLICY_VERSION      = '1.0';
const CALCULATION_VERSION = '1.0';

// ─────────────────────────────────────────────────────────────────────────── //
// Pure date helpers (no I/O, fully testable)                                  //
// ─────────────────────────────────────────────────────────────────────────── //

/**
 * Return the last valid calendar day for a given year/month (1-based).
 * e.g. lastDayOfMonth(2024, 2) → 29
 */
function lastDayOfMonth(year, month) {
  // Day 0 of month+1 = last day of month
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/**
 * Clamp a payment_day to the actual last day of the given month when the
 * month is shorter than the configured day (e.g. day=31 in February → 28/29).
 */
function clampDay(day, year, month) {
  return Math.min(day, lastDayOfMonth(year, month));
}

/**
 * Given a payment_day (1–31) and a reference UTC Date ("today"), compute:
 *   { startDate, endDate }  – both as UTC Date objects at 00:00:00.
 *
 * Algorithm:
 *   1. Try placing day-D in the current month (clamped).
 *      - If that date ≤ today → cycleStart = that date.
 *      - Else → move one month back and place day-D there (clamped).
 *   2. Next payment date = one month after cycleStart, using the *original*
 *      payment_day (not the clamped one), clamped to that future month.
 *   3. cycleEnd = nextPaymentDate - 1 day.
 */
function computeCycleDates(paymentDay, today) {
  const y = today.getUTCFullYear();
  const m = today.getUTCMonth() + 1; // 1-based

  // Candidate: day-D in the current month
  const candidateDay = clampDay(paymentDay, y, m);
  const candidate = new Date(Date.UTC(y, m - 1, candidateDay));

  let startDate;
  if (candidate <= today) {
    startDate = candidate;
  } else {
    // Go back one calendar month
    let prevYear  = y;
    let prevMonth = m - 1;
    if (prevMonth === 0) { prevMonth = 12; prevYear -= 1; }
    const prevDay = clampDay(paymentDay, prevYear, prevMonth);
    startDate = new Date(Date.UTC(prevYear, prevMonth - 1, prevDay));
  }

  // Next occurrence: one calendar month after startDate, using original day
  const nextYear  = startDate.getUTCMonth() === 11
    ? startDate.getUTCFullYear() + 1
    : startDate.getUTCFullYear();
  const nextMonth = (startDate.getUTCMonth() + 1) % 12 + 1; // 1-based
  const nextDay   = clampDay(paymentDay, nextYear, nextMonth);
  const nextDate  = new Date(Date.UTC(nextYear, nextMonth - 1, nextDay));

  // endDate = one day before next payment date
  const endDate = new Date(nextDate);
  endDate.setUTCDate(endDate.getUTCDate() - 1);

  return { startDate, endDate };
}

/**
 * Format a JS Date to MySQL DATETIME string 'YYYY-MM-DD HH:MM:SS'.
 */
function toMySQLDatetime(date) {
  return date.toISOString().replace('T', ' ').slice(0, 19);
}

// ─────────────────────────────────────────────────────────────────────────── //
// Allocation helpers                                                           //
// ─────────────────────────────────────────────────────────────────────────── //

/**
 * Resolve the BPS split to use for a new cycle.
 *
 * Priority:
 *   1. If an approved allocation_preference row exists → user_adjusted (or
 *      transition_plan) source; use its bps directly.
 *   2. Otherwise derive tier defaults from income via AllocationService.
 *
 * Returns: { needsBps, wantsBps, savingsBps, source, tierCode, tierLabel }
 */
function resolveAllocationBps(income, allocationPref) {
  if (allocationPref) {
    const { tier, needs_bps: tn, wants_bps: tw, savings_bps: ts } =
      AllocationService.calculateTierAndBps(income);

    return {
      needsBps:  allocationPref.needs_bps,
      wantsBps:  allocationPref.wants_bps,
      savingsBps: allocationPref.savings_bps,
      source:    allocationPref.source,       // 'user_adjusted' | 'transition_plan'
      tierCode:  tier,
      tierLabel: tier,
    };
  }

  // Derive from tier
  const { tier, needs_bps, wants_bps, savings_bps } =
    AllocationService.calculateTierAndBps(income);

  return {
    needsBps:  needs_bps,
    wantsBps:  wants_bps,
    savingsBps: savings_bps,
    source:    'system_tier',
    tierCode:  tier,
    tierLabel: tier,
  };
}

// ─────────────────────────────────────────────────────────────────────────── //
// Response shaper                                                              //
// ─────────────────────────────────────────────────────────────────────────── //

function shapeCycleResponse(row) {
  if (!row) return null;
  return {
    id:           Number(row.id),
    userId:       Number(row.user_id),
    startDate:    row.start_date,
    endDate:      row.end_date,
    status:       row.status,
    expectedIncome: Number(row.expected_income || 0),
    policyVersion:  row.policy_version,
    createdAt:    row.created_at,
    snapshot: row.allocation_base_income != null ? {
      allocationBaseIncome: Number(row.allocation_base_income),
      tierCode:    row.tier_code,
      tierLabel:   row.tier_label,
      allocationSource: row.allocation_source,
      needsBps:    Number(row.needs_bps),
      wantsBps:    Number(row.wants_bps),
      savingsBps:  Number(row.savings_bps),
      needsTarget:   Number(row.needs_target),
      wantsTarget:   Number(row.wants_target),
      savingsTarget: Number(row.savings_target),
      policyVersion:      row.snapshot_policy_version || row.policy_version,
      calculationVersion: row.calculation_version,
    } : null,
  };
}

// ─────────────────────────────────────────────────────────────────────────── //
// Service methods                                                              //
// ─────────────────────────────────────────────────────────────────────────── //

class CycleService {
  /**
   * POST /financial-cycles
   *
   * Creates one open cycle + one immutable snapshot in a single transaction.
   * Idempotency: if idempotencyKey is supplied and a committed cycle already
   * carries it for this user, the existing cycle is returned (HTTP 200 with
   * replayed=true).
   * Concurrency: the unique index uq_one_open_cycle_per_user (on generated
   * column open_user_id) plus the FOR UPDATE lock on financial_profiles
   * ensures at most one open cycle per user even under concurrent requests.
   */
  static async createCycle(userId, { idempotencyKey } = {}) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // ── Step 1: Idempotency pre-check ─────────────────────────────── //
      if (idempotencyKey) {
        const existing = await CycleRepository.findCycleByIdempotencyKey(
          conn, userId, idempotencyKey
        );
        if (existing) {
          await conn.rollback();
          const full = await CycleRepository.findCycleById(userId, existing.id);
          return { cycle: shapeCycleResponse(full), replayed: true };
        }
      }

      // ── Step 2: Lock financial_profile (serialises concurrent requests) //
      const profile = await CycleRepository.lockFinancialProfile(conn, userId);
      if (!profile) {
        throw new AppError(
          'Financial profile not found. Complete onboarding before creating a cycle.',
          422,
          'PROFILE_NOT_FOUND'
        );
      }

      const income     = Number(profile.expected_monthly_income || 0);
      const paymentDay = profile.payment_day;

      if (!paymentDay || paymentDay < 1 || paymentDay > 31) {
        throw new AppError(
          'payment_day must be set on your financial profile (1–31) before creating a cycle.',
          422,
          'PAYMENT_DAY_NOT_SET'
        );
      }

      if (income <= 0) {
        throw new AppError(
          'expected_monthly_income must be greater than zero before creating a cycle.',
          422,
          'INCOME_NOT_SET'
        );
      }

      // ── Step 3: Reject if an open cycle already exists ────────────── //
      const openCycle = await CycleRepository.findOpenCycle(conn, userId);
      if (openCycle) {
        throw new AppError(
          'An open cycle already exists. Close the current cycle before creating a new one.',
          409,
          'CYCLE_ALREADY_OPEN'
        );
      }

      // ── Step 4: Read allocation preference ────────────────────────── //
      const allocationPref = await CycleRepository.getAllocationPreference(conn, userId);

      // ── Step 5 & 6: Resolve BPS + calculate targets (Largest Remainder) //
      const { needsBps, wantsBps, savingsBps, source, tierCode, tierLabel } =
        resolveAllocationBps(income, allocationPref);

      // Invariant guard (belt-and-suspenders; DB CHECK also enforces this)
      if (needsBps + wantsBps + savingsBps !== 10000) {
        throw new AppError(
          `BPS values do not sum to 10000 (got ${needsBps + wantsBps + savingsBps}).`,
          500,
          'BPS_INVARIANT_VIOLATED'
        );
      }

      const { needsAmount, wantsAmount, savingsAmount } =
        AllocationService.calculateAmounts(income, needsBps, wantsBps, savingsBps);

      // Invariant guard for targets
      if (needsAmount + wantsAmount + savingsAmount !== income) {
        throw new AppError(
          `Target amounts do not sum to income (${needsAmount}+${wantsAmount}+${savingsAmount} ≠ ${income}).`,
          500,
          'TARGET_INVARIANT_VIOLATED'
        );
      }

      // ── Step 7: Compute cycle dates ───────────────────────────────── //
      const today = new Date();
      // Strip time to midnight UTC for deterministic boundary
      const todayMidnight = new Date(Date.UTC(
        today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()
      ));
      const { startDate, endDate } = computeCycleDates(paymentDay, todayMidnight);

      // ── Step 8: Insert financial_cycle ────────────────────────────── //
      const cycleId = await CycleRepository.createCycle(conn, {
        userId,
        startDate:      toMySQLDatetime(startDate),
        endDate:        toMySQLDatetime(endDate),
        expectedIncome: income,
        policyVersion:  POLICY_VERSION,
        idempotencyKey: idempotencyKey || null,
      });

      // ── Step 9: Insert immutable snapshot ─────────────────────────── //
      await CycleRepository.createSnapshot(conn, {
        cycleId,
        allocationBaseIncome: income,
        tierCode,
        tierLabel,
        allocationSource:    source,
        needsBps,
        wantsBps,
        savingsBps,
        needsTarget:   needsAmount,
        wantsTarget:   wantsAmount,
        savingsTarget: savingsAmount,
        policyVersion:      POLICY_VERSION,
        calculationVersion: CALCULATION_VERSION,
      });

      // ── Step 9.5: Generate commitment occurrences for this cycle ────── //
      const activeCommitments = await FinanceRepository.getActiveCommitmentsForUser(conn, userId);
      for (const commitment of activeCommitments) {
        // Calculate due date based on cycle start date and commitment frequency
        // For monthly commitments, use the cycle start date's day of month
        const cycleStart = new Date(startDate);
        const dueDate = new Date(cycleStart);
        dueDate.setUTCDate(commitment.next_due_date ? new Date(commitment.next_due_date).getUTCDate() : 1);
        // Format as YYYY-MM-DD
        const dueDateStr = dueDate.toISOString().split('T')[0];

        await FinanceRepository.createOccurrence(conn, {
          commitmentId: commitment.id,
          cycleId,
          dueDate: dueDateStr,
          amount: commitment.amount,
          status: 'upcoming'
        });
      }

      // ── Step 10: Commit ───────────────────────────────────────────── //
      await conn.commit();

      const full = await CycleRepository.findCycleById(userId, cycleId);
      return { cycle: shapeCycleResponse(full), replayed: false };

    } catch (err) {
      await conn.rollback();

      // MySQL duplicate-key on uq_one_open_cycle_per_user (concurrent race)
      if (err.code === 'ER_DUP_ENTRY') {
        if (err.message.includes('uq_one_open_cycle_per_user')) {
          throw new AppError(
            'An open cycle already exists (concurrent creation detected).',
            409,
            'CYCLE_ALREADY_OPEN'
          );
        }
        if (err.message.includes('uq_cycles_user_idempotency')) {
          // Another request committed the same idempotency key concurrently.
          // Re-fetch and return the committed cycle as a replay.
          const existing = await CycleRepository.findCycleByIdempotencyKey(
            db, userId, idempotencyKey
          );
          if (existing) {
            const full = await CycleRepository.findCycleById(userId, existing.id);
            return { cycle: shapeCycleResponse(full), replayed: true };
          }
        }
      }

      throw err;
    } finally {
      conn.release();
    }
  }

  /**
   * GET /financial-cycles/current
   */
  static async getCurrentCycle(userId) {
    const row = await CycleRepository.findCurrentCycle(userId);
    if (!row) {
      throw new AppError('No open cycle found.', 404, 'CYCLE_NOT_FOUND');
    }
    return shapeCycleResponse(row);
  }

  /**
   * GET /financial-cycles/:id
   */
  static async getCycleById(userId, cycleId) {
    const row = await CycleRepository.findCycleById(userId, cycleId);
    if (!row) {
      throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
    }
    return shapeCycleResponse(row);
  }
}

module.exports = { CycleService, computeCycleDates, resolveAllocationBps, POLICY_VERSION, CALCULATION_VERSION };
