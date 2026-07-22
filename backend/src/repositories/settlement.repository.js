'use strict';

const { db } = require('../config/database');

class SettlementRepository {
  // ------------------------------------------------------------------ //
  // Settlement reads                                                     //
  // ------------------------------------------------------------------ //

  static async findOpenCycle(connOrNull, userId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT id, user_id, start_date, end_date, status, expected_income, closed_at
         FROM financial_cycles
        WHERE user_id = ? AND status = 'open'
        ORDER BY start_date DESC, id DESC
        LIMIT 1`,
      [userId]
    );
    return rows[0] || null;
  }

  static async lockOpenCycle(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, user_id, start_date, end_date, status, expected_income, closed_at
         FROM financial_cycles
        WHERE user_id = ? AND status = 'open'
        ORDER BY start_date DESC, id DESC
        LIMIT 1
        FOR UPDATE`,
      [userId]
    );
    return rows[0] || null;
  }

  static async lockSettlementPendingCycle(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, user_id, start_date, end_date, status, expected_income, closed_at
         FROM financial_cycles
        WHERE user_id = ? AND status = 'settlement_pending'
        ORDER BY start_date DESC, id DESC
        LIMIT 1
        FOR UPDATE`,
      [userId]
    );
    return rows[0] || null;
  }

  static async findSettlementByCycleId(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT cs.id, cs.cycle_id, cs.expected_income, cs.actual_recurring_income,
              cs.unexpected_income, cs.planned_needs, cs.actual_needs,
              cs.planned_wants, cs.actual_wants, cs.planned_savings, cs.actual_savings,
              cs.total_actual_outflows, cs.surplus, cs.deficit, cs.status,
              cs.approved_at, cs.closed_at
         FROM cycle_settlements cs
         JOIN financial_cycles fc ON fc.id = cs.cycle_id
        WHERE cs.cycle_id = ? AND fc.user_id = ?
        LIMIT 1`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  static async lockSettlementByCycleId(conn, userId, cycleId) {
    // MySQL 8 supports locking joined tables, but to be safe we lock the specific rows.
    // A nested select or just locking cycle_settlements is usually enough if we know cycleId is owned.
    const [rows] = await conn.execute(
      `SELECT cs.id, cs.cycle_id, cs.expected_income, cs.actual_recurring_income,
              cs.unexpected_income, cs.planned_needs, cs.actual_needs,
              cs.planned_wants, cs.actual_wants, cs.planned_savings, cs.actual_savings,
              cs.total_actual_outflows, cs.surplus, cs.deficit, cs.status,
              cs.approved_at, cs.closed_at
         FROM cycle_settlements cs
         JOIN financial_cycles fc ON fc.id = cs.cycle_id
        WHERE cs.cycle_id = ? AND fc.user_id = ?
        LIMIT 1
        FOR UPDATE`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  static async getCycleSnapshot(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT cas.needs_target, cas.wants_target, cas.savings_target, cas.allocation_base_income,
              cas.policy_version, cas.calculation_version
         FROM cycle_allocation_snapshots cas
         JOIN financial_cycles fc ON fc.id = cas.cycle_id
        WHERE cas.cycle_id = ? AND fc.user_id = ?
        LIMIT 1`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  static async getConfirmedIncomeByCycle(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT t.income_kind, COALESCE(SUM(t.amount), 0) as total
         FROM transactions t
         JOIN financial_cycles fc ON fc.id = t.cycle_id
        WHERE t.cycle_id = ? AND t.user_id = ? AND fc.user_id = ?
          AND t.transaction_type = 'income' AND t.direction = 'inflow' AND t.status = 'confirmed'
        GROUP BY t.income_kind`,
      [cycleId, userId, userId]
    );
    return rows;
  }

  static async getConfirmedExpensesByCycle(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT t.budget_bucket, COALESCE(SUM(t.amount), 0) as total
         FROM transactions t
         JOIN financial_cycles fc ON fc.id = t.cycle_id
        WHERE t.cycle_id = ? AND t.user_id = ? AND fc.user_id = ?
          AND t.transaction_type = 'expense' AND t.direction = 'outflow' AND t.status = 'confirmed'
          AND t.budget_bucket IN ('needs', 'wants')
        GROUP BY t.budget_bucket`,
      [cycleId, userId, userId]
    );
    return rows;
  }

  static async getConfirmedSavingsByCycle(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT COALESCE(SUM(t.amount), 0) as total
         FROM transactions t
         JOIN financial_cycles fc ON fc.id = t.cycle_id
        WHERE t.cycle_id = ? AND t.user_id = ? AND fc.user_id = ?
          AND t.transaction_type = 'saving' AND t.budget_bucket = 'savings' 
          AND t.direction = 'outflow' AND t.status = 'confirmed'`,
      [cycleId, userId, userId]
    );
    return rows[0]?.total || 0;
  }

  static async getTotalConfirmedOutflowsByCycle(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    // Includes saving since it reduces distributable cash
    const [rows] = await exec.execute(
      `SELECT COALESCE(SUM(t.amount), 0) as total
         FROM transactions t
         JOIN financial_cycles fc ON fc.id = t.cycle_id
        WHERE t.cycle_id = ? AND t.user_id = ? AND fc.user_id = ?
          AND t.direction = 'outflow' AND t.status = 'confirmed'
          AND t.transaction_type IN ('expense', 'capital_expense', 'saving')`,
      [cycleId, userId, userId]
    );
    return rows[0]?.total || 0;
  }

  static async getUnpaidCommitmentsByCycle(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT co.id, co.commitment_id, co.amount, co.status, co.due_date, fcom.name AS commitment_name
         FROM commitment_occurrences co
         JOIN financial_commitments fcom ON fcom.id = co.commitment_id
         JOIN financial_cycles fcyc ON fcyc.id = co.cycle_id
        WHERE co.cycle_id = ? AND fcom.user_id = ? AND fcyc.user_id = ? 
          AND co.status IN ('upcoming', 'due', 'overdue')
        ORDER BY co.due_date ASC`,
      [cycleId, userId, userId]
    );
    return rows;
  }

  static async getSettlementActions(connOrNull, userId, settlementId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT sa.id, sa.settlement_id, sa.action_type, sa.amount, sa.target_goal_id, sa.description, sa.created_at
         FROM settlement_actions sa
         JOIN cycle_settlements cs ON cs.id = sa.settlement_id
         JOIN financial_cycles fc ON fc.id = cs.cycle_id
        WHERE sa.settlement_id = ? AND fc.user_id = ?
        ORDER BY sa.id ASC`,
      [settlementId, userId]
    );
    return rows;
  }

  static async lockGoalsForSettlement(conn, userId, goalIds) {
    if (!goalIds || goalIds.length === 0) return [];
    const placeholders = goalIds.map(() => '?').join(',');
    const [rows] = await conn.execute(
      `SELECT id, user_id, name, target_amount, current_balance, status, ready_at
         FROM goals
        WHERE user_id = ? AND id IN (${placeholders})
        ORDER BY id ASC
        FOR UPDATE`,
      [userId, ...goalIds]
    );
    return rows;
  }

  // ------------------------------------------------------------------ //
  // Settlement writes                                                    //
  // ------------------------------------------------------------------ //

  static async createSettlement(conn, data) {
    // Only standard columns exist in cycle_settlements schema as per migration 017
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

  static async updateCycleStatusToPending(conn, userId, cycleId) {
    const [result] = await conn.execute(
      `UPDATE financial_cycles 
          SET status = 'settlement_pending' 
        WHERE id = ? AND user_id = ? AND status = 'open'`,
      [cycleId, userId]
    );
    return result.affectedRows;
  }

  static async updateCycleStatusToClosed(conn, userId, cycleId) {
    const [result] = await conn.execute(
      `UPDATE financial_cycles 
          SET status = 'closed', closed_at = NOW() 
        WHERE id = ? AND user_id = ? AND status = 'settlement_pending'`,
      [cycleId, userId]
    );
    return result.affectedRows;
  }

  static async approveSettlement(conn, userId, cycleId, settlementId) {
    const [result] = await conn.execute(
      `UPDATE cycle_settlements cs
         JOIN financial_cycles fcyc ON fcyc.id = cs.cycle_id
          SET cs.status = 'approved', cs.approved_at = NOW(), cs.closed_at = NOW()
        WHERE cs.id = ? AND cs.cycle_id = ? AND cs.status = 'pending' AND fcyc.user_id = ?`,
      [settlementId, cycleId, userId]
    );
    return result.affectedRows;
  }

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

  static async updateGoalBalanceAndStatus(conn, userId, goalId, newBalance, newStatus, readyAt) {
    const [result] = await conn.execute(
      `UPDATE goals 
          SET current_balance = ?, status = ?, ready_at = ? 
        WHERE id = ? AND user_id = ?`,
      [newBalance, newStatus, readyAt, goalId, userId]
    );
    return result.affectedRows;
  }

  static async createGoalTransaction(conn, data) {
    // Based on goal_transactions schema in migration 009
    const [result] = await conn.execute(
      `INSERT INTO goal_transactions
         (user_id, goal_id, amount, transaction_type, description)
       VALUES (?, ?, ?, 'contribution', ?)`,
      [data.userId, data.goalId, data.amount, data.description || null]
    );
    return result.insertId;
  }

  static async createSavingsTransaction(conn, data) {
    const [result] = await conn.execute(
      `INSERT INTO transactions
         (user_id, cycle_id, amount, direction, transaction_type, budget_bucket,
          description, occurred_at, status, confirmed_at)
       VALUES (?, ?, ?, 'outflow', 'saving', 'savings', ?, NOW(), 'confirmed', NOW())`,
      [data.userId, data.cycleId, data.amount, data.description || null]
    );
    return result.insertId;
  }
}

module.exports = { SettlementRepository };
