'use strict';

const { db } = require('../config/database');

class CycleRepository {
  static async lockFinancialProfile(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, expected_monthly_income, payment_day, timezone, detected_tier
         FROM financial_profiles
        WHERE user_id = ?
          FOR UPDATE`,
      [userId]
    );
    return rows[0] || null;
  }

  static async lockAllocationPreference(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT needs_bps, wants_bps, savings_bps, source, based_on_income
         FROM allocation_preferences
        WHERE user_id = ?
          FOR UPDATE`,
      [userId]
    );
    return rows[0] || null;
  }

  static async getAllocationPreference(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT needs_bps, wants_bps, savings_bps, source, based_on_income
         FROM allocation_preferences
        WHERE user_id = ?`,
      [userId]
    );
    return rows[0] || null;
  }

  static async findOpenCycle(connOrNull, userId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT id, user_id, start_date, end_date, status,
              expected_income, policy_version, created_at, idempotency_key
         FROM financial_cycles
        WHERE user_id = ? AND status = 'open'
        ORDER BY start_date DESC, id DESC
        LIMIT 1`,
      [userId]
    );
    return rows[0] || null;
  }

  static async lockCycleById(conn, userId, cycleId) {
    const [rows] = await conn.execute(
      `SELECT id, user_id, start_date, end_date, status,
              expected_income, policy_version, created_at, closed_at, idempotency_key
         FROM financial_cycles
        WHERE id = ? AND user_id = ?
          FOR UPDATE`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  static async findCycleById(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT fc.id, fc.user_id, fc.start_date, fc.end_date, fc.status,
              fc.expected_income, fc.policy_version, fc.created_at, fc.closed_at,
              cas.allocation_base_income, cas.tier_code, cas.tier_label,
              cas.allocation_source, cas.needs_bps, cas.wants_bps, cas.savings_bps,
              cas.needs_target, cas.wants_target, cas.savings_target,
              cas.policy_version AS snapshot_policy_version,
              cas.calculation_version
         FROM financial_cycles fc
         LEFT JOIN cycle_allocation_snapshots cas ON cas.cycle_id = fc.id
        WHERE fc.id = ? AND fc.user_id = ?`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  static async findCurrentCycle(connOrNull, userId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT fc.id, fc.user_id, fc.start_date, fc.end_date, fc.status,
              fc.expected_income, fc.policy_version, fc.created_at,
              cas.allocation_base_income, cas.tier_code, cas.tier_label,
              cas.allocation_source, cas.needs_bps, cas.wants_bps, cas.savings_bps,
              cas.needs_target, cas.wants_target, cas.savings_target,
              cas.policy_version AS snapshot_policy_version,
              cas.calculation_version
         FROM financial_cycles fc
         LEFT JOIN cycle_allocation_snapshots cas ON cas.cycle_id = fc.id
        WHERE fc.user_id = ? AND fc.status = 'open'
        ORDER BY fc.start_date DESC, fc.id DESC
        LIMIT 1`,
      [userId]
    );
    return rows[0] || null;
  }

  static async findCycleByIdempotencyKey(conn, userId, idempotencyKey) {
    const [rows] = await conn.execute(
      `SELECT id, user_id, start_date, end_date, status,
              expected_income, policy_version, created_at, idempotency_key
         FROM financial_cycles
        WHERE user_id = ? AND idempotency_key = ?
        LIMIT 1`,
      [userId, idempotencyKey]
    );
    return rows[0] || null;
  }

  static async createCycle(conn, { userId, startDate, endDate, expectedIncome, policyVersion, idempotencyKey }) {
    const [result] = await conn.execute(
      `INSERT INTO financial_cycles
         (user_id, start_date, end_date, status, expected_income,
          policy_version, idempotency_key)
       VALUES (?, ?, ?, 'open', ?, ?, ?)`,
      [
        userId,
        startDate,
        endDate,
        expectedIncome,
        policyVersion,
        idempotencyKey || null,
      ]
    );
    return result.insertId;
  }

  static async createSnapshot(conn, {
    cycleId,
    allocationBaseIncome,
    tierCode,
    tierLabel,
    allocationSource,
    needsBps,
    wantsBps,
    savingsBps,
    needsTarget,
    wantsTarget,
    savingsTarget,
    policyVersion,
    calculationVersion,
  }) {
    const [result] = await conn.execute(
      `INSERT INTO cycle_allocation_snapshots
         (cycle_id, allocation_base_income, tier_code, tier_label,
          allocation_source, needs_bps, wants_bps, savings_bps,
          needs_target, wants_target, savings_target,
          policy_version, calculation_version)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        cycleId,
        allocationBaseIncome,
        tierCode || null,
        tierLabel || null,
        allocationSource,
        needsBps,
        wantsBps,
        savingsBps,
        needsTarget,
        wantsTarget,
        savingsTarget,
        policyVersion,
        calculationVersion,
      ]
    );
    return result.insertId;
  }

  static async findSnapshotByCycleId(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT cas.id, cas.cycle_id, cas.allocation_base_income, cas.tier_code,
              cas.tier_label, cas.allocation_source, cas.needs_bps, cas.wants_bps, cas.savings_bps,
              cas.needs_target, cas.wants_target, cas.savings_target,
              cas.policy_version, cas.calculation_version, cas.created_at
         FROM cycle_allocation_snapshots cas
         JOIN financial_cycles fc ON cas.cycle_id = fc.id
        WHERE cas.cycle_id = ? AND fc.user_id = ?`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }
}

module.exports = { CycleRepository };
