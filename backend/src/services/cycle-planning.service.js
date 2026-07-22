const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');
const { CyclePlanningRepository } = require('../repositories/cycle-planning.repository');
const { CycleRepository } = require('../repositories/cycle.repository');

class CyclePlanningService {
  static async planGoalAllocations(userId, cycleId, goalAllocations) {
    if (!Array.isArray(goalAllocations) || goalAllocations.length === 0) {
      throw new AppError('goalAllocations must be a non-empty array', 400, 'INVALID_PAYLOAD');
    }
    if (goalAllocations.length > 100) {
      throw new AppError('Too many goal allocations (max 100)', 400, 'PAYLOAD_TOO_LARGE');
    }
    if (goalAllocations.some(a => a.userId !== undefined)) {
      throw new AppError('userId must not be provided in request payload', 400, 'INVALID_PAYLOAD');
    }
    
    const normalizedAllocations = [];
    const seenGoals = new Set();
    for (const alloc of goalAllocations) {
      const gId = String(alloc.goalId);
      if (seenGoals.has(gId)) {
        throw new AppError('Duplicate goalId in payload', 400, 'DUPLICATE_GOAL_ID');
      }
      seenGoals.add(gId);
      
      const plannedAmount = Number(alloc.plannedAmount);
      if (!Number.isSafeInteger(plannedAmount) || plannedAmount <= 0) {
        throw new AppError('Planned amount must be a positive safe integer', 422, 'INVALID_AMOUNT');
      }
      
      const prioritySnapshot = Number(alloc.prioritySnapshot);
      if (!Number.isSafeInteger(prioritySnapshot)) {
        throw new AppError('Priority snapshot must be an integer', 422, 'INVALID_PRIORITY');
      }
      // TODO: Ensure prioritySnapshot falls within the valid schema range (e.g., 1-10)

      normalizedAllocations.push({
        goalId: gId,
        plannedAmount,
        prioritySnapshot
      });
    }

    const goalIds = normalizedAllocations.map(a => a.goalId);
    const conn = await db.getConnection();
    let transactionCommitted = false;
    try {
      await conn.beginTransaction();

      const cycle = await CycleRepository.lockCycleById(conn, userId, cycleId);
      if (!cycle) {
        throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
      }
      if (cycle.status !== 'open') {
        throw new AppError('Cannot plan allocations for a closed cycle.', 409, 'CYCLE_NOT_OPEN');
      }

      const eligibleGoals = await CyclePlanningRepository.lockEligibleGoalsForPlanning(conn, userId, goalIds);
      if (eligibleGoals.length !== goalIds.length) {
        throw new AppError('One or more goals are not found, not active, or ineligible.', 404, 'GOAL_NOT_FOUND_OR_INELIGIBLE');
      }

      const goalsMap = new Map();
      for (const g of eligibleGoals) {
        goalsMap.set(String(g.id), g);
      }

      for (const alloc of normalizedAllocations) {
        const goal = goalsMap.get(alloc.goalId);
        const targetAmount = Number(goal.target_amount);
        const currentBalance = Number(goal.current_balance);
        const remaining = targetAmount - currentBalance;
        
        if (remaining <= 0) {
          throw new AppError(`Goal ${alloc.goalId} is already fully funded.`, 422, 'GOAL_OVERFUNDING');
        }
        if (alloc.plannedAmount > remaining) {
          throw new AppError(`Planned amount for goal ${alloc.goalId} exceeds remaining amount.`, 422, 'GOAL_OVERFUNDING');
        }
      }

      await CyclePlanningRepository.createGoalCycleAllocations(conn, userId, cycleId, normalizedAllocations);

      await conn.commit();
      transactionCommitted = true;
      return { success: true, message: 'Goal allocations planned successfully' };
    } catch (err) {
      if (!transactionCommitted) {
        await conn.rollback();
      }
      if (err.code === 'ER_DUP_ENTRY') {
        throw new AppError('Goal allocation already exists for this cycle.', 409, 'GOAL_ALLOCATION_ALREADY_EXISTS');
      }
      throw err;
    } finally {
      conn.release();
    }
  }

