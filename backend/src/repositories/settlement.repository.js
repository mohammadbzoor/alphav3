/**
 * SettlementRepository – all DB access for cycle settlements and settlement actions
 *
 * Rules enforced here:
 *   - Every mutating method that must be atomic receives an open `connection`
 *     so the caller owns the transaction boundary.
 *   - Read-only helpers accept an optional connection; they fall back to the
 *     pool when none is supplied.
 *   - Settlement records are never deleted, only created and updated.
 *   - Settlement actions are never deleted (no cascade).
 */

'use strict';

const { db } = require('../config/database');

class SettlementRepository {
  // ------------------------------------------------------------------ //
  // Settlement reads                                                     //
  // ------------------------------------------------------------------ //

  /**
   * Lock the user's open cycle for UPDATE inside a transaction.
   * Returns the cycle row or null if not found.
   */
  static async lockOpenCycle(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, user_id, start_date, end_date, status, expected_income, closed_at
         FROM financial_cycles
        WHERE user_id = ? AND status = 'open'
          FOR UPDATE`,
      [userId]
    );
    return rows[0] || null;
  }

  /**
   * Lock the user's current cycle (open or settlement_pending) for UPDATE.
   * Used during close operation.
   */
  static async lockCurrentCycle(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, user_id, start_date, end_date, status, expected_income, closed_at
         FROM financial_cycles
        WHERE user_id = ? AND status IN ('open', 'settlement_pending')
          FOR UPDATE`,
      [userId]
    );
    return rows[0] || null;
  }

  /**
   * Lock a cycle by ID for UPDATE inside a transaction.
   * Used during settlement and closure.
   */
  static async lockCycleById(conn, userId, cycleId) {
    const [rows] = await conn.execute(
      `SELECT id, user_id, start_date, end_date, status, expected_income, closed_at
         FROM financial_cycles
        WHERE id = ? AND user_id = ?
          FOR UPDATE`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  /**
   * Find settlement by cycle ID.
   */
  static async findSettlementByCycleId(cycleId) {
    const [rows] = await db.execute(
      `SELECT * FROM cycle_settlements WHERE cycle_id = ?`,
      [cycleId]
    );
    return rows[0] || null;
  }

  /**
   * Lock settlement by cycle ID for UPDATE inside a transaction.
   */
  static async lockSettlementByCycleId(conn, cycleId) {
    const [rows] = await conn.execute(
      `SELECT * FROM cycle_settlements WHERE cycle_id = ? FOR UPDATE`,
      [cycleId]
    );
    return rows[0] || null;
  }

  /**
   * Get cycle snapshot for settlement calculations.
   */
  static async getCycleSnapshot(cycleId) {
    const [rows] = await db.execute(
      `SELECT needs_target, wants_target, savings_target
         FROM cycle_allocation_snapshots
        WHERE cycle_id = ?`,
      [cycleId]
    );
    return rows[0] || null;
  }

  /**
   * Get confirmed income transactions for a cycle.
   */
  static async getConfirmedIncomeByCycle(cycleId) {
    const [rows] = await db.execute(
      `SELECT income_kind, SUM(amount) as total
         FROM transactions
        WHERE cycle_id = ? AND transaction_type = 'income' AND status = 'confirmed'
        GROUP BY income_kind`,
      [cycleId]
    );
    return rows;
  }

  /**
   * Get confirmed expense transactions by bucket for a cycle.
   */
  static async getConfirmedExpensesByCycle(cycleId) {
    const [rows] = await db.execute(
      `SELECT budget_bucket, SUM(amount) as total
         FROM transactions
        WHERE cycle_id = ? AND transaction_type = 'expense' AND status = 'confirmed'
        GROUP BY budget_bucket`,
      [cycleId]
    );
    return rows;
  }

  /**
   * Get confirmed savings movements for a cycle.
   */
  static async getConfirmedSavingsByCycle(cycleId) {
    const [rows] = await db.execute(
      `SELECT SUM(amount) as total
         FROM transactions
        WHERE cycle_id = ? AND budget_bucket = 'savings' AND direction = 'outflow' AND status = 'confirmed'`,
      [cycleId]
    );
    return rows[0]?.total || 0;
  }

  /**
   * Get total confirmed external outflows for a cycle.
   * Excludes internal transfers, goal reallocations, and duplicate goal execution deductions.
   */
  static async getTotalConfirmedOutflowsByCycle(cycleId) {
    const [rows] = await db.execute(
      `SELECT SUM(amount) as total
         FROM transactions
        WHERE cycle_id = ? AND direction = 'outflow' AND status = 'confirmed'
          AND transaction_type IN ('expense', 'capital_expense')`,
      [cycleId]
    );
    return rows[0]?.total || 0;
  }

  /**
   * Get unpaid commitment occurrences for a cycle.
   */
  static async getUnpaidCommitmentsByCycle(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT co.id, co.amount, co.status, fc.name AS commitment_name
         FROM commitment_occurrences co
         JOIN financial_commitments fc ON fc.id = co.commitment_id
        WHERE co.cycle_id = ? AND fc.user_id = ? AND co.status IN ('upcoming', 'due', 'overdue')
        ORDER BY co.due_date ASC`,
      [cycleId, userId]
    );
    return rows;
  }

  /**
   * Get settlement actions for a settlement.
   */
  static async getSettlementActions(settlementId) {
    const [rows] = await db.execute(
      `SELECT * FROM settlement_actions WHERE settlement_id = ? ORDER BY id ASC`,
      [settlementId]
    );
    return rows;
  }

  // ------------------------------------------------------------------ //
  // Settlement writes                                                    //
  // ------------------------------------------------------------------ //

  /**
   * Create a pending settlement record.
   */
  static async createSettlement(conn, data) {
    const [result] = await conn.execute(
      `INSERT INTO cycle_settlements
         (cycle_id, expected_income, actual_recurring_income, unexpected_income,
          planned_needs, actual_needs, planned_wants, actual_wants,
          planned_savings, actual_savings, total_actual_outflows, surplus, deficit, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [
        data.cycleId,
        data.expectedIncome,
        data.actualRecurringIncome,
        data.unexpectedIncome,
        data.plannedNeeds,
        data.actualNeeds,
        data.plannedWants,
        data.actualWants,
        data.plannedSavings,
        data.actualSavings,
        data.totalActualOutflows,
        data.surplus,
        data.deficit
      ]
    );
    return result.insertId;
  }

  /**
   * Update cycle status to settlement_pending.
   */
  static async updateCycleStatusToPending(conn, cycleId) {
    await conn.execute(
      `UPDATE financial_cycles SET status = 'settlement_pending' WHERE id = ?`,
      [cycleId]
    );
  }

  /**
   * Update cycle status to closed and set closed_at.
   */
  static async updateCycleStatusToClosed(conn, cycleId) {
    await conn.execute(
      `UPDATE financial_cycles SET status = 'closed', closed_at = NOW() WHERE id = ?`,
      [cycleId]
    );
  }

  /**
   * Update settlement to approved status with timestamps.
   */
  static async approveSettlement(conn, settlementId) {
    await conn.execute(
      `UPDATE cycle_settlements
       SET status = 'approved', approved_at = NOW(), closed_at = NOW()
       WHERE id = ?`,
      [settlementId]
    );
  }

  /**
   * Create a settlement action.
   */
  static async createSettlementAction(conn, data) {
    const [result] = await conn.execute(
      `INSERT INTO settlement_actions
         (settlement_id, action_type, amount, target_goal_id, description)
       VALUES (?, ?, ?, ?, ?)`,
      [
        data.settlementId,
        data.actionType,
        data.amount,
        data.targetGoalId || null,
        data.description || null
      ]
    );
    return result.insertId;
  }

  /**
   * Find goal for update to verify ownership and status.
   */
  static async findGoalForUpdate(conn, goalId, userId) {
    const [rows] = await conn.execute(
      `SELECT * FROM goals WHERE id = ? AND user_id = ? FOR UPDATE`,
      [goalId, userId]
    );
    return rows[0] || null;
  }

  /**
   * Update goal balance for settlement allocation.
   */
  static async updateGoalBalance(conn, goalId, newBalance) {
    await conn.execute(
      `UPDATE goals SET current_balance = ? WHERE id = ?`,
      [newBalance, goalId]
    );
  }

  /**
   * Create a goal transaction for settlement allocation.
   */
  static async createGoalTransaction(conn, data) {
    const [result] = await conn.execute(
      `INSERT INTO goal_transactions
         (user_id, goal_id, amount, transaction_type, description)
       VALUES (?, ?, ?, 'contribution', ?)`,
      [data.userId, data.goalId, data.amount, data.description]
    );
    return result.insertId;
  }

  /**
   * Create a savings transaction for emergency fund or unallocated savings.
   */
  static async createSavingsTransaction(conn, data) {
    const [result] = await conn.execute(
      `INSERT INTO transactions
         (user_id, cycle_id, amount, direction, transaction_type, budget_bucket,
          description, occurred_at, status, confirmed_at)
       VALUES (?, ?, ?, 'outflow', 'savings', 'savings', ?, NOW(), 'confirmed', NOW())`,
      [data.userId, data.cycleId, data.amount, data.description]
    );
    return result.insertId;
  }
}

module.exports = { SettlementRepository };
