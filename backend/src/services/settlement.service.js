/**
 * SettlementService – Phase 3B – Financial Cycle Settlement and Closure
 *
 * Implements:
 *   - previewSettlement()  – Calculate settlement preview without persisting
 *   - beginSettlement()    – Transition cycle to settlement_pending and create pending settlement
 *   - closeCycle()         – Execute settlement actions and close cycle
 *
 * Settlement formulas:
 *   expectedIncome = cycle snapshot/profile expected income
 *   actualRecurringIncome = sum confirmed recurring income transactions
 *   unexpectedIncome = sum confirmed unexpected income transactions
 *   actualIncome = actualRecurringIncome + unexpectedIncome
 *   actualNeeds = sum confirmed Needs outflows
 *   actualWants = sum confirmed Wants outflows
 *   actualSavings = sum confirmed savings movements
 *   totalActualOutflows = all confirmed external outflows
 *   netCycleResult = actualIncome - totalActualOutflows
 *   surplus = netCycleResult if > 0, else 0
 *   deficit = absolute value of netCycleResult if < 0, else 0
 */

'use strict';

const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');
const { SettlementRepository } = require('../repositories/settlement.repository');
const { CycleRepository } = require('../repositories/cycle.repository');
const { FinanceRepository } = require('../repositories/finance.repository');

class SettlementService {
  /**
   * POST /financial-cycles/current/settlement-preview
   *
   * Calculate settlement preview without persisting anything.
   * Uses authenticated user ID and the current open cycle.
   */
  static async previewSettlement(userId) {
    const conn = await db.getConnection();
    try {
      // Find open cycle
      const cycle = await SettlementRepository.lockOpenCycle(conn, userId);
      if (!cycle) {
        throw new AppError('No active financial cycle found.', 404, 'NO_ACTIVE_FINANCIAL_CYCLE');
      }

      const cycleId = cycle.id;

      // Get cycle snapshot for planned values
      const snapshot = await SettlementRepository.getCycleSnapshot(cycleId);
      if (!snapshot) {
        throw new AppError('Cycle snapshot not found.', 404, 'CYCLE_SNAPSHOT_NOT_FOUND');
      }

      // Get confirmed income
      const incomeRows = await SettlementRepository.getConfirmedIncomeByCycle(cycleId);
      let actualRecurringIncome = 0;
      let unexpectedIncome = 0;
      incomeRows.forEach(row => {
        if (row.income_kind === 'recurring') {
          actualRecurringIncome += Number(row.total);
        } else if (row.income_kind === 'unexpected') {
          unexpectedIncome += Number(row.total);
        }
      });

      // Get confirmed expenses by bucket
      const expenseRows = await SettlementRepository.getConfirmedExpensesByCycle(cycleId);
      let actualNeeds = 0;
      let actualWants = 0;
      expenseRows.forEach(row => {
        if (row.budget_bucket === 'needs') {
          actualNeeds += Number(row.total);
        } else if (row.budget_bucket === 'wants') {
          actualWants += Number(row.total);
        }
      });

      // Get confirmed savings
      const actualSavings = await SettlementRepository.getConfirmedSavingsByCycle(cycleId);

      // Get total confirmed outflows
      const totalActualOutflows = await SettlementRepository.getTotalConfirmedOutflowsByCycle(cycleId);

      // Get unpaid commitments
      const unpaidCommitments = await SettlementRepository.getUnpaidCommitmentsByCycle(userId, cycleId);
      const totalUnpaidCommitments = unpaidCommitments.reduce((sum, occ) => sum + Number(occ.amount), 0);

      // Calculate settlement values
      const expectedIncome = Number(cycle.expected_income) || 0;
      const actualIncome = actualRecurringIncome + unexpectedIncome;
      const plannedNeeds = Number(snapshot.needs_target) || 0;
      const plannedWants = Number(snapshot.wants_target) || 0;
      const plannedSavings = Number(snapshot.savings_target) || 0;

      const netCycleResult = actualIncome - totalActualOutflows;
      let surplus = 0;
      let deficit = 0;

      if (netCycleResult > 0) {
        surplus = netCycleResult;
      } else if (netCycleResult < 0) {
        deficit = Math.abs(netCycleResult);
      }

      // Calculate variances
      const incomeVariance = actualIncome - expectedIncome;
      const needsVariance = actualNeeds - plannedNeeds;
      const wantsVariance = actualWants - plannedWants;
      const savingsVariance = actualSavings - plannedSavings;

      // Data quality warnings
      const warnings = [];
      if (actualIncome === 0) warnings.push('NO_CONFIRMED_INCOME');
      if (unpaidCommitments.length > 0) warnings.push('UNPAID_COMMITMENTS');
      if (incomeVariance < -expectedIncome * 0.2) warnings.push('INCOME_SHORTAGE');

      // Determine allowed settlement actions
      const allowedActions = [];
      if (surplus > 0) {
        allowedActions.push('carry_forward', 'emergency_fund', 'goal_allocation', 'unallocated_savings');
      }

      return {
        cycle: {
          id: cycleId,
          startDate: cycle.start_date,
          endDate: cycle.end_date,
          status: cycle.status,
          expectedIncome
        },
        income: {
          expected: expectedIncome,
          actual: actualIncome,
          actualRecurring: actualRecurringIncome,
          unexpected: unexpectedIncome,
          variance: incomeVariance
        },
        needs: {
          planned: plannedNeeds,
          actual: actualNeeds,
          variance: needsVariance
        },
        wants: {
          planned: plannedWants,
          actual: actualWants,
          variance: wantsVariance
        },
        savings: {
          planned: plannedSavings,
          actual: actualSavings,
          variance: savingsVariance
        },
        outflows: {
          total: totalActualOutflows
        },
        result: {
          netCycleResult,
          surplus,
          deficit
        },
        commitments: {
          unpaid: unpaidCommitments.map(occ => ({
            id: occ.id,
            name: occ.commitment_name,
            amount: Number(occ.amount),
            status: occ.status
          })),
          totalUnpaid: totalUnpaidCommitments
        },
        warnings,
        allowedActions,
        reliability: warnings.length === 0 ? 'reliable' : 'partial'
      };
    } finally {
      conn.release();
    }
  }

