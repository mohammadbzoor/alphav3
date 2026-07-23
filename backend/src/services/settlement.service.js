'use strict';

const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');
const { SettlementRepository } = require('../repositories/settlement.repository');
const { CycleRepository } = require('../repositories/cycle.repository');

class SettlementService {
  static normalizeMoney(value, fieldName = 'amount', { allowZero = true } = {}) {
    const num = Number(value);
    if (!Number.isFinite(num)) {
      throw new AppError(`Invalid settlement amount for ${fieldName}`, 422, 'INVALID_SETTLEMENT_AMOUNT');
    }
    const rounded = Math.round(num);
    if (!Number.isSafeInteger(rounded)) {
      throw new AppError(`Unsafe integer for ${fieldName}`, 422, 'INVALID_SETTLEMENT_AMOUNT');
    }
    if (allowZero && rounded < 0) {
      throw new AppError(`Amount for ${fieldName} cannot be negative`, 422, 'INVALID_SETTLEMENT_AMOUNT');
    }
    if (!allowZero && rounded <= 0) {
      throw new AppError(`Amount for ${fieldName} must be positive`, 422, 'INVALID_SETTLEMENT_AMOUNT');
    }
    return rounded;
  }

  static normalizeDatabaseMoney(value, fieldName) {
    const num = Number(value);
    if (!Number.isFinite(num)) {
      throw new AppError(`Invalid database financial data for ${fieldName}`, 500, 'SETTLEMENT_FINANCIAL_DATA_INVALID');
    }
    const rounded = Math.round(num);
    if (!Number.isSafeInteger(rounded)) {
      throw new AppError(`Unsafe integer in database for ${fieldName}`, 500, 'SETTLEMENT_FINANCIAL_DATA_INVALID');
    }
    if (rounded < 0) {
      throw new AppError(`Negative amount in database for ${fieldName}`, 500, 'SETTLEMENT_FINANCIAL_DATA_INVALID');
    }
    return rounded;
  }

  static normalizeIdempotencyKey(key, required = true) {
    if (!key && required) {
      throw new AppError('Idempotency key is missing', 400, 'INVALID_IDEMPOTENCY_KEY');
    }
    if (!key && !required) return null;
    if (typeof key !== 'string') {
      throw new AppError('Idempotency key must be a string', 400, 'INVALID_IDEMPOTENCY_KEY');
    }
    const trimmed = key.trim();
    if (trimmed.length < 8 || trimmed.length > 128) {
      throw new AppError('Idempotency key length must be between 8 and 128 characters', 400, 'INVALID_IDEMPOTENCY_KEY');
    }
    return trimmed;
  }

  static normalizeDescription(value) {
    if (value === undefined || value === null) return null;
    if (typeof value !== 'string') {
      throw new AppError('Description must be a string', 422, 'INVALID_DESCRIPTION');
    }
    const trimmed = value.trim();
    if (trimmed === '') return null;
    if (trimmed.length > 255) {
      throw new AppError('Description cannot exceed 255 characters', 422, 'INVALID_DESCRIPTION');
    }
    return trimmed;
  }

