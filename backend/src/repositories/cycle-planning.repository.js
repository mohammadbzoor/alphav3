const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');

class CyclePlanningRepository {
  /**
   * Create goal cycle allocations for a user's cycle.
   * Enforces unique (goal_id, cycle_id) constraint.
   */
  static async createGoalCycleAllocations(conn, userId, cycleId, allocations) {
    for (const allocation of allocations) {
      const { goalId, plannedAmount, prioritySnapshot } = allocation;
      await conn.execute(
        `INSERT INTO goal_cycle_allocations
           (cycle_id, goal_id, planned_amount, priority_snapshot)
         VALUES (?, ?, ?, ?)`,
        [cycleId, goalId, plannedAmount, prioritySnapshot]
      );
    }
  }

  /**
   * Get goal cycle allocations for a cycle, scoped to user.
   */
  static async getGoalCycleAllocations(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT gca.id, gca.cycle_id, gca.goal_id, gca.planned_amount,
              gca.actual_amount, gca.priority_snapshot,
              g.name AS goal_name, g.goal_type
         FROM goal_cycle_allocations gca
         JOIN goals g ON g.id = gca.goal_id
        WHERE gca.cycle_id = ? AND g.user_id = ?`,
      [cycleId, userId]
    );
    return rows;
  }

  /**
   * Create cycle savings allocation linking Phase 2C provisional allocation to cycle.
   * Enforces savings invariant: emergency_fund_amount + total_goal_allocations + unallocated_savings_amount = savings_amount
   */
  static async createCycleSavingsAllocation(conn, userId, cycleId, savingsData) {
    const {
      savingsAmount,
      emergencyFundAmount,
      emergencyFundRate,
      totalGoalAllocations,
      unallocatedSavingsAmount
    } = savingsData;

    // Verify invariant before insert
    const calculatedTotal = emergencyFundAmount + totalGoalAllocations + unallocatedSavingsAmount;
    if (calculatedTotal !== savingsAmount) {
      throw new AppError(
        'Savings allocation invariant violation: emergency_fund_amount + total_goal_allocations + unallocated_savings_amount must equal savings_amount',
        422,
        'SAVINGS_INVARIANT_VIOLATION'
      );
    }

    await conn.execute(
      `INSERT INTO cycle_savings_allocations
         (cycle_id, savings_amount, emergency_fund_amount, emergency_fund_rate,
          total_goal_allocations, unallocated_savings_amount, status)
       VALUES (?, ?, ?, ?, ?, ?, 'planned')`,
      [cycleId, savingsAmount, emergencyFundAmount, emergencyFundRate,
       totalGoalAllocations, unallocatedSavingsAmount]
    );
  }

  /**
   * Get cycle savings allocation for a cycle, scoped to user.
   */
  static async getCycleSavingsAllocation(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT csa.* FROM cycle_savings_allocations csa
         JOIN financial_cycles fc ON fc.id = csa.cycle_id
        WHERE csa.cycle_id = ? AND fc.user_id = ?`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  /**
   * Verify goal belongs to user and is active.
   */
  static async verifyGoalOwnership(conn, userId, goalId) {
    const [rows] = await conn.execute(
      `SELECT id FROM goals WHERE id = ? AND user_id = ? AND status IN ('active', 'paused', 'ready')`,
      [goalId, userId]
    );
    return rows.length > 0;
  }

  /**
   * Get confirmed transaction totals for a cycle by bucket.
   */
  static async getConfirmedTransactionTotals(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT budget_bucket, SUM(amount) AS total
         FROM transactions
        WHERE user_id = ? AND cycle_id = ? AND status = 'confirmed'
          AND transaction_type = 'expense'
          AND budget_bucket IN ('needs', 'wants')
        GROUP BY budget_bucket`,
      [userId, cycleId]
    );
    const totals = { needs: 0, wants: 0 };
    for (const row of rows) {
      totals[row.budget_bucket] = Number(row.total || 0);
    }
    return totals;
  }

  /**
   * Get unpaid commitment occurrences total for a cycle.
   */
  static async getUnpaidCommitmentOccurrencesTotal(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT COALESCE(SUM(co.amount), 0) AS total
         FROM commitment_occurrences co
         JOIN financial_commitments fc ON fc.id = co.commitment_id
        WHERE co.cycle_id = ? AND fc.user_id = ? AND co.status IN ('upcoming', 'due', 'overdue')`,
      [cycleId, userId]
    );
    return Number(rows[0].total || 0);
  }
}

module.exports = { CyclePlanningRepository };
