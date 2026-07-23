const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');

class CyclePlanningRepository {
  static async lockEligibleGoalsForPlanning(conn, userId, goalIds) {
    if (!goalIds || goalIds.length === 0) return [];
    const placeholders = goalIds.map(() => '?').join(', ');
    const params = [userId, ...goalIds];
    const [rows] = await conn.execute(
      `SELECT id, user_id, name, goal_type, target_amount, current_balance, priority, status
         FROM goals
        WHERE user_id = ? AND status = 'active' AND id IN (${placeholders})
        ORDER BY id ASC
          FOR UPDATE`,
      params
    );
    return rows;
  }

  static async createGoalCycleAllocations(conn, userId, cycleId, allocations) {
    if (!allocations || allocations.length === 0) return 0;
    const placeholders = allocations.map(() => '(?, ?, ?, ?)').join(', ');
    const params = [];
    for (const allocation of allocations) {
      params.push(cycleId, allocation.goalId, allocation.plannedAmount, allocation.prioritySnapshot);
    }
    const [result] = await conn.execute(
      `INSERT INTO goal_cycle_allocations
         (cycle_id, goal_id, planned_amount, priority_snapshot)
       VALUES ${placeholders}`,
      params
    );
    return result.affectedRows;
  }

  static async getGoalCycleAllocationsTotal(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT COALESCE(SUM(gca.planned_amount), 0) AS total
         FROM goal_cycle_allocations gca
         JOIN financial_cycles fc ON fc.id = gca.cycle_id
         JOIN goals g ON g.id = gca.goal_id
        WHERE gca.cycle_id = ? AND fc.user_id = ? AND g.user_id = ? AND g.is_system_managed = FALSE AND g.goal_type != 'emergency_fund'`,
      [cycleId, userId, userId]
    );
    return Number(rows[0].total);
  }

  static async getGoalCycleAllocations(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT gca.id, gca.cycle_id, gca.goal_id, gca.planned_amount,
              gca.actual_amount, gca.priority_snapshot,
              g.name AS goal_name, g.goal_type
         FROM goal_cycle_allocations gca
         JOIN financial_cycles fc ON fc.id = gca.cycle_id
         JOIN goals g ON g.id = gca.goal_id
        WHERE gca.cycle_id = ? AND fc.user_id = ? AND g.user_id = ?
        ORDER BY gca.priority_snapshot ASC, gca.id ASC`,
      [cycleId, userId, userId]
    );
    return rows;
  }

  static async createCycleSavingsAllocation(conn, userId, cycleId, savingsData) {
    const {
      savingsAmount,
      emergencyFundAmount,
      emergencyFundRate,
      totalGoalAllocations,
      unallocatedSavingsAmount
    } = savingsData;
    await conn.execute(
      `INSERT INTO cycle_savings_allocations
         (cycle_id, savings_amount, emergency_fund_amount, emergency_fund_rate,
          total_goal_allocations, unallocated_savings_amount, status)
       VALUES (?, ?, ?, ?, ?, ?, 'planned')`,
      [cycleId, savingsAmount, emergencyFundAmount, emergencyFundRate,
       totalGoalAllocations, unallocatedSavingsAmount]
    );
  }

  static async getCycleSavingsAllocation(connOrNull, userId, cycleId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT csa.id, csa.cycle_id, csa.savings_amount, csa.emergency_fund_amount,
              csa.emergency_fund_rate, csa.total_goal_allocations,
              csa.unallocated_savings_amount, csa.status
         FROM cycle_savings_allocations csa
         JOIN financial_cycles fc ON fc.id = csa.cycle_id
        WHERE csa.cycle_id = ? AND fc.user_id = ?
        LIMIT 1`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  static async findCycleSavingsAllocationForUpdate(conn, userId, cycleId) {
    const [rows] = await conn.execute(
      `SELECT csa.id, csa.cycle_id, csa.savings_amount, csa.emergency_fund_amount,
              csa.emergency_fund_rate, csa.total_goal_allocations,
              csa.unallocated_savings_amount, csa.status
         FROM cycle_savings_allocations csa
         JOIN financial_cycles fc ON fc.id = csa.cycle_id
        WHERE csa.cycle_id = ? AND fc.user_id = ?
          FOR UPDATE`,
      [cycleId, userId]
    );
    return rows[0] || null;
  }

  static async verifyGoalOwnership(conn, userId, goalId) {
    const [rows] = await conn.execute(
      `SELECT id FROM goals WHERE id = ? AND user_id = ? AND status IN ('active', 'paused', 'ready')`,
      [goalId, userId]
    );
    return rows.length > 0;
  }

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