  static async _calculateSettlementValues(connOrNull, userId, cycleId, cycle = null) {
    if (!cycle) {
      cycle = await CycleRepository.findCycleById(connOrNull, userId, cycleId);
      if (!cycle) {
        throw new AppError('Cycle not found', 404, 'CYCLE_NOT_FOUND');
      }
    }

    const snapshot = await SettlementRepository.getCycleSnapshot(connOrNull, userId, cycleId);
    if (!snapshot) {
      throw new AppError('Cycle snapshot not found.', 500, 'CYCLE_SNAPSHOT_MISSING');
    }

    const expectedIncome = this.normalizeDatabaseMoney(cycle.expected_income, 'expected_income');
    const plannedNeeds = this.normalizeDatabaseMoney(snapshot.needs_target, 'planned_needs');
    const plannedWants = this.normalizeDatabaseMoney(snapshot.wants_target, 'planned_wants');
    const plannedSavings = this.normalizeDatabaseMoney(snapshot.savings_target, 'planned_savings');

    const incomeRows = await SettlementRepository.getConfirmedIncomeByCycle(connOrNull, userId, cycleId);
    let actualRecurringIncome = 0;
    let unexpectedIncome = 0;
    for (const row of incomeRows) {
      if (row.income_kind === 'recurring') {
        actualRecurringIncome += this.normalizeDatabaseMoney(row.total, 'actual_recurring_income');
      } else if (row.income_kind === 'unexpected') {
        unexpectedIncome += this.normalizeDatabaseMoney(row.total, 'unexpected_income');
      }
    }

    const expenseRows = await SettlementRepository.getConfirmedExpensesByCycle(connOrNull, userId, cycleId);
    let actualNeeds = 0;
    let actualWants = 0;
    for (const row of expenseRows) {
      if (row.budget_bucket === 'needs') {
        actualNeeds += this.normalizeDatabaseMoney(row.total, 'actual_needs');
      } else if (row.budget_bucket === 'wants') {
        actualWants += this.normalizeDatabaseMoney(row.total, 'actual_wants');
      }
    }

    const rawSavings = await SettlementRepository.getConfirmedSavingsByCycle(connOrNull, userId, cycleId);
    const actualSavings = this.normalizeDatabaseMoney(rawSavings, 'actual_savings');

    const rawOutflows = await SettlementRepository.getTotalConfirmedOutflowsByCycle(connOrNull, userId, cycleId);
    const totalActualOutflows = this.normalizeDatabaseMoney(rawOutflows, 'total_actual_outflows');

    const actualIncome = actualRecurringIncome + unexpectedIncome;
    const netCycleResult = actualIncome - totalActualOutflows;
    
    let surplus = 0;
    let deficit = 0;
    if (netCycleResult > 0) surplus = netCycleResult;
    else if (netCycleResult < 0) deficit = -netCycleResult;

    return {
      expectedIncome,
      plannedNeeds,
      plannedWants,
      plannedSavings,
      actualRecurringIncome,
      unexpectedIncome,
      actualNeeds,
      actualWants,
      actualSavings,
      totalActualOutflows,
      actualIncome,
      netCycleResult,
      surplus,
      deficit
    };
  }

  static async previewSettlement(userId) {
    const cycle = await SettlementRepository.findOpenCycle(null, userId);
    if (!cycle) {
      throw new AppError('No active financial cycle found.', 404, 'NO_ACTIVE_FINANCIAL_CYCLE');
    }

    const cycleId = cycle.id;
    const values = await this._calculateSettlementValues(null, userId, cycleId, cycle);
    const unpaidCommitments = await SettlementRepository.getUnpaidCommitmentsByCycle(null, userId, cycleId);

    const warnings = [];
    if (values.actualIncome === 0) warnings.push('NO_CONFIRMED_INCOME');
    if (unpaidCommitments.length > 0) warnings.push('UNPAID_COMMITMENTS');
    const incomeVariance = values.actualIncome - values.expectedIncome;
    if (incomeVariance < -values.expectedIncome * 0.2) warnings.push('INCOME_SHORTAGE');

    const allowedActions = [];
    if (values.surplus > 0) {
      allowedActions.push('emergency_fund', 'goal_allocation', 'unallocated_savings');
    }

    const totalUnpaidCommitments = unpaidCommitments.reduce((sum, occ) => sum + this.normalizeDatabaseMoney(occ.amount, 'unpaid_amount'), 0);

    return {
      cycle: {
        id: cycleId,
        startDate: cycle.start_date,
        endDate: cycle.end_date,
        status: cycle.status,
        expectedIncome: values.expectedIncome
      },
      income: {
        expected: values.expectedIncome,
        actual: values.actualIncome,
        actualRecurring: values.actualRecurringIncome,
        unexpected: values.unexpectedIncome,
        variance: incomeVariance
      },
      needs: {
        planned: values.plannedNeeds,
        actual: values.actualNeeds,
        variance: values.actualNeeds - values.plannedNeeds
      },
      wants: {
        planned: values.plannedWants,
        actual: values.actualWants,
        variance: values.actualWants - values.plannedWants
      },
      savings: {
        planned: values.plannedSavings,
        actual: values.actualSavings,
        variance: values.actualSavings - values.plannedSavings
      },
      outflows: {
        total: values.totalActualOutflows
      },
      result: {
        netCycleResult: values.netCycleResult,
        surplus: values.surplus,
        deficit: values.deficit
      },
      commitments: {
        unpaid: unpaidCommitments.map(occ => ({
          id: occ.id,
          name: occ.commitment_name,
          amount: this.normalizeDatabaseMoney(occ.amount, 'unpaid_amount'),
          status: occ.status
        })),
        totalUnpaid: totalUnpaidCommitments
      },
      warnings,
      allowedActions,
      reliability: warnings.length === 0 ? 'reliable' : 'partial'
    };
  }