  static async linkSavingsAllocation(userId, cycleId, savingsData) {
    if (savingsData.userId !== undefined) {
      throw new AppError('userId must not be provided in request payload', 400, 'INVALID_PAYLOAD');
    }

    const savingsAmount = Number(savingsData.savingsAmount);
    const emergencyFundAmount = Number(savingsData.emergencyFundAmount);
    const totalGoalAllocations = Number(savingsData.totalGoalAllocations);
    const unallocatedSavingsAmount = Number(savingsData.unallocatedSavingsAmount);
    const emergencyFundRate = Number(savingsData.emergencyFundRate);

    if (!Number.isSafeInteger(savingsAmount) || savingsAmount < 0 ||
        !Number.isSafeInteger(emergencyFundAmount) || emergencyFundAmount < 0 ||
        !Number.isSafeInteger(totalGoalAllocations) || totalGoalAllocations < 0 ||
        !Number.isSafeInteger(unallocatedSavingsAmount) || unallocatedSavingsAmount < 0) {
      throw new AppError('Amounts must be non-negative safe integers', 422, 'INVALID_AMOUNT');
    }
    
    if (isNaN(emergencyFundRate) || emergencyFundRate < 0) {
      throw new AppError('Invalid emergency fund rate', 422, 'INVALID_RATE');
    }

    const conn = await db.getConnection();
    let transactionCommitted = false;
    try {
      await conn.beginTransaction();

      const cycle = await CycleRepository.lockCycleById(conn, userId, cycleId);
      if (!cycle) {
        throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
      }
      if (cycle.status !== 'open') {
        throw new AppError('Cannot link savings to a closed cycle.', 409, 'CYCLE_NOT_OPEN');
      }

      const existingSavings = await CyclePlanningRepository.findCycleSavingsAllocationForUpdate(conn, userId, cycleId);
      if (existingSavings) {
        throw new AppError('Cycle savings allocation already exists.', 409, 'CYCLE_SAVINGS_ALLOCATION_EXISTS');
      }

      const actualGoalAllocationsTotal = await CyclePlanningRepository.getGoalCycleAllocationsTotal(conn, userId, cycleId);
      if (totalGoalAllocations !== undefined && actualGoalAllocationsTotal !== totalGoalAllocations) {
        throw new AppError(`Goal allocation total mismatch. Expected ${actualGoalAllocationsTotal}`, 422, 'GOAL_ALLOCATION_TOTAL_MISMATCH');
      }

      const calculatedTotal = emergencyFundAmount + actualGoalAllocationsTotal + unallocatedSavingsAmount;
      if (calculatedTotal !== savingsAmount) {
        throw new AppError(
          'Savings allocation invariant violation: emergency_fund_amount + total_goal_allocations + unallocated_savings_amount must equal savings_amount',
          422,
          'SAVINGS_INVARIANT_VIOLATION'
        );
      }

      const snapshot = await CycleRepository.findSnapshotByCycleId(conn, userId, cycleId);
      if (snapshot && Number(snapshot.savings_target) !== savingsAmount) {
        // TODO: Enforce savingsAmount == savings_target based on strict domain rules if required.
      }

      const normalizedData = {
        savingsAmount,
        emergencyFundAmount,
        emergencyFundRate,
        totalGoalAllocations: actualGoalAllocationsTotal,
        unallocatedSavingsAmount
      };

      await CyclePlanningRepository.createCycleSavingsAllocation(conn, userId, cycleId, normalizedData);

      await conn.commit();
      transactionCommitted = true;
      return { success: true, message: 'Savings allocation linked successfully' };
    } catch (err) {
      if (!transactionCommitted) {
        await conn.rollback();
      }
      if (err.code === 'ER_DUP_ENTRY') {
        throw new AppError('Cycle savings allocation already exists.', 409, 'CYCLE_SAVINGS_ALLOCATION_EXISTS');
      }
      throw err;
    } finally {
      conn.release();
    }
  }

  static async getCyclePlanningSummary(userId, cycleId) {
    const cycle = await CycleRepository.findCycleById(null, userId, cycleId);
    if (!cycle) {
      throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
    }

    const [goalAllocations, savingsAllocation] = await Promise.all([
      CyclePlanningRepository.getGoalCycleAllocations(null, userId, cycleId),
      CyclePlanningRepository.getCycleSavingsAllocation(null, userId, cycleId)
    ]);

    return {
      cycleId,
      goalAllocations,
      savingsAllocation
    };
  }
}

module.exports = { CyclePlanningService };
