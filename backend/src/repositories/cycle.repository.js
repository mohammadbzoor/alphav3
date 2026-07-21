/**
 * CycleRepository – all DB access for financial_cycles and
 * cycle_allocation_snapshots.
 *
 * Rules enforced here:
 *   - Every mutating method that must be atomic receives an open `connection`
 *     so the caller owns the transaction boundary.
 *   - Read-only helpers accept an optional connection; they fall back to the
 *     pool when none is supplied so they can also be called outside a
 *     transaction (e.g. GET endpoints).
 *   - Snapshot rows are never updated or deleted through this repository.
 *     The DB triggers installed by migration 014 provide a second line of
 *     defence.
 */

'use strict';

const { db } = require('../config/database');

class CycleRepository {
  // ------------------------------------------------------------------ //
  // financial_cycles – reads                                            //
  // ------------------------------------------------------------------ //

  /**
   * Lock the user's financial_profile row for UPDATE inside a transaction.
   * Returns the profile row or null if not found.
   */
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

  /**
   * Read the approved allocation preference for a user (no lock needed for
   * snapshot purposes – the value is captured into the snapshot immediately).
   */
  static async getAllocationPreference(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT needs_bps, wants_bps, savings_bps, source, based_on_income
         FROM allocation_preferences
        WHERE user_id = ?`,
      [userId]
    );
    return rows[0] || null;
  }

  /**
   * Return the current open cycle for a user, or null.
   * Uses the pool when no connection is passed.
   */
  static async findOpenCycle(connOrNull, userId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT id, user_id, start_date, end_date, status,
              expected_income, policy_version, created_at, idempotency_key
         FROM financial_cycles
        WHERE user_id = ? AND status = 'open'
        LIMIT 1`,
      [userId]
    );
    return rows[0] || null;
  }

  /**
   * Return any cycle by id, scoped to the authenticated user.
   */
  static async findCycleById(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT fc.id, fc.user_id, fc.start_date, fc.end_date, fc.status,
              fc.expected_income, fc.policy_version, fc.created_at,
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

  /**
   * Return current open cycle with its snapshot joined, scoped to user.
   */
  static async findCurrentCycle(userId) {
    const [rows] = await db.execute(
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
        LIMIT 1`,
      [userId]
    );
    return rows[0] || null;
  }

  /**
   * Check whether an idempotency key has already been committed for this user.
   * Returns the existing cycle row or null.
   */
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

  // ------------------------------------------------------------------ //
  // financial_cycles – writes                                           //
  // ------------------------------------------------------------------ //

  /**
   * Insert a new financial_cycle row inside an open transaction.
   * Returns the insertId.
   */
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

  // ------------------------------------------------------------------ //
  // cycle_allocation_snapshots – write (create only, never update/delete)
  // ------------------------------------------------------------------ //

  /**
   * Insert the immutable allocation snapshot for a cycle.
   * Must be called inside the same transaction as createCycle.
   */
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

  /**
   * Read the snapshot for a given cycle (read-only, uses pool).
   * Returns null when no snapshot exists (should never happen for open cycles).
   */
  static async findSnapshotByCycleId(cycleId) {
    const [rows] = await db.execute(
      `SELECT * FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
      [cycleId]
    );
    return rows[0] || null;
  }
}

module.exports = { CycleRepository };