  static async beginSettlement(userId, { idempotencyKey } = {}) {
    // Idempotency key validated but not persisted.
    // beginSettlement provides a limited state-based replay if the settlement is already pending.
    // Full idempotency requires a schema migration to add idempotency_key.
    this.normalizeIdempotencyKey(idempotencyKey, true);
    
    const conn = await db.getConnection();
    let transactionActive = false;
    try {
      await conn.beginTransaction();
      transactionActive = true;

      let cycle = await SettlementRepository.lockOpenCycle(conn, userId);
      
      if (!cycle) {
        cycle = await SettlementRepository.lockSettlementPendingCycle(conn, userId);
        if (!cycle) {
          throw new AppError('No active financial cycle found.', 404, 'NO_ACTIVE_FINANCIAL_CYCLE');
        }
        
        const existingSettlement = await SettlementRepository.findSettlementByCycleId(conn, userId, cycle.id);
        if (existingSettlement) {
          if (existingSettlement.status === 'pending') {
            await conn.rollback();
            transactionActive = false;
            return {
              settlementId: existingSettlement.id,
              cycleId: cycle.id,
              status: existingSettlement.status,
              replayed: true,
              message: 'Full idempotency replay requires migration. Replaying pending settlement.'
            };
          } else {
            throw new AppError('Settlement already exists and is not pending.', 409, 'SETTLEMENT_ALREADY_EXISTS');
          }
        } else {
          throw new AppError('Cycle is pending but settlement record missing.', 500, 'CYCLE_STATE_INVALID');
        }
      }

      const cycleId = cycle.id;
      const existingSettlement = await SettlementRepository.findSettlementByCycleId(conn, userId, cycleId);
      if (existingSettlement) {
        throw new AppError('Settlement already exists for this open cycle.', 409, 'SETTLEMENT_ALREADY_EXISTS');
      }

      const values = await this._calculateSettlementValues(conn, userId, cycleId, cycle);

      const settlementId = await SettlementRepository.createSettlement(conn, {
        cycleId,
        expectedIncome: values.expectedIncome,
        actualRecurringIncome: values.actualRecurringIncome,
        unexpectedIncome: values.unexpectedIncome,
        plannedNeeds: values.plannedNeeds,
        actualNeeds: values.actualNeeds,
        plannedWants: values.plannedWants,
        actualWants: values.actualWants,
        plannedSavings: values.plannedSavings,
        actualSavings: values.actualSavings,
        totalActualOutflows: values.totalActualOutflows,
        surplus: values.surplus,
        deficit: values.deficit
      });

      const affected = await SettlementRepository.updateCycleStatusToPending(conn, userId, cycleId);
      if (affected !== 1) {
        throw new AppError('Failed to transition cycle to settlement_pending.', 409, 'INVALID_CYCLE_TRANSITION');
      }

      await conn.commit();
      transactionActive = false;

      return {
        settlementId,
        cycleId,
        status: 'pending',
        replayed: false
      };
    } catch (err) {
      if (transactionActive) {
        try {
          await conn.rollback();
        } catch (rollbackError) {
          err.rollbackError = rollbackError;
        }
      }
      throw err;
    } finally {
      conn.release();
    }
  }