  /**
   * POST /financial-cycles/current/settlement
   *
   * Begin settlement by transitioning cycle to settlement_pending
   * and creating a pending settlement record.
   * Uses idempotency.
   */
  static async beginSettlement(userId, { idempotencyKey } = {}) {
    // First, check if settlement already exists without locking (for idempotency)
    const [cycles] = await db.execute(
      `SELECT id, status FROM financial_cycles WHERE user_id = ? AND status IN ('open', 'settlement_pending') ORDER BY created_at DESC LIMIT 1`,
      [userId]
    );
    
    if (cycles.length > 0) {
      const cycleId = cycles[0].id;
      const existingSettlement = await SettlementRepository.findSettlementByCycleId(cycleId);
      if (existingSettlement) {
        if (existingSettlement.status === 'pending') {
          // Return existing pending settlement (idempotent replay)
          return {
            settlementId: existingSettlement.id,
            cycleId,
            status: existingSettlement.status,
            replayed: true
          };
        } else {
          throw new AppError('Settlement already exists and is not pending.', 409, 'SETTLEMENT_ALREADY_EXISTS');
        }
      }
    }

    // No existing settlement, proceed with creation
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // Lock the open cycle for creation
      const cycle = await SettlementRepository.lockOpenCycle(conn, userId);
      if (!cycle) {
        throw new AppError('No active financial cycle found.', 404, 'NO_ACTIVE_FINANCIAL_CYCLE');
      }

      const cycleId = cycle.id;

      // Calculate fresh settlement preview
      const preview = await this._calculateSettlementValues(conn, userId, cycleId, cycle);

      // Create pending settlement
      const settlementId = await SettlementRepository.createSettlement(conn, {
        cycleId,
        expectedIncome: preview.expectedIncome,
        actualRecurringIncome: preview.actualRecurringIncome,
        unexpectedIncome: preview.unexpectedIncome,
        plannedNeeds: preview.plannedNeeds,
        actualNeeds: preview.actualNeeds,
        plannedWants: preview.plannedWants,
        actualWants: preview.actualWants,
        plannedSavings: preview.plannedSavings,
        actualSavings: preview.actualSavings,
        totalActualOutflows: preview.totalActualOutflows,
        surplus: preview.surplus,
        deficit: preview.deficit
      });

      // Update cycle status to settlement_pending
      await SettlementRepository.updateCycleStatusToPending(conn, cycleId);

      await conn.commit();

      return {
        settlementId,
        cycleId,
        status: 'pending',
        replayed: false
      };
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  /**
   * POST /financial-cycles/current/close
   *
   * Close cycle by executing settlement actions and marking cycle as closed.
   * Requires cycle status = settlement_pending.
   */
  static async closeCycle(userId, { actions, idempotencyKey } = {}) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // Find current cycle (settlement_pending)
      const cycle = await SettlementRepository.lockCurrentCycle(conn, userId);
      if (!cycle) {
        throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
      }

      if (cycle.status !== 'settlement_pending') {
        throw new AppError('Cycle must be in settlement_pending status to close.', 409, 'INVALID_CYCLE_STATUS');
      }

      const cycleId = cycle.id;

      // Lock settlement
      const settlement = await SettlementRepository.lockSettlementByCycleId(conn, cycleId);
      if (!settlement) {
        throw new AppError('Settlement not found.', 404, 'SETTLEMENT_NOT_FOUND');
      }

      // Recalculate official settlement values
      const currentValues = await this._calculateSettlementValues(conn, userId, cycleId, cycle);

      // Validate that financial data hasn't changed significantly
      const tolerance = 1; // Allow 1 unit difference for floating point
      if (
        Math.abs(currentValues.surplus - Number(settlement.surplus)) > tolerance ||
        Math.abs(currentValues.deficit - Number(settlement.deficit)) > tolerance
      ) {
        throw new AppError('Financial data has changed since settlement began. Please review the updated preview.', 409, 'SETTLEMENT_DATA_CHANGED');
      }

      const surplus = Number(settlement.surplus);
      const deficit = Number(settlement.deficit);

      // Validate actions
      if (surplus > 0) {
        if (!actions || actions.length === 0) {
          throw new AppError('Settlement actions required when surplus exists.', 422, 'SETTLEMENT_ACTIONS_REQUIRED');
        }

        const actionTotal = actions.reduce((sum, action) => sum + Number(action.amount), 0);
        if (actionTotal !== surplus) {
          throw new AppError(
            `Settlement action totals (${actionTotal}) must equal distributable surplus (${surplus}).`,
            422,
            'SETTLEMENT_ACTIONS_MISMATCH'
          );
        }

        // Validate each action
        for (const action of actions) {
          await this._validateSettlementAction(conn, userId, action);
        }
      } else if (surplus === 0) {
        if (actions && actions.length > 0) {
          throw new AppError('No settlement actions allowed when surplus is zero.', 422, 'SURPLUS_ACTION_NOT_ALLOWED');
        }
      } else {
        // Deficit case - no surplus actions allowed
        if (actions && actions.length > 0) {
          throw new AppError('No surplus actions allowed when deficit exists.', 422, 'DEFICIT_HAS_NO_DISTRIBUTABLE_SURPLUS');
        }
      }

      // Create settlement actions and execute them
      if (surplus > 0 && actions) {
        for (const action of actions) {
          const actionId = await SettlementRepository.createSettlementAction(conn, {
            settlementId: settlement.id,
            actionType: action.actionType,
            amount: action.amount,
            targetGoalId: action.goalId || null,
            description: action.description || null
          });

          // Execute the action
          await this._executeSettlementAction(conn, userId, cycleId, action);
        }
      }

      // Approve settlement
      await SettlementRepository.approveSettlement(conn, settlement.id);

      // Close cycle
      await SettlementRepository.updateCycleStatusToClosed(conn, cycleId);

      await conn.commit();

      return {
        settlementId: settlement.id,
        cycleId,
        status: 'closed',
        surplus,
        deficit,
        actionsExecuted: actions ? actions.length : 0
      };
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  /**
   * Internal helper to calculate settlement values.
   * Used by both preview and begin settlement.
   */
  static async _calculateSettlementValues(conn, userId, cycleId, cycle = null) {
    // Get cycle snapshot
    const snapshot = await SettlementRepository.getCycleSnapshot(cycleId);
    const plannedNeeds = Number(snapshot?.needs_target) || 0;
    const plannedWants = Number(snapshot?.wants_target) || 0;
    const plannedSavings = Number(snapshot?.savings_target) || 0;

    // Get cycle for expected income (use passed cycle if available)
    if (!cycle) {
      cycle = await CycleRepository.findCycleById(userId, cycleId);
    }
    const expectedIncome = Number(cycle?.expected_income) || 0;

    // Get confirmed income
    const incomeRows = await SettlementRepository.getConfirmedIncomeByCycle(cycleId);
    let actualRecurringIncome = 0;
    let unexpectedIncome = 0;
    incomeRows.forEach(row => {
      if (row.income_kind === 'recurring') {
        actualRecurringIncome += Number(row.total);
      } else if (row.income_kind === 'unexpected') {
        unexpectedIncome += Number(row.total);
      }
    });

    // Get confirmed expenses
    const expenseRows = await SettlementRepository.getConfirmedExpensesByCycle(cycleId);
    let actualNeeds = 0;
    let actualWants = 0;
    expenseRows.forEach(row => {
      if (row.budget_bucket === 'needs') {
        actualNeeds += Number(row.total);
      } else if (row.budget_bucket === 'wants') {
        actualWants += Number(row.total);
      }
    });

    // Get confirmed savings
    const actualSavings = await SettlementRepository.getConfirmedSavingsByCycle(cycleId);

    // Get total outflows
    const totalActualOutflows = await SettlementRepository.getTotalConfirmedOutflowsByCycle(cycleId);

    // Calculate surplus/deficit
    const actualIncome = actualRecurringIncome + unexpectedIncome;
    const netCycleResult = actualIncome - totalActualOutflows;
    let surplus = 0;
    let deficit = 0;

    if (netCycleResult > 0) {
      surplus = netCycleResult;
    } else if (netCycleResult < 0) {
      deficit = Math.abs(netCycleResult);
    }

    return {
      expectedIncome,
      actualRecurringIncome,
      unexpectedIncome,
      plannedNeeds,
      actualNeeds,
      plannedWants,
      actualWants,
      plannedSavings,
      actualSavings,
      totalActualOutflows,
      surplus,
      deficit
    };
  }

  /**
   * Validate a settlement action.
   */
  static async _validateSettlementAction(conn, userId, action) {
    const { actionType, amount, goalId, description } = action;

    if (amount <= 0) {
      throw new AppError('Action amount must be positive.', 422, 'INVALID_ACTION_AMOUNT');
    }

    const validActionTypes = ['carry_forward', 'emergency_fund', 'goal_allocation', 'unallocated_savings', 'custom'];
    if (!validActionTypes.includes(actionType)) {
      throw new AppError('Invalid action type.', 422, 'INVALID_ACTION_TYPE');
    }

    if (actionType === 'goal_allocation') {
      if (!goalId) {
        throw new AppError('goalId is required for goal_allocation action.', 422, 'GOAL_ID_REQUIRED');
      }
      const goal = await SettlementRepository.findGoalForUpdate(conn, goalId, userId);
      if (!goal) {
        throw new AppError('Goal not found or access denied.', 404, 'GOAL_NOT_FOUND');
      }
      if (goal.status !== 'active' && goal.status !== 'paused') {
        throw new AppError('Goal must be active or paused to receive allocation.', 422, 'INVALID_GOAL_STATUS');
      }
    }

    if (actionType === 'custom' && !description) {
      throw new AppError('Description is required for custom action.', 422, 'DESCRIPTION_REQUIRED');
    }
  }

  /**
   * Execute a settlement action.
   */
  static async _executeSettlementAction(conn, userId, cycleId, action) {
    const { actionType, amount, goalId, description } = action;

    switch (actionType) {
      case 'carry_forward':
        // Record the amount for use by next cycle - no ledger movement in this phase
        break;

      case 'emergency_fund':
        // Create a traceable savings movement
        await SettlementRepository.createSavingsTransaction(conn, {
          userId,
          cycleId,
          amount,
          description: description || 'Emergency fund from cycle settlement'
        });
        break;

      case 'goal_allocation':
        // Create a traceable goal contribution
        const goal = await SettlementRepository.findGoalForUpdate(conn, goalId, userId);
        const currentBalance = Number(goal.current_balance) || 0;
        const targetAmount = Number(goal.target_amount) || 0;
        const newBalance = currentBalance + amount;

        if (newBalance > targetAmount) {
          throw new AppError('Goal allocation would cause overfunding.', 422, 'GOAL_OVERFUNDING');
        }

        await SettlementRepository.updateGoalBalance(conn, goalId, newBalance);
        await SettlementRepository.createGoalTransaction(conn, {
          userId,
          goalId,
          amount,
          description: description || 'Cycle settlement allocation'
        });
        break;

      case 'unallocated_savings':
        // Record a traceable unallocated-savings movement
        await SettlementRepository.createSavingsTransaction(conn, {
          userId,
          cycleId,
          amount,
          description: description || 'Unallocated savings from cycle settlement'
        });
        break;

      case 'custom':
        // Require explicitly supported destination
        if (!description) {
          throw new AppError('Description required for custom action.', 422, 'DESCRIPTION_REQUIRED');
        }
        // For now, record as savings with custom description
        await SettlementRepository.createSavingsTransaction(conn, {
          userId,
          cycleId,
          amount,
          description: `Custom: ${description}`
        });
        break;

      default:
        throw new AppError('Unsupported action type.', 422, 'UNSUPPORTED_ACTION_TYPE');
    }
  }
}

module.exports = { SettlementService };
