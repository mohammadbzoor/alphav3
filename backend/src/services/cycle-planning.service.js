const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');
const { CyclePlanningRepository } = require('../repositories/cycle-planning.repository');
const { CycleRepository } = require('../repositories/cycle.repository');
const { FinanceRepository } = require('../repositories/finance.repository');

class CyclePlanningService {
  /**
   * Plan goal allocations for a cycle.
   * Does not modify goal balances or create ledger entries.
   */
  static async planGoalAllocations(userId, cycleId, goalAllocations) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // Verify cycle belongs to user and is open
      const cycle = await CycleRepository.findCycleById(userId, cycleId);
      if (!cycle) {
        throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
      }
      if (cycle.status !== 'open') {
        throw new AppError('Cannot plan allocations for a closed cycle.', 409, 'CYCLE_CLOSED');
      }

      // Reject userId from request payload
      if (goalAllocations.some(a => a.userId !== undefined)) {
        throw new AppError('userId must not be provided in request payload', 400, 'INVALID_PAYLOAD');
      }

      // Verify each goal belongs to user
      for (const allocation of goalAllocations) {
        const { goalId, plannedAmount, prioritySnapshot } = allocation;
        const ownsGoal = await CyclePlanningRepository.verifyGoalOwnership(conn, userId, goalId);
        if (!ownsGoal) {
          throw new AppError('Goal not found or access denied.', 404, 'GOAL_NOT_FOUND');
        }
        if (plannedAmount < 0) {
          throw new AppError('Planned amount must be non-negative', 422, 'INVALID_AMOUNT');
        }
      }

      // Create allocations (unique constraint will prevent duplicates)
      await CyclePlanningRepository.createGoalCycleAllocations(conn, userId, cycleId, goalAllocations);

      await conn.commit();
      return { success: true, message: 'Goal allocations planned successfully' };
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  /**
   * Link Phase 2C provisional savings allocation to the open cycle.
   * Enforces savings invariant.
   */
  static async linkSavingsAllocation(userId, cycleId, savingsData) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // Verify cycle belongs to user and is open
      const cycle = await CycleRepository.findCycleById(userId, cycleId);
      if (!cycle) {
        throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
      }
      if (cycle.status !== 'open') {
        throw new AppError('Cannot link savings to a closed cycle.', 409, 'CYCLE_CLOSED');
      }

      // Reject userId from request payload
      if (savingsData.userId !== undefined) {
        throw new AppError('userId must not be provided in request payload', 400, 'INVALID_PAYLOAD');
      }

      // Verify invariant
      const { savingsAmount, emergencyFundAmount, totalGoalAllocations, unallocatedSavingsAmount } = savingsData;
      const calculatedTotal = emergencyFundAmount + totalGoalAllocations + unallocatedSavingsAmount;
      if (calculatedTotal !== savingsAmount) {
        throw new AppError(
          'Savings allocation invariant violation: emergency_fund_amount + total_goal_allocations + unallocated_savings_amount must equal savings_amount',
          422,
          'SAVINGS_INVARIANT_VIOLATION'
        );
      }

      await CyclePlanningRepository.createCycleSavingsAllocation(conn, userId, cycleId, savingsData);

      await conn.commit();
      return { success: true, message: 'Savings allocation linked successfully' };
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  /**
   * Get cycle planning summary including goal allocations and savings.
   */
  static async getCyclePlanningSummary(userId, cycleId) {
    // Verify cycle belongs to user
    const cycle = await CycleRepository.findCycleById(userId, cycleId);
    if (!cycle) {
      throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
    }

    const goalAllocations = await CyclePlanningRepository.getGoalCycleAllocations(userId, cycleId);
    const savingsAllocation = await CyclePlanningRepository.getCycleSavingsAllocation(userId, cycleId);

    return {
      cycleId,
      goalAllocations,
      savingsAllocation
    };
  }
}

module.exports = { CyclePlanningService };