  static async closeCycle(userId, { actions, idempotencyKey } = {}) {
    // Idempotency key validated but not persisted.
    // closeCycle provides NO replay after successful close until migration.
    this.normalizeIdempotencyKey(idempotencyKey, true);
    
    const normalizedActions = [];
    if (actions && Array.isArray(actions)) {
      for (const action of actions) {
        if (action.userId !== undefined || action.cycleId !== undefined || action.settlementId !== undefined) {
          throw new AppError('userId, cycleId, and settlementId are not allowed in action payload', 400, 'INVALID_PAYLOAD');
        }

        const actionType = action.actionType;
        if (!['emergency_fund', 'goal_allocation', 'unallocated_savings'].includes(actionType)) {
          throw new AppError('Unsupported action type.', 422, 'UNSUPPORTED_ACTION_TYPE');
        }
        const amount = this.normalizeMoney(action.amount, 'amount', { allowZero: false });
        const description = this.normalizeDescription(action.description);
        
        let goalId = null;
        if (actionType === 'goal_allocation') {
          if (action.goalId === undefined || action.goalId === null) {
            throw new AppError('goalId required for goal_allocation', 422, 'GOAL_ID_REQUIRED');
          }
          const goalIdStr = String(action.goalId);
          if (!/^[1-9]\d*$/.test(goalIdStr)) {
            throw new AppError('goalId must be a positive integer', 422, 'INVALID_GOAL_ID');
          }
          try {
            BigInt(goalIdStr);
          } catch (e) {
            throw new AppError('goalId is not a valid BIGINT', 422, 'INVALID_GOAL_ID');
          }
          goalId = goalIdStr;
        } else {
          if (action.goalId !== undefined && action.goalId !== null) {
            throw new AppError('goalId is not allowed for this action type', 422, 'GOAL_ID_NOT_ALLOWED');
          }
        }

        normalizedActions.push({
          actionType,
          amount,
          description,
          goalId
        });
      }
    } else if (actions !== undefined && !Array.isArray(actions)) {
      throw new AppError('actions must be an array', 422, 'INVALID_ACTIONS_FORMAT');
    }

    const goalIds = normalizedActions.filter(a => a.actionType === 'goal_allocation').map(a => a.goalId);
    const uniqueGoalIds = new Set(goalIds);
    if (uniqueGoalIds.size !== goalIds.length) {
      throw new AppError('Duplicate goalId in actions.', 422, 'DUPLICATE_GOAL_ID');
    }

    const conn = await db.getConnection();
    let transactionActive = false;
    try {
      await conn.beginTransaction();
      transactionActive = true;

      const cycle = await SettlementRepository.lockSettlementPendingCycle(conn, userId);
      if (!cycle) {
        throw new AppError('Cycle must be in settlement_pending status to close.', 409, 'INVALID_CYCLE_STATUS');
      }

      const cycleId = cycle.id;
      const settlement = await SettlementRepository.lockSettlementByCycleId(conn, userId, cycleId);
      if (!settlement) {
        throw new AppError('Settlement not found.', 404, 'SETTLEMENT_NOT_FOUND');
      }

      if (settlement.status !== 'pending') {
        throw new AppError('Settlement must be pending.', 409, 'INVALID_SETTLEMENT_STATUS');
      }

      const values = await this._calculateSettlementValues(conn, userId, cycleId, cycle);

      const dbSurplus = this.normalizeDatabaseMoney(settlement.surplus, 'surplus');
      const dbDeficit = this.normalizeDatabaseMoney(settlement.deficit, 'deficit');
      const dbActualIncome = this.normalizeDatabaseMoney(settlement.actual_recurring_income, 'actual_recurring_income') + this.normalizeDatabaseMoney(settlement.unexpected_income, 'unexpected_income');
      const dbActualNeeds = this.normalizeDatabaseMoney(settlement.actual_needs, 'actual_needs');
      const dbActualWants = this.normalizeDatabaseMoney(settlement.actual_wants, 'actual_wants');
      const dbActualSavings = this.normalizeDatabaseMoney(settlement.actual_savings, 'actual_savings');
      const dbTotalOutflows = this.normalizeDatabaseMoney(settlement.total_actual_outflows, 'total_actual_outflows');

      if (
        values.surplus !== dbSurplus ||
        values.deficit !== dbDeficit ||
        values.actualIncome !== dbActualIncome ||
        values.actualNeeds !== dbActualNeeds ||
        values.actualWants !== dbActualWants ||
        values.actualSavings !== dbActualSavings ||
        values.totalActualOutflows !== dbTotalOutflows
      ) {
        throw new AppError('Financial data has changed since settlement began.', 409, 'SETTLEMENT_DATA_CHANGED');
      }

      if (values.surplus > 0) {
        if (!normalizedActions || normalizedActions.length === 0) {
          throw new AppError('Settlement actions required when surplus exists.', 422, 'SETTLEMENT_ACTIONS_REQUIRED');
        }
        const actionTotal = normalizedActions.reduce((sum, a) => sum + a.amount, 0);
        if (actionTotal !== values.surplus) {
          throw new AppError(`Settlement action totals (${actionTotal}) must equal distributable surplus (${values.surplus}).`, 422, 'SETTLEMENT_ACTIONS_MISMATCH');
        }
      } else {
        if (normalizedActions && normalizedActions.length > 0) {
          throw new AppError('No settlement actions allowed when surplus is zero or deficit exists.', 422, 'SURPLUS_ACTION_NOT_ALLOWED');
        }
      }

      const goalUpdates = new Map();
      if (goalIds.length > 0) {
        const sortedGoalIds = [...goalIds].sort((a, b) => (BigInt(a) < BigInt(b) ? -1 : (BigInt(a) > BigInt(b) ? 1 : 0)));
        const lockedGoals = await SettlementRepository.lockGoalsForSettlement(conn, userId, sortedGoalIds);
        if (lockedGoals.length !== sortedGoalIds.length) {
          throw new AppError('One or more goals not found.', 404, 'GOAL_NOT_FOUND');
        }
        
        const goalsMap = new Map();
        lockedGoals.forEach(g => goalsMap.set(g.id.toString(), g));

        for (const action of normalizedActions) {
          if (action.actionType === 'goal_allocation') {
            const goalIdStr = action.goalId;
            const goal = goalsMap.get(goalIdStr);
            if (goal.status !== 'active') {
              throw new AppError('Goal must be active to receive allocation.', 422, 'INVALID_GOAL_STATUS');
            }

            const currentBalance = this.normalizeDatabaseMoney(goal.current_balance, 'current_balance');
            const targetAmount = this.normalizeDatabaseMoney(goal.target_amount, 'target_amount');
            const newBalance = currentBalance + action.amount;
            if (newBalance > targetAmount) {
              throw new AppError('Goal allocation would cause overfunding.', 422, 'GOAL_OVERFUNDING');
            }

            let newStatus = 'active';
            let readyAt = goal.ready_at;
            if (newBalance === targetAmount) {
              newStatus = 'ready';
              readyAt = new Date();
            }

            goalUpdates.set(goalIdStr, {
              newBalance,
              newStatus,
              readyAt
            });
          }
        }
      }

      for (const action of normalizedActions) {
        const actionId = await SettlementRepository.createSettlementAction(conn, {
          settlementId: settlement.id,
          actionType: action.actionType,
          amount: action.amount,
          targetGoalId: action.goalId ? action.goalId.toString() : null,
          description: action.description
        });

        if (action.actionType === 'goal_allocation') {
          const gd = goalUpdates.get(action.goalId);
          await SettlementRepository.createGoalTransaction(conn, {
            userId,
            goalId: action.goalId,
            amount: action.amount,
            description: action.description || 'Cycle settlement allocation'
          });
          const affected = await SettlementRepository.updateGoalBalanceAndStatus(conn, userId, action.goalId, gd.newBalance, gd.newStatus, gd.readyAt);
          if (affected !== 1) {
            throw new AppError('Failed to update goal balance.', 500, 'GOAL_UPDATE_FAILED');
          }
        } else if (action.actionType === 'emergency_fund' || action.actionType === 'unallocated_savings') {
          const defaultDesc = action.actionType === 'emergency_fund' ? 'Emergency fund from cycle settlement' : 'Unallocated savings from cycle settlement';
          await SettlementRepository.createSavingsTransaction(conn, {
            userId,
            cycleId,
            amount: action.amount,
            description: action.description || defaultDesc
          });
        }
      }

      const approveAffected = await SettlementRepository.approveSettlement(conn, userId, cycleId, settlement.id);
      if (approveAffected !== 1) {
        throw new AppError('Failed to approve settlement.', 409, 'INVALID_SETTLEMENT_TRANSITION');
      }

      const closeAffected = await SettlementRepository.updateCycleStatusToClosed(conn, userId, cycleId);
      if (closeAffected !== 1) {
        throw new AppError('Failed to close cycle.', 409, 'INVALID_CYCLE_TRANSITION');
      }

      await conn.commit();
      transactionActive = false;

      const { ChallengeEngineService } = require('./challenge-engine.service');
      ChallengeEngineService.evaluateForSettlement(userId, cycleId).catch(err => {
        console.error('Async challenge evaluation failed (settlement):', err.message);
      });

      return {
        settlementId: settlement.id,
        cycleId,
        status: 'closed',
        surplus: values.surplus,
        deficit: values.deficit,
        actionsExecuted: normalizedActions.length
      };
    } catch (err) {
      if (transactionActive) {
        try {
          await conn.rollback();
        } catch (rollbackError) {
          err.rollbackError = rollbackError;
        }
      }
      throw err;
    } finally {
      conn.release();
    }
  }
}

module.exports = { SettlementService };
