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

    const emergencyFundPercentage = savingsData.emergencyFundPercentage !== undefined ? Number(savingsData.emergencyFundPercentage) : 10;
    if (isNaN(emergencyFundPercentage) || emergencyFundPercentage < 0 || emergencyFundPercentage > 100) {
      throw new AppError('Invalid emergency fund percentage', 422, 'INVALID_PERCENTAGE');
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

      // Fetch snapshot to get planned savings
      const snapshot = await CycleRepository.findSnapshotByCycleId(conn, userId, cycleId);
      if (!snapshot) {
        throw new AppError('Cycle allocation snapshot not found.', 404, 'SNAPSHOT_NOT_FOUND');
      }
      const plannedSavings = Number(snapshot.savings_target);

      // Goal allocations
      const actualGoalAllocationsTotal = await CyclePlanningRepository.getGoalCycleAllocationsTotal(conn, userId, cycleId);

      // System EF Capacity
      const { SavingsAccountingService } = require('./savings-accounting.service');
      const { emergencyFundBalance, emergencyFundTarget } = await SavingsAccountingService.getEmergencyFundBalance(userId);
      const remainingEmergencyCapacity = Math.max(emergencyFundTarget - emergencyFundBalance, 0);

      // Calculation
      const calculatedEmergencyFundAmount = Math.round(plannedSavings * (emergencyFundPercentage / 100));
      const effectiveEmergencyFundAmount = Math.min(calculatedEmergencyFundAmount, remainingEmergencyCapacity);

      if (effectiveEmergencyFundAmount + actualGoalAllocationsTotal > plannedSavings) {
        throw new AppError('Emergency Fund and goal allocations exceed planned savings.', 422, 'SAVINGS_EXCEEDED');
      }

      const unallocatedSavingsAmount = plannedSavings - effectiveEmergencyFundAmount - actualGoalAllocationsTotal;

      const normalizedData = {
        savingsAmount: plannedSavings,
        emergencyFundAmount: effectiveEmergencyFundAmount,
        emergencyFundRate: emergencyFundPercentage,
        totalGoalAllocations: actualGoalAllocationsTotal,
        unallocatedSavingsAmount
      };

      await CyclePlanningRepository.createCycleSavingsAllocation(conn, userId, cycleId, normalizedData);

      await conn.commit();
      transactionCommitted = true;
      
      return { 
        plannedSavings,
        emergencyFundPercentage,
        emergencyFundAmount: effectiveEmergencyFundAmount,
        plannedGoalAllocations: actualGoalAllocationsTotal,
        unallocatedSavingsAmount,
        emergencyFundBalance,
        emergencyFundTarget,
        remainingEmergencyCapacity
      };
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

    const snapshot = await CycleRepository.findSnapshotByCycleId(null, userId, cycleId);
    const plannedSavings = snapshot ? Number(snapshot.savings_target) : 0;

    const { SavingsAccountingService } = require('./savings-accounting.service');
    const { emergencyFundBalance, emergencyFundTarget } = await SavingsAccountingService.getEmergencyFundBalance(userId);
    const remainingEmergencyCapacity = Math.max(emergencyFundTarget - emergencyFundBalance, 0);

    return {
      cycleId,
      plannedSavings,
      emergencyFundBalance,
      emergencyFundTarget,
      remainingEmergencyCapacity,
      goalAllocations,
      savingsAllocation
    };
  }
}

module.exports = { CyclePlanningService };
