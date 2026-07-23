const crypto = require('crypto');
const { db } = require('../config/database');
const { FinanceRepository } = require('../repositories/finance.repository');
const { CycleRepository } = require('../repositories/cycle.repository');
const { AppError } = require('../utils/app-error');

class FinanceService {
  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------
  static normalizeMoney(amount, fieldName = 'amount', { allowZero = false } = {}) {
    const num = Number(amount);
    if (!Number.isFinite(num)) {
      throw new AppError(`Invalid ${fieldName}: must be a finite number`, 422, 'INVALID_AMOUNT');
    }
    const rounded = Math.round(num);
    if (!Number.isSafeInteger(rounded)) {
      throw new AppError(`Invalid ${fieldName}: amount too large`, 422, 'INVALID_AMOUNT');
    }
    if (allowZero) {
      if (rounded < 0) throw new AppError(`Invalid ${fieldName}: cannot be negative`, 422, 'INVALID_AMOUNT');
    } else {
      if (rounded <= 0) throw new AppError(`Invalid ${fieldName}: must be greater than zero`, 422, 'INVALID_AMOUNT');
    }
    return rounded;
  }

  static normalizeIdempotencyKey(key, required = false) {
    if (!key) {
      if (required) throw new AppError('idempotencyKey is required', 400, 'INVALID_IDEMPOTENCY_KEY');
      return null;
    }
    const trimmed = String(key).trim();
    if (trimmed.length < 8 || trimmed.length > 128) {
      throw new AppError('idempotencyKey length must be between 8 and 128 characters', 400, 'INVALID_IDEMPOTENCY_KEY');
    }
    return trimmed;
  }

  static normalizeDate(dateString, fieldName = 'date', required = false) {
    if (!dateString) {
      if (required) throw new AppError(`${fieldName} is required`, 400, 'INVALID_DATE');
      return null;
    }
    const d = new Date(dateString);
    if (isNaN(d.getTime())) {
      throw new AppError(`Invalid ${fieldName}`, 400, 'INVALID_DATE');
    }
    return d.toISOString().split('T')[0];
  }

  // ---------------------------------------------------------
  // EXPENSES
  // ---------------------------------------------------------
  static async getExpenses(userId) {
    const rawExpenses = await FinanceRepository.getExpenses(userId);
    const formatted = rawExpenses.map(row => ({
      id: row.id,
      amount: Number(row.amount || 0),
      bucket: row.bucket,
      category: row.category,
      paymentMethod: row.paymentMethod,
      description: row.description,
      sourceType: row.sourceType,
      date: row.date
    }));
    return { items: formatted, total: formatted.length };
  }

  static async createExpense(userId, data) {
    if (data.userId !== undefined || data.cycleId !== undefined) {
      throw new AppError('userId or cycleId must not be provided in payload', 400, 'INVALID_PAYLOAD');
    }

    const amount = this.normalizeMoney(data.amount, 'amount');

    const bucket = data.bucket;
    if (!bucket || !['needs', 'wants'].includes(bucket)) {
      throw new AppError('Bucket must be either needs or wants', 400, 'INVALID_BUCKET');
    }

    const needsCategories = ['rent', 'electricity', 'water', 'internet', 'transportation', 'healthcare', 'education', 'family', 'loan', 'other'];
    const wantsCategories = ['restaurant', 'coffee', 'entertainment', 'shopping', 'travel', 'subscription', 'hobbies', 'other'];
    const allowedCategories = bucket === 'needs' ? needsCategories : wantsCategories;

    const category = data.category;
    if (!category || !allowedCategories.includes(category)) {
      throw new AppError(`Invalid category for bucket ${bucket}`, 400, 'INVALID_CATEGORY');
    }

    const paymentMethod = data.paymentMethod || 'cash';
    if (!['cash', 'card', 'wallet', 'bank_transfer', 'other'].includes(paymentMethod)) {
      throw new AppError('Invalid payment method', 400, 'INVALID_PAYMENT_METHOD');
    }

    const sourceType = data.sourceType || 'manual';
    if (!['manual', 'image', 'voice'].includes(sourceType)) {
      throw new AppError('Invalid source type', 400, 'INVALID_SOURCE_TYPE');
    }

    const expenseDate = this.normalizeDate(data.expenseDate, 'expenseDate') || new Date().toISOString().split('T')[0];
    const description = data.description ? String(data.description).trim() : null;

    let originalImageUrl = null;
    if (data.originalImageUrl) {
      originalImageUrl = String(data.originalImageUrl).trim();
      if (originalImageUrl.length > 255) throw new AppError('originalImageUrl too long', 400, 'INVALID_PAYLOAD');
    }

    let originalTranscript = null;
    if (data.originalTranscript) {
      originalTranscript = String(data.originalTranscript).trim();
      if (originalTranscript.length > 10000) throw new AppError('originalTranscript too long', 400, 'INVALID_PAYLOAD');
    }

    const normalizedData = {
      amount, bucket, category, paymentMethod, sourceType, expenseDate, description, originalImageUrl, originalTranscript
    };

    const conn = await db.getConnection();
    let transactionActive = false;
    try {
      await conn.beginTransaction();
      transactionActive = true;

      const openCycle = await FinanceRepository.lockOpenCycleForUser(conn, userId);
      if (!openCycle) {
        throw new AppError('No active financial cycle. Create a cycle before adding transactions.', 422, 'NO_ACTIVE_FINANCIAL_CYCLE');
      }

      normalizedData.cycleId = openCycle.id;
      const id = await FinanceRepository.createExpense(conn, userId, normalizedData);

      await conn.commit();
      transactionActive = false;
      return { id, ...normalizedData };
    } catch (err) {
      if (transactionActive) await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  static async deleteExpense(userId, expenseId) {
    const conn = await db.getConnection();
    let transactionActive = false;
    try {
      await conn.beginTransaction();
      transactionActive = true;

      const txLock = await FinanceRepository.lockTransactionForMutation(conn, userId, expenseId, 'expense');
      if (!txLock) {
        throw new AppError('Expense not found or unauthorized', 404, 'NOT_FOUND');
      }
      if (txLock.cycle_status !== 'open') {
        throw new AppError('Cannot delete transactions in a closed cycle.', 409, 'CLOSED_CYCLE_IMMUTABLE');
      }

      const success = await FinanceRepository.deleteExpense(conn, userId, expenseId);
      if (!success) {
        throw new AppError('Expense not found or unauthorized', 404, 'NOT_FOUND');
      }
      await conn.commit();
      transactionActive = false;
      return { success: true };
    } catch (err) {
      if (transactionActive) await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  // ---------------------------------------------------------
  // INCOMES
  // ---------------------------------------------------------
  static async getIncomes(userId) {
    const rawIncomes = await FinanceRepository.getIncomes(userId);
    const formatted = rawIncomes.map(row => ({
      id: row.id,
      amount: Number(row.amount || 0),
      source: row.source,
      description: row.description,
      incomeDate: row.incomeDate,
      isRecurring: row.incomeKind === 'recurring',
      createdAt: row.createdAt
    }));
    return { items: formatted, total: formatted.length };
  }

  static async createIncome(userId, data) {
    if (data.userId !== undefined || data.cycleId !== undefined) {
      throw new AppError('userId or cycleId must not be provided in payload', 400, 'INVALID_PAYLOAD');
    }

    const amount = this.normalizeMoney(data.amount, 'amount');
    const source = data.source || 'uncategorized';
    const description = data.description ? String(data.description).trim() : null;
    const incomeDate = this.normalizeDate(data.incomeDate, 'incomeDate') || new Date().toISOString().split('T')[0];
    const isRecurring = !!data.isRecurring;

    const sourceType = data.sourceType || 'manual';
    if (!['manual', 'image', 'voice'].includes(sourceType)) {
      throw new AppError('Invalid source type', 400, 'INVALID_SOURCE_TYPE');
    }

    let originalImageUrl = null;
    if (data.originalImageUrl) {
      originalImageUrl = String(data.originalImageUrl).trim();
      if (originalImageUrl.length > 255) throw new AppError('originalImageUrl too long', 400, 'INVALID_PAYLOAD');
    }

    let originalTranscript = null;
    if (data.originalTranscript) {
      originalTranscript = String(data.originalTranscript).trim();
      if (originalTranscript.length > 10000) throw new AppError('originalTranscript too long', 400, 'INVALID_PAYLOAD');
    }

    const normalizedData = {
      amount, source, description, incomeDate, isRecurring, sourceType, originalImageUrl, originalTranscript
    };

    const conn = await db.getConnection();
    let transactionActive = false;
    try {
      await conn.beginTransaction();
      transactionActive = true;

      const openCycle = await FinanceRepository.lockOpenCycleForUser(conn, userId);
      if (!openCycle) {
        throw new AppError('No active financial cycle. Create a cycle before adding transactions.', 422, 'NO_ACTIVE_FINANCIAL_CYCLE');
      }

      normalizedData.cycleId = openCycle.id;
      const id = await FinanceRepository.createIncome(conn, userId, normalizedData);

      await conn.commit();
      transactionActive = false;
      return { id, ...normalizedData };
    } catch (err) {
      if (transactionActive) await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  static async deleteIncome(userId, incomeId) {
    const conn = await db.getConnection();
    let transactionActive = false;
    try {
      await conn.beginTransaction();
      transactionActive = true;

      const txLock = await FinanceRepository.lockTransactionForMutation(conn, userId, incomeId, 'income');
      if (!txLock) {
        throw new AppError('Income not found or unauthorized', 404, 'NOT_FOUND');
      }
      if (txLock.cycle_status !== 'open') {
        throw new AppError('Cannot delete transactions in a closed cycle.', 409, 'CLOSED_CYCLE_IMMUTABLE');
      }

      const success = await FinanceRepository.deleteIncome(conn, userId, incomeId);
      if (!success) {
        throw new AppError('Income not found or unauthorized', 404, 'NOT_FOUND');
      }
      await conn.commit();
      transactionActive = false;
      return { success: true };
    } catch (err) {
      if (transactionActive) await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  // ---------------------------------------------------------
  // GOALS
  // ---------------------------------------------------------
  static async getGoals(userId) {
    const rawGoals = await FinanceRepository.getGoals(userId);
    const formatted = rawGoals.map(row => {
      const targetAmount = Number(row.target_amount || 0);
      const currentBalance = Number(row.current_balance || 0);
      const monthlyContribution = Number(row.cycle_allocation || 0);

      const remainingAmount = Math.max(0, targetAmount - currentBalance);
      const requiredCycles = monthlyContribution > 0 ? Math.ceil(remainingAmount / monthlyContribution) : 0;

      return {
        id: row.id,
        name: row.name,
        targetAmount,
        currentBalance,
        monthlyContribution,
        remainingAmount,
        requiredCycles,
        priority: row.priority,
        status: row.status
      };
    });
    return { items: formatted, total: formatted.length };
  }

  static planningPreview(data) {
    const targetAmount = this.normalizeMoney(data.targetAmount, 'targetAmount');
    const plannedContribution = data.plannedContribution !== undefined
      ? this.normalizeMoney(data.plannedContribution, 'plannedContribution', { allowZero: true })
      : 0;

    const result = {
      isEstimated: true,
      remainingAmount: targetAmount,
      cyclesRequired: null,
      requiredContribution: null,
    };

    if (data.planningMode === 'contribution_based') {
      if (plannedContribution > 0) {
        result.cyclesRequired = Math.ceil(result.remainingAmount / plannedContribution);
      }
    } else if (data.planningMode === 'deadline_based') {
      if (data.targetDate) {
        const d = new Date(data.targetDate);
        if (!isNaN(d.getTime())) {
          const now = new Date();
          let months = (d.getFullYear() - now.getFullYear()) * 12 + (d.getMonth() - now.getMonth());
          if (d.getDate() < now.getDate()) months--;
          const estimatedPeriodsRemaining = Math.max(1, months);
          result.requiredContribution = Math.ceil(result.remainingAmount / estimatedPeriodsRemaining);
        }
      }
    }

    return result;
  }

  static validateGoalData(data, currentBalance = 0) {
    const validGoalTypes = [
      'emergency_fund', 'laptop', 'travel', 'religious_travel',
      'holiday_expenses', 'tuition', 'car_down_payment',
      'home_down_payment', 'business_startup',
      'electrical_appliances', 'furniture',
      'clothing_accessories', 'custom'
    ];

    if (!validGoalTypes.includes(data.goalType)) {
      throw new AppError('Unsupported goal type', 400, 'INVALID_GOAL_TYPE');
    }
    if (data.goalType === 'custom' && !data.customName) {
      throw new AppError('Custom name is required for custom goals', 400, 'INVALID_CUSTOM_NAME');
    }

    const targetAmount = this.normalizeMoney(data.targetAmount, 'targetAmount');
    if (targetAmount < currentBalance) {
      throw new AppError('Target amount cannot be lower than current balance', 400, 'INVALID_TARGET_AMOUNT');
    }

    const priority = Number(data.priority);
    if (!Number.isSafeInteger(priority) || priority < 1 || priority > 10) {
      throw new AppError('Priority must be an integer between 1 and 10', 400, 'INVALID_PRIORITY');
    }

    let plannedContribution = 0;
    let targetDate = null;
    const planningMode = data.planningMode;

    if (planningMode === 'contribution_based') {
      plannedContribution = this.normalizeMoney(data.plannedContribution, 'plannedContribution');
    } else if (planningMode === 'deadline_based') {
      targetDate = this.normalizeDate(data.targetDate, 'targetDate', true);
      const dateObj = new Date(targetDate);
      const now = new Date();
      now.setHours(0,0,0,0);
      const sevenYearsFromNow = new Date(now);
      sevenYearsFromNow.setFullYear(sevenYearsFromNow.getFullYear() + 7);

      if (dateObj < now) {
        throw new AppError('Target date cannot be in the past', 400, 'INVALID_TARGET_DATE');
      }
      if (dateObj > sevenYearsFromNow) {
        throw new AppError('Target date cannot be more than 7 years ahead', 400, 'INVALID_TARGET_DATE');
      }
      
      if (data.plannedContribution !== undefined && data.plannedContribution !== null && data.plannedContribution !== '') {
        plannedContribution = this.normalizeMoney(data.plannedContribution, 'plannedContribution');
      }
    } else {
      throw new AppError('Invalid planning mode', 400, 'INVALID_PLANNING_MODE');
    }
    
    if (plannedContribution > targetAmount) {
      throw new AppError('Planned contribution cannot exceed target amount', 400, 'INVALID_PLANNED_CONTRIBUTION');
    }

    const customName = data.customName ? String(data.customName).trim() : null;

    return {
      goalType: data.goalType,
      customName,
      targetAmount,
      plannedContribution,
      targetDate,
      planningMode,
      priority
    };
  }

  static async createGoal(userId, data) {
    const normalizedData = this.validateGoalData(data, 0);
    const id = await FinanceRepository.createGoal(userId, normalizedData);
    return { goalId: id };
  }

  static async updateGoal(userId, goalId, data) {
    const goals = await FinanceRepository.getGoals(userId);
    const goal = goals.find(g => String(g.id) === String(goalId));

    if (!goal) {
      throw new AppError('Goal not found', 404, 'NOT_FOUND');
    }
    if (goal.status === 'executed') {
      throw new AppError('Executed goals cannot be edited', 400, 'GOAL_ALREADY_EXECUTED');
    }

    const normalizedData = this.validateGoalData(data, Number(goal.current_balance));

    await FinanceRepository.updateGoal(userId, goalId, normalizedData);
    return { success: true, goalId };
  }

  static async addGoalContribution(userId, goalId, data) {
    if (data.userId !== undefined) {
      throw new AppError('userId must not be provided in payload', 400, 'INVALID_PAYLOAD');
    }

    const amount = this.normalizeMoney(data.amount, 'amount');
    const idempotencyKey = this.normalizeIdempotencyKey(data.idempotencyKey, true);
    const description = data.description ? String(data.description).trim() : null;

    const requestHash = crypto.createHash('sha256')
      .update(`contribution|${userId}|${goalId}|${amount}|${description || ''}`)
      .digest('hex');

    const connection = await db.getConnection();
    let transactionActive = false;
    try {
      await connection.beginTransaction();
      transactionActive = true;

      const existingTx = await FinanceRepository.findIdempotencyRecord(connection, userId, idempotencyKey);
      if (existingTx) {
        if (existingTx.request_hash === requestHash) {
          await connection.rollback();
          transactionActive = false;
          return { success: true, replayed: true, transaction: existingTx };
        }
        throw new AppError('Idempotency key reused with different payload', 409, 'IDEMPOTENCY_KEY_REUSED');
      }

      const goal = await FinanceRepository.findGoalForUpdate(connection, goalId, userId);
      if (!goal) {
        throw new AppError('Goal not found or unauthorized', 404, 'NOT_FOUND');
      }
      if (goal.status !== 'active') {
        throw new AppError(`Cannot contribute to a ${goal.status} goal`, 400, 'INVALID_GOAL_STATUS');
      }

      const targetAmount = Number(goal.target_amount);
      const currentBalance = Number(goal.current_balance || 0);
      if (!Number.isSafeInteger(targetAmount) || !Number.isSafeInteger(currentBalance) || targetAmount <= 0 || currentBalance < 0) {
        throw new AppError('Goal financial data invalid', 500, 'GOAL_FINANCIAL_DATA_INVALID');
      }

      const remainingAmount = targetAmount - currentBalance;

      if (amount > remainingAmount) {
        throw new AppError('Contribution exceeds the remaining goal amount.', 409, 'GOAL_CONTRIBUTION_EXCEEDS_REMAINING');
      }

      let transaction;
      try {
        transaction = await FinanceRepository.createGoalTransaction(connection, {
          userId, goalId, amount, transactionType: 'contribution', idempotencyKey, requestHash, description
        });
      } catch (err) {
        if (err.code === 'CONCURRENT_IDEMPOTENT_REPLAY') {
          await connection.rollback();
          transactionActive = false;
          return { success: true, replayed: true, transaction: err.existingTransaction };
        }
        throw err;
      }

      const newBalance = currentBalance + amount;
      let newStatus = 'active';
      let readyAt = null;

      if (newBalance >= targetAmount) {
        newStatus = 'ready';
        readyAt = new Date().toISOString().split('T')[0];
      }

      await FinanceRepository.updateGoalBalanceAndStatus(connection, {
        goalId, userId, newBalance, newStatus, readyAt
      });

      await connection.commit();
      transactionActive = false;

      return {
        success: true,
        goal: {
          id: goal.id,
          targetAmount,
          currentAmount: newBalance,
          remainingAmount: targetAmount - newBalance,
          progressPercent: ((newBalance / targetAmount) * 100).toFixed(2),
          status: newStatus,
          readyAt
        },
        transaction
      };

    } catch (error) {
      if (transactionActive) await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async getReadyGoals(userId) {
    return await FinanceRepository.getReadyGoals(userId);
  }

  static async getGoalTransactions(userId, goalId, limit = 50, offset = 0) {
    const l = Number(limit);
    const o = Number(offset);
    if (!Number.isSafeInteger(l) || l < 1 || l > 100) throw new AppError('Invalid limit', 400, 'INVALID_PAGINATION');
    if (!Number.isSafeInteger(o) || o < 0) throw new AppError('Invalid offset', 400, 'INVALID_PAGINATION');

    const goal = await FinanceRepository.getGoals(userId);
    if (!goal.some(g => String(g.id) === String(goalId))) {
      throw new AppError('Goal not found or unauthorized', 404, 'NOT_FOUND');
    }
    return await FinanceRepository.getGoalTransactions(userId, goalId, l, o);
  }

  static async changeGoalStatus(userId, goalId, newStatus) {
    const connection = await db.getConnection();
    let transactionActive = false;
    try {
      await connection.beginTransaction();
      transactionActive = true;
      const goal = await FinanceRepository.findGoalForUpdate(connection, goalId, userId);
      if (!goal) {
        throw new AppError('Goal not found or unauthorized', 404, 'NOT_FOUND');
      }

      if (newStatus === 'paused') {
        if (goal.status !== 'active') throw new AppError(`Cannot pause a ${goal.status} goal`, 400, 'INVALID_STATUS');
      } else if (newStatus === 'active') {
        if (goal.status !== 'paused') throw new AppError(`Cannot resume a ${goal.status} goal`, 400, 'INVALID_STATUS');
      } else {
        throw new AppError(`Invalid status transition to ${newStatus}`, 400, 'INVALID_STATUS');
      }

      await FinanceRepository.updateGoalBalanceAndStatus(connection, {
        goalId, userId,
        newBalance: goal.current_balance,
        newStatus,
        readyAt: goal.ready_at
      });

      await connection.commit();
      transactionActive = false;
      return { success: true, status: newStatus };
    } catch (error) {
      if (transactionActive) await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async deleteGoal(userId, goalId) {
    const success = await FinanceRepository.deleteGoal(userId, goalId);
    if (!success) {
      throw new AppError('Goal not found or unauthorized', 404, 'NOT_FOUND');
    }
    return { success: true };
  }

  static async executeGoal(userId, goalId, idempotencyKeyParam) {
    const idempotencyKey = this.normalizeIdempotencyKey(idempotencyKeyParam, true);

    const requestHash = crypto.createHash('sha256')
      .update(JSON.stringify({ operation: 'execute', userId, goalId }))
      .digest('hex');

    const connection = await db.getConnection();
    let transactionActive = false;
    try {
      await connection.beginTransaction();
      transactionActive = true;

      const existing = await FinanceRepository.findIdempotencyRecord(connection, userId, idempotencyKey);
      if (existing) {
        if (existing.request_hash === requestHash) {
          await connection.rollback();
          transactionActive = false;
          return { success: true, message: 'Goal executed successfully (idempotent)' };
        }
        throw new AppError('Idempotency key reused for a different request', 409, 'IDEMPOTENCY_KEY_REUSED');
      }

      const openCycle = await FinanceRepository.lockOpenCycleForUser(connection, userId);
      if (!openCycle) {
        throw new AppError('No active financial cycle to link execution expense.', 422, 'NO_ACTIVE_FINANCIAL_CYCLE');
      }

      const goal = await FinanceRepository.findGoalForUpdate(connection, goalId, userId);
      if (!goal) {
        throw new AppError('Goal not found or unauthorized', 404, 'NOT_FOUND');
      }
      if (goal.status !== 'ready') {
        throw new AppError('Goal is not in ready status', 400, 'BAD_REQUEST');
      }

      const targetAmount = Number(goal.target_amount);
      if (!Number.isSafeInteger(targetAmount) || targetAmount <= 0) {
        throw new AppError('Goal target amount invalid', 500, 'GOAL_FINANCIAL_DATA_INVALID');
      }

      const ledgerBalance = await FinanceRepository.getLedgerBalance(connection, goalId, userId);
      if (!Number.isSafeInteger(ledgerBalance) || ledgerBalance < 0) {
        throw new AppError('Ledger balance invalid', 500, 'GOAL_FINANCIAL_DATA_INVALID');
      }

      if (ledgerBalance < targetAmount) {
        throw new AppError('Goal balance is less than target amount', 400, 'BAD_REQUEST');
      }

      try {
        await FinanceRepository.createGoalTransaction(connection, {
          userId, goalId, amount: targetAmount, transactionType: 'execution',
          idempotencyKey, requestHash, description: 'Goal execution'
        });
      } catch (err) {
        if (err.code === 'CONCURRENT_IDEMPOTENT_REPLAY') {
          await connection.rollback();
          transactionActive = false;
          return { success: true, message: 'Goal executed successfully (idempotent replay)' };
        }
        throw err;
      }

      const insertId = await FinanceRepository.createCapitalExpense(connection, userId, targetAmount, goal.name, openCycle.id);

      const newBalance = ledgerBalance - targetAmount;
      const executedAt = new Date().toISOString().replace('T', ' ').substring(0, 19);
      await FinanceRepository.updateGoalBalanceAndStatus(connection, {
        goalId, userId, newBalance, newStatus: 'executed', executedAt, readyAt: null
      });

      await connection.commit();
      transactionActive = false;
      return { success: true, message: 'Goal executed successfully' };
    } catch (error) {
      if (transactionActive) await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async deferGoal(userId, goalId) {
    const connection = await db.getConnection();
    let transactionActive = false;
    try {
      await connection.beginTransaction();
      transactionActive = true;

      const goal = await FinanceRepository.findGoalForUpdate(connection, goalId, userId);
      if (!goal) {
        throw new AppError('Goal not found or unauthorized', 404, 'NOT_FOUND');
      }
      if (goal.status !== 'ready') {
        throw new AppError('Goal is not in ready status', 400, 'BAD_REQUEST');
      }

      const affected = await FinanceRepository.updateGoalBalanceAndStatus(connection, {
        goalId, userId, newBalance: goal.current_balance, newStatus: 'active', readyAt: null
      });

      if (affected === 0) {
        throw new AppError('Could not defer goal', 500, 'UPDATE_FAILED');
      }

      await connection.commit();
      transactionActive = false;
      return { success: true, message: 'Goal deferred successfully' };
    } catch (error) {
      if (transactionActive) await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async reallocateGoal(userId, sourceGoalId, destinationGoalId, amountRaw, idempotencyKeyParam) {
    const amount = this.normalizeMoney(amountRaw, 'amount');
    const idempotencyKey = this.normalizeIdempotencyKey(idempotencyKeyParam, true);

    if (String(sourceGoalId) === String(destinationGoalId)) {
      throw new AppError('Source and destination goals must differ', 400, 'BAD_REQUEST');
    }

    const requestHash = crypto.createHash('sha256')
      .update(JSON.stringify({ operation: 'reallocate', userId, sourceGoalId, destinationGoalId, amount }))
      .digest('hex');

    const connection = await db.getConnection();
    let transactionActive = false;
    try {
      await connection.beginTransaction();
      transactionActive = true;

      const existing = await FinanceRepository.findIdempotencyRecord(connection, userId, idempotencyKey);
      if (existing) {
        if (existing.request_hash === requestHash) {
          await connection.rollback();
          transactionActive = false;
          return { success: true, message: 'Goal reallocated successfully (idempotent)' };
        }
        throw new AppError('Idempotency key reused for a different request', 409, 'IDEMPOTENCY_KEY_REUSED');
      }

      const sourceBigInt = BigInt(sourceGoalId);
      const destBigInt = BigInt(destinationGoalId);
      const firstId = sourceBigInt < destBigInt ? sourceGoalId : destinationGoalId;
      const secondId = sourceBigInt < destBigInt ? destinationGoalId : sourceGoalId;

      const firstGoal = await FinanceRepository.findGoalForUpdate(connection, firstId, userId);
      const secondGoal = await FinanceRepository.findGoalForUpdate(connection, secondId, userId);

      if (!firstGoal || !secondGoal) {
        throw new AppError('Goal not found or unauthorized', 404, 'NOT_FOUND');
      }

      const sourceGoal = String(firstId) === String(sourceGoalId) ? firstGoal : secondGoal;
      const destGoal = String(firstId) === String(destinationGoalId) ? firstGoal : secondGoal;

      if (sourceGoal.status !== 'ready') {
        throw new AppError('Source goal must be in ready status', 400, 'BAD_REQUEST');
      }
      if (destGoal.status !== 'active') {
        throw new AppError('Destination goal must be active', 400, 'BAD_REQUEST');
      }

      const sourceBalance = await FinanceRepository.getLedgerBalance(connection, sourceGoal.id, userId);
      if (!Number.isSafeInteger(sourceBalance) || sourceBalance < 0) {
        throw new AppError('Ledger balance invalid', 500, 'GOAL_FINANCIAL_DATA_INVALID');
      }
      if (amount > sourceBalance) {
        throw new AppError('Amount exceeds source goal balance', 400, 'BAD_REQUEST');
      }

      const destBalance = await FinanceRepository.getLedgerBalance(connection, destGoal.id, userId);
      if (!Number.isSafeInteger(destBalance) || destBalance < 0) {
        throw new AppError('Ledger balance invalid', 500, 'GOAL_FINANCIAL_DATA_INVALID');
      }
      const destTarget = Number(destGoal.target_amount);
      if (!Number.isSafeInteger(destTarget) || destTarget <= 0) {
        throw new AppError('Goal target amount invalid', 500, 'GOAL_FINANCIAL_DATA_INVALID');
      }

      if (destBalance + amount > destTarget) {
        throw new AppError('Reallocation amount causes destination overfunding', 400, 'BAD_REQUEST');
      }

      try {
        await FinanceRepository.createGoalTransaction(connection, {
          userId, goalId: sourceGoal.id, amount, transactionType: 'reallocation_out', relatedGoalId: destGoal.id,
          idempotencyKey, requestHash, description: `Reallocated to ${destGoal.name}`
        });
      } catch (err) {
        if (err.code === 'CONCURRENT_IDEMPOTENT_REPLAY') {
          await connection.rollback();
          transactionActive = false;
          return { success: true, message: 'Goal reallocated successfully (idempotent replay)' };
        }
        throw err;
      }

      await FinanceRepository.createGoalTransaction(connection, {
        userId, goalId: destGoal.id, amount, transactionType: 'reallocation_in', relatedGoalId: sourceGoal.id,
        idempotencyKey: null, requestHash: null, description: `Reallocated from ${sourceGoal.name}`
      });

      const newSourceBalance = sourceBalance - amount;
      const newSourceStatus = newSourceBalance < Number(sourceGoal.target_amount) ? 'active' : 'ready';
      let sourceReadyAt = sourceGoal.ready_at;
      if (newSourceStatus === 'active') sourceReadyAt = null;

      await FinanceRepository.updateGoalBalanceAndStatus(connection, {
        goalId: sourceGoal.id, userId, newBalance: newSourceBalance, newStatus: newSourceStatus, readyAt: sourceReadyAt
      });

      const newDestBalance = destBalance + amount;
      let newDestStatus = destGoal.status;
      let destReadyAt = destGoal.ready_at;
      if (newDestBalance === destTarget) {
        newDestStatus = 'ready';
        destReadyAt = new Date().toISOString().split('T')[0];
      }

      await FinanceRepository.updateGoalBalanceAndStatus(connection, {
        goalId: destGoal.id, userId, newBalance: newDestBalance, newStatus: newDestStatus, readyAt: destReadyAt
      });

      await connection.commit();
      transactionActive = false;
      return { success: true, message: 'Goal reallocated successfully' };
    } catch (error) {
      if (transactionActive) await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  // ---------------------------------------------------------
  // SAVINGS ALLOCATIONS
  // ---------------------------------------------------------
  static async savingsAllocationPreview(userId, savingsAmountRaw, emergencyFundRateRaw = 10.0, inputGoalAllocations = []) {
    const savingsAmount = this.normalizeMoney(savingsAmountRaw, 'savingsAmount', { allowZero: true });
    const emergencyFundRate = Number(emergencyFundRateRaw);
    if (!Number.isFinite(emergencyFundRate) || emergencyFundRate < 0 || emergencyFundRate > 100) {
      throw new AppError('Emergency fund rate must be between 0 and 100', 400, 'BAD_REQUEST');
    }

    const goals = await FinanceRepository.getGoals(userId);
    const activeGoals = goals.filter(g => g.status === 'active');

    const emergencyFundAmount = Math.round(savingsAmount * (emergencyFundRate / 100));

    let totalGoalAllocations = 0;
    const goalAllocations = [];
    const providedAmounts = {};

    for (const alloc of inputGoalAllocations) {
      if (!alloc.goalId) continue;
      if (providedAmounts[alloc.goalId] !== undefined) {
        throw new AppError('Duplicate goalId in input', 400, 'BAD_REQUEST');
      }
      providedAmounts[alloc.goalId] = this.normalizeMoney(alloc.amount || alloc.allocationAmount || 0, 'allocationAmount', { allowZero: true });
    }

    for (const goal of activeGoals) {
      const planned = providedAmounts[goal.id] !== undefined ? providedAmounts[goal.id] : Number(goal.planned_contribution || 0);
      const remaining = Number(goal.target_amount) - Number(goal.current_balance);
      if (planned > remaining) {
        throw new AppError(`Goal allocation exceeds remaining balance for goal ${goal.id}`, 400, 'BAD_REQUEST');
      }
      totalGoalAllocations += planned;
      goalAllocations.push({
        goalId: goal.id,
        name: goal.name,
        targetAmount: Number(goal.target_amount),
        currentBalance: Number(goal.current_balance),
        plannedContribution: planned
      });
    }

    const unallocatedSavings = savingsAmount - emergencyFundAmount - totalGoalAllocations;
    if (unallocatedSavings < 0) {
      throw new AppError('Total goal allocations exceed available savings amount after emergency fund', 400, 'SAVINGS_ALLOCATION_EXCEEDED');
    }

    return {
      savingsAmount,
      emergencyFundRate,
      emergencyFundAmount,
      totalGoalAllocations,
      unallocatedSavings,
      goals: goalAllocations
    };
  }

  static async getSavingsAllocation(userId) {
    const allocation = await FinanceRepository.getSavingsAllocation(userId);
    if (!allocation) {
      return {
        id: null,
        savingsAmount: 0,
        emergencyFundRate: 10.0,
        emergencyFundAmount: 0,
        totalGoalAllocations: 0,
        unallocatedSavingsAmount: 0,
        status: 'none',
        goals: []
      };
    }
    return allocation;
  }

  static async approveSavingsAllocation(userId, data) {
    if (data.userId !== undefined) {
      throw new AppError('userId must not be provided in payload', 400, 'INVALID_PAYLOAD');
    }
    const idempotencyKey = this.normalizeIdempotencyKey(data.idempotencyKey, true);

    const savingsAmount = this.normalizeMoney(data.savingsAmount, 'savingsAmount', { allowZero: true });
    const emergencyFundRate = Number(data.emergencyFundRate !== undefined ? data.emergencyFundRate : 10.0);
    if (!Number.isFinite(emergencyFundRate) || emergencyFundRate < 0 || emergencyFundRate > 100) {
      throw new AppError('Emergency fund rate must be between 0 and 100', 400, 'BAD_REQUEST');
    }

    const providedAmounts = {};
    for (const alloc of data.goals || []) {
      if (!alloc.goalId) continue;
      if (providedAmounts[alloc.goalId] !== undefined) {
        throw new AppError('Duplicate goalId in input', 400, 'BAD_REQUEST');
      }
      const val = this.normalizeMoney(alloc.amount || alloc.allocationAmount || 0, 'allocationAmount', { allowZero: true });
      if (val > 0) {
        providedAmounts[alloc.goalId] = val;
      }
    }

    const requestedGoalIds = Object.keys(providedAmounts);
    for (const gid of requestedGoalIds) {
      try { BigInt(gid); } catch(e) { throw new AppError('Invalid goalId format', 400, 'BAD_REQUEST'); }
    }
    requestedGoalIds.sort((a, b) => (BigInt(a) < BigInt(b) ? -1 : 1));

    const hashList = requestedGoalIds.map(id => ({ goalId: String(id), allocationAmount: providedAmounts[id] }));
    const requestHash = crypto.createHash('sha256')
      .update(`savings_alloc|${userId}|${savingsAmount}|${emergencyFundRate}|${JSON.stringify(hashList)}`)
      .digest('hex');

    const connection = await db.getConnection();
    let transactionActive = false;
    try {
      await connection.beginTransaction();
      transactionActive = true;

      await connection.execute('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId]);

      const [existing] = await connection.execute(
        'SELECT id, request_hash FROM savings_allocations WHERE user_id = ? AND idempotency_key = ?',
        [userId, idempotencyKey]
      );
      if (existing.length > 0) {
        if (existing[0].request_hash === requestHash) {
          await connection.rollback();
          transactionActive = false;
          return { success: true, replayed: true, message: 'Savings allocation approved successfully' };
        }
        throw new AppError('Idempotency key reused with different payload', 409, 'IDEMPOTENCY_KEY_REUSED');
      }

      let totalGoalAllocations = 0;
      for (const gid of requestedGoalIds) {
        const goal = await FinanceRepository.findGoalForUpdate(connection, gid, userId);
        if (!goal) throw new AppError(`Goal ${gid} not found`, 404, 'NOT_FOUND');
        if (goal.status !== 'active') throw new AppError(`Cannot allocate to ${goal.status} goal`, 400, 'INVALID_GOAL_STATUS');

        const remaining = Number(goal.target_amount) - Number(goal.current_balance);
        const planned = providedAmounts[gid];
        if (planned > remaining) {
          throw new AppError(`Goal allocation exceeds remaining balance for goal ${gid}`, 400, 'BAD_REQUEST');
        }
        totalGoalAllocations += planned;
      }

      const emergencyFundAmount = Math.round(savingsAmount * (emergencyFundRate / 100));
      const unallocatedSavingsAmount = savingsAmount - emergencyFundAmount - totalGoalAllocations;

      if (unallocatedSavingsAmount < 0) {
        throw new AppError('Total goal allocations exceed available savings amount after emergency fund', 400, 'SAVINGS_ALLOCATION_EXCEEDED');
      }

      await connection.execute("UPDATE savings_allocations SET status = 'superseded' WHERE user_id = ? AND status = 'provisional'", [userId]);

      const [allocRes] = await connection.execute(
        `INSERT INTO savings_allocations (
          user_id, savings_amount, emergency_fund_rate, emergency_fund_amount,
          total_goal_allocations, unallocated_savings_amount, status,
          idempotency_key, request_hash, approved_at
        ) VALUES (?, ?, ?, ?, ?, ?, 'provisional', ?, ?, NOW())`,
        [userId, savingsAmount, emergencyFundRate, emergencyFundAmount, totalGoalAllocations, unallocatedSavingsAmount, idempotencyKey, requestHash]
      );
      const allocationId = allocRes.insertId;

      for (const gid of requestedGoalIds) {
        await connection.execute(
          'INSERT INTO goal_savings_allocations (allocation_id, goal_id, planned_amount) VALUES (?, ?, ?)',
          [allocationId, gid, providedAmounts[gid]]
        );
      }

      await connection.commit();
      transactionActive = false;
      return { success: true, message: 'Savings allocation approved successfully' };
    } catch (e) {
      if (transactionActive) await connection.rollback();
      if (e.code === 'ER_DUP_ENTRY' && e.message.includes('idempotency_key')) {
        throw new AppError('Savings allocation request duplicated concurrently', 409, 'IDEMPOTENCY_KEY_REUSED');
      }
      throw e;
    } finally {
      connection.release();
    }
  }

  // ---------------------------------------------------------
  // COMMITMENTS
  // ---------------------------------------------------------
  static async getCommitments(userId) {
    const rawCommitments = await FinanceRepository.getCommitments(userId);
    const formatted = rawCommitments.map(row => ({
      id: row.id,
      name: row.name,
      amount: Number(row.amount || 0),
      frequency: row.frequency,
      nextDueDate: row.next_due_date,
      status: row.status,
      flexibility: row.flexibility
    }));
    return { items: formatted, total: formatted.length };
  }

  static async createCommitment(userId, data) {
    if (data.userId !== undefined) {
      throw new AppError('userId must not be provided in payload', 400, 'INVALID_PAYLOAD');
    }
    const amount = this.normalizeMoney(data.amount, 'amount');
    const name = data.name ? String(data.name).trim() : null;
    if (!name) throw new AppError('Name is required', 400, 'INVALID_NAME');

    const frequency = data.frequency || 'monthly';
    if (!['weekly', 'monthly', 'quarterly', 'yearly'].includes(frequency)) {
      throw new AppError('Invalid frequency', 400, 'INVALID_FREQUENCY');
    }

    const flexibility = data.flexibility || 'fixed';
    if (!['fixed', 'flexible'].includes(flexibility)) {
      throw new AppError('Invalid flexibility', 400, 'INVALID_FLEXIBILITY');
    }

    let nextDueDate = this.normalizeDate(data.nextDueDate, 'nextDueDate');
    if (data.dueDay && !nextDueDate) {
      const dueDay = Number(data.dueDay);
      if (!Number.isSafeInteger(dueDay) || dueDay < 1 || dueDay > 31) {
        throw new AppError('dueDay must be between 1 and 31', 400, 'INVALID_DUE_DAY');
      }
      const today = new Date();
      let year = today.getFullYear();
      let month = today.getMonth();
      if (today.getDate() > dueDay) {
        month++;
        if (month > 11) { month = 0; year++; }
      }
      const lastDay = new Date(year, month + 1, 0).getDate();
      const actualDay = Math.min(dueDay, lastDay);
      const targetDate = new Date(year, month, actualDay);
      nextDueDate = targetDate.toISOString().split('T')[0];
    }

    const sourceType = data.sourceType || 'manual';

    const normalizedData = {
      amount, name, frequency, nextDueDate, flexibility, sourceType
    };

    const id = await FinanceRepository.createCommitment(userId, normalizedData);
    return { id, ...normalizedData };
  }

  static async updateCommitment(userId, commitmentId, data) {
    if (data.userId !== undefined) {
      throw new AppError('userId must not be provided in payload', 400, 'INVALID_PAYLOAD');
    }
    const normalizedData = {};
    if (data.amount !== undefined) normalizedData.amount = this.normalizeMoney(data.amount, 'amount');
    if (data.name !== undefined) {
      normalizedData.name = String(data.name).trim();
      if (!normalizedData.name) throw new AppError('Name is required', 400, 'INVALID_NAME');
    }
    if (data.frequency !== undefined) {
      normalizedData.frequency = data.frequency;
      if (!['weekly', 'monthly', 'quarterly', 'yearly'].includes(normalizedData.frequency)) {
        throw new AppError('Invalid frequency', 400, 'INVALID_FREQUENCY');
      }
    }
    if (data.nextDueDate !== undefined) normalizedData.nextDueDate = this.normalizeDate(data.nextDueDate, 'nextDueDate');
    if (data.flexibility !== undefined) {
      normalizedData.flexibility = data.flexibility;
      if (!['fixed', 'flexible'].includes(normalizedData.flexibility)) {
        throw new AppError('Invalid flexibility', 400, 'INVALID_FLEXIBILITY');
      }
    }
    if (data.status !== undefined) {
      normalizedData.status = data.status;
      if (!['active', 'paused', 'cancelled'].includes(normalizedData.status)) {
        throw new AppError('Invalid status', 400, 'INVALID_STATUS');
      }
    }

    const success = await FinanceRepository.updateCommitment(userId, commitmentId, normalizedData);
    if (!success) {
      throw new AppError('Commitment not found or unauthorized', 404, 'NOT_FOUND');
    }
    return { success: true };
  }

  static async deleteCommitment(userId, commitmentId) {
    const success = await FinanceRepository.deleteCommitment(userId, commitmentId);
    if (!success) {
      throw new AppError('Commitment not found or unauthorized', 404, 'NOT_FOUND');
    }
    return { success: true };
  }

  static async getExpenseCategories() {
    const categories = [
      { id: 'housing', name: 'Housing' },
      { id: 'transport', name: 'Transportation' },
      { id: 'food', name: 'Food & Dining' },
      { id: 'utilities', name: 'Utilities' },
      { id: 'health', name: 'Healthcare' },
      { id: 'entertainment', name: 'Entertainment' },
      { id: 'education', name: 'Education' },
      { id: 'shopping', name: 'Shopping' },
      { id: 'personal', name: 'Personal Care' },
      { id: 'other', name: 'Other' }
    ];
    return { items: categories, total: categories.length };
  }

  // ---------------------------------------------------------
  // ALLOCATION & PROFILE
  // ---------------------------------------------------------
  static async getAllocation(userId) {
    const openCycle = await FinanceRepository.findOpenCycleForUser(null, userId);

    let income, needsBps, wantsBps, savingsBps, tier;

    if (openCycle) {
      const snapshot = await CycleRepository.findSnapshotByCycleId(null, userId, openCycle.id);
      if (snapshot) {
        income = Number(snapshot.allocation_base_income);
        tier = snapshot.tier_code;
        needsBps = Number(snapshot.needs_bps);
        wantsBps = Number(snapshot.wants_bps);
        savingsBps = Number(snapshot.savings_bps);
      }
    }

    if (!income) {
      const profileRows = await db.execute('SELECT expected_monthly_income, detected_tier FROM financial_profiles WHERE user_id = ?', [userId]);
      const prefRows = await db.execute('SELECT needs_bps, wants_bps, savings_bps FROM allocation_preferences WHERE user_id = ?', [userId]);
      if (profileRows[0].length === 0 || prefRows[0].length === 0) return null;

      const profile = profileRows[0][0];
      const pref = prefRows[0][0];

      income = Number(profile.expected_monthly_income);
      tier = profile.detected_tier;
      needsBps = Number(pref.needs_bps);
      wantsBps = Number(pref.wants_bps);
      savingsBps = Number(pref.savings_bps);
    }

    const { AllocationService } = require('./allocation.service');
    const amounts = AllocationService.calculateAmounts(income, needsBps, wantsBps, savingsBps);

    let reservedNeeds = 0;
    if (openCycle) {
      reservedNeeds = await FinanceRepository.getUnpaidOccurrencesTotal(userId, openCycle.id);
    } else {
      const activeCommitments = await FinanceRepository.getCommitments(userId);
      for (const comm of activeCommitments) reservedNeeds += Number(comm.amount || 0);
    }

    let confirmedNeedsExpenses = 0;
    if (openCycle) {
      const totals = await FinanceRepository.getConfirmedTotalsByCycle(userId, openCycle.id);
      confirmedNeedsExpenses = totals.needs || 0;
    } else {
      confirmedNeedsExpenses = await FinanceRepository.getConfirmedNeedsExpenses(userId);
    }

    const availableVariableNeeds = Math.max(0, amounts.needsAmount - confirmedNeedsExpenses - reservedNeeds);

    return {
      income, tier,
      needsAmount: amounts.needsAmount,
      wantsAmount: amounts.wantsAmount,
      savingsAmount: amounts.savingsAmount,
      confirmedNeedsExpenses,
      reservedNeedsAmount: reservedNeeds,
      availableVariableNeeds
    };
  }

  static async getFinancialProfile(userId) {
    const { OnboardingService } = require('./onboarding.service');
    const { OnboardingRepository } = require('../repositories/onboarding.repository');

    const status = await OnboardingService.getStatus(userId);
    const financial = await OnboardingRepository.findFinancialProfile(null, userId);

    return {
      expectedMonthlyIncome: financial ? Number(financial.expected_monthly_income || 0) : null,
      paymentDay: financial ? financial.payment_day : null,
      currency: financial ? financial.currency : null,
      timezone: financial ? financial.timezone : null,
      relationshipWithMoney: status.profile?.relationship_with_money || null,
      primaryFinancialGoal: status.profile?.primary_financial_goal || null,
      monthlyExtraSavingsGoal: status.profile?.monthly_extra_savings_goal ? Number(status.profile.monthly_extra_savings_goal) : null,
      incomeSources: this.parseJsonArray(status.profile?.income_sources),
      fixedExpenses: this.parseJsonArray(status.profile?.fixed_expenses),
      variableExpenses: this.parseJsonArray(status.profile?.variable_expenses),
      allocation: status.allocation || null,
      financialProfileComplete: status.financialProfileComplete,
      missingFinancialFields: status.missingFinancialFields,
      canCreateCycle: status.canCreateCycle
    };
  }

  static parseJsonArray(value) {
    if (value === null || value === undefined || value === '') return [];
    if (typeof value === 'object') return Array.isArray(value) ? value : [value];
    if (typeof value === 'string') {
      try {
        const parsed = JSON.parse(value);
        return Array.isArray(parsed) ? parsed : [parsed];
      } catch (e) {
        const AppError = require('../utils/app-error');
        throw new AppError('Invalid JSON format in database', 500, 'INTERNAL_SERVER_ERROR');
      }
    }
    return [];
  }

  static async updateFinancialProfile(userId, data) {
    if (data.expectedMonthlyIncome !== undefined || data.monthlyIncome !== undefined || data.incomeSources !== undefined || data.regularSalary !== undefined) {
      throw new AppError('Income changes require allocation review.', 400, 'ALLOCATION_REVIEW_REQUIRED');
    }

    const { OnboardingService } = require('./onboarding.service');

    const connection = await db.getConnection();
    let transactionActive = false;
    try {
      await connection.beginTransaction();
      transactionActive = true;

      // Update descriptive profile fields if present
      const profileUpdates = {};
      if (data.relationshipWithMoney !== undefined) profileUpdates.relationshipWithMoney = data.relationshipWithMoney;
      if (data.primaryFinancialGoal !== undefined) profileUpdates.primaryFinancialGoal = data.primaryFinancialGoal;
      if (data.monthlyExtraSavingsGoal !== undefined) profileUpdates.monthlyExtraSavingsGoal = data.monthlyExtraSavingsGoal;
      if (data.monthlyExtraSavingsGoal !== undefined) profileUpdates.monthlyExtraSavingsGoal = data.monthlyExtraSavingsGoal;
      if (data.fixedExpenses !== undefined) profileUpdates.fixedExpenses = data.fixedExpenses;
      if (data.variableExpenses !== undefined) profileUpdates.variableExpenses = data.variableExpenses;

      if (Object.keys(profileUpdates).length > 0) {
        const normalized = OnboardingService.normalizeUserProfileData(profileUpdates);

        const [existingProfile] = await connection.execute('SELECT user_id FROM user_profiles WHERE user_id = ? FOR UPDATE', [userId]);
        if (existingProfile.length === 0) {
          const cols = Object.keys(normalized);
          const vals = Object.values(normalized);
          const placeholders = cols.map(() => '?').join(', ');
          await connection.execute(`INSERT INTO user_profiles (user_id, ${cols.join(', ')}) VALUES (?, ${placeholders})`, [userId, ...vals]);
        } else {
          const sets = [];
          const vals = [];
          for (const [k, v] of Object.entries(normalized)) {
            sets.push(`${k} = ?`);
            vals.push(v);
          }
          if (sets.length > 0) {
            vals.push(userId);
            await connection.execute(`UPDATE user_profiles SET ${sets.join(', ')} WHERE user_id = ?`, vals);
          }
        }
      }

      // Update future plan fields if present
      const [existing] = await connection.execute('SELECT id, expected_monthly_income, payment_day, currency, timezone FROM financial_profiles WHERE user_id = ? FOR UPDATE', [userId]);
      const isNew = existing.length === 0;

      // Removed expectedIncome assignment because it is protected now

      const hasPaymentDay = Object.prototype.hasOwnProperty.call(data, 'paymentDay');
      const hasCurrency = Object.prototype.hasOwnProperty.call(data, 'currency');
      const hasTimezone = Object.prototype.hasOwnProperty.call(data, 'timezone');

      let paymentDay = hasPaymentDay ? data.paymentDay : undefined;
      let currency = hasCurrency ? data.currency : undefined;
      let timezone = hasTimezone ? data.timezone : undefined;

      if (hasPaymentDay) {
        if (paymentDay === undefined) {
          throw new AppError('paymentDay cannot be undefined', 400, 'BAD_REQUEST');
        }
        if (paymentDay !== null) {
          paymentDay = Number(paymentDay);
          if (!Number.isSafeInteger(paymentDay) || paymentDay < 1 || paymentDay > 31) {
            throw new AppError('Salary payment day must be between 1 and 31', 400, 'BAD_REQUEST');
          }
        }
      }

      if (hasCurrency) {
        if (currency === undefined || currency === null || typeof currency !== 'string' || currency.trim() === '') {
          throw new AppError('Currency must be a valid 3-letter code', 400, 'BAD_REQUEST');
        }
        currency = currency.trim().toUpperCase();
        if (currency.length !== 3) {
          throw new AppError('Currency must be a valid 3-letter code', 400, 'BAD_REQUEST');
        }
        if (currency !== 'JOD') {
          throw new AppError('Unsupported currency. Only JOD is supported at this time.', 400, 'BAD_REQUEST');
        }
      }

      if (hasTimezone) {
        if (timezone === undefined || typeof timezone !== 'string' || timezone.trim() === '') {
          throw new AppError('Timezone must be a valid string', 400, 'BAD_REQUEST');
        }
        timezone = timezone.trim();
      }

      if (isNew) {
        const finalCurrency = hasCurrency ? currency : 'JOD';
        const finalTimezone = hasTimezone ? timezone : 'Asia/Amman';
        const finalPaymentDay = hasPaymentDay ? paymentDay : null;
        
        await connection.execute(
          'INSERT INTO financial_profiles (user_id, payment_day, currency, timezone, expected_monthly_income, onboarding_status) VALUES (?, ?, ?, ?, 0, "not_started")',
          [userId, finalPaymentDay, finalCurrency, finalTimezone]
        );
      } else {
        const updates = [];
        const values = [];

        if (hasPaymentDay) {
          updates.push('payment_day = ?');
          values.push(paymentDay);
        }
        if (hasCurrency) {
          updates.push('currency = ?');
          values.push(currency);
        }
        if (hasTimezone) {
          updates.push('timezone = ?');
          values.push(timezone);
        }
        if (updates.length > 0) {
          values.push(userId);
          await connection.execute(`UPDATE financial_profiles SET ${updates.join(', ')} WHERE user_id = ?`, values);
        }
      }

      await connection.commit();
      transactionActive = false;
      return { success: true };
    } catch (error) {
      if (transactionActive) await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async financialProfileAllocationPreview(userId, data) {
    const { AllocationService } = require('./allocation.service');
    const expectedIncome = this.normalizeMoney(data.expectedMonthlyIncome);

    if (expectedIncome <= 0) {
      throw new AppError('Expected income must be positive', 400, 'BAD_REQUEST');
    }

    if (data.incomeSources && Array.isArray(data.incomeSources)) {
      let sourcesTotal = 0;
      for (const source of data.incomeSources) {
        sourcesTotal += this.normalizeMoney(source.amount || 0);
      }
      // If there are sources, their sum must match expectedMonthlyIncome
      if (sourcesTotal > 0 && Math.abs(sourcesTotal - expectedIncome) >= 0.01) {
        throw new AppError('Total of income sources must match expected monthly income', 400, 'INCOME_TOTAL_MISMATCH');
      }
    }

    const { tier, needs_bps, wants_bps, savings_bps } = AllocationService.calculateTierAndBps(expectedIncome);
    const amounts = AllocationService.calculateAmounts(expectedIncome, needs_bps, wants_bps, savings_bps);

    const activeCommitments = await FinanceRepository.getCommitments(userId);
    let reservedAmount = 0;
    for (const comm of activeCommitments) reservedAmount += Number(comm.amount || 0);

    const availableVariableNeeds = Math.max(0, amounts.needsAmount - reservedAmount);

    return {
      income: expectedIncome,
      tier,
      allocation: {
        needsBps: needs_bps,
        needsAmount: amounts.needsAmount,
        wantsBps: wants_bps,
        wantsAmount: amounts.wantsAmount,
        savingsBps: savings_bps,
        savingsAmount: amounts.savingsAmount,
        source: 'system_tier',
        isCustomized: false
      },
      commitments: { reservedAmount, availableVariableNeeds }
    };
  }

  static async approveFinancialProfileAllocation(userId, data) {
    const { AllocationService } = require('./allocation.service');
    const expectedIncome = this.normalizeMoney(data.expectedMonthlyIncome);

    if (expectedIncome <= 0) {
      throw new AppError('Expected income must be positive', 400, 'BAD_REQUEST');
    }

    if (data.incomeSources && Array.isArray(data.incomeSources)) {
      let sourcesTotal = 0;
      for (const source of data.incomeSources) {
        sourcesTotal += this.normalizeMoney(source.amount || 0);
      }
      if (sourcesTotal > 0 && Math.abs(sourcesTotal - expectedIncome) >= 0.01) {
        throw new AppError('Total of income sources must match expected monthly income', 400, 'INCOME_TOTAL_MISMATCH');
      }
    }

    const needsBps = Number(data.needsBps);
    const wantsBps = Number(data.wantsBps);
    const savingsBps = Number(data.savingsBps);

    if (!Number.isSafeInteger(needsBps) || needsBps < 0 || !Number.isSafeInteger(wantsBps) || wantsBps < 0 || !Number.isSafeInteger(savingsBps) || savingsBps < 0) {
      throw new AppError('Allocation percentages must be non-negative integers', 400, 'BAD_REQUEST');
    }
    if (needsBps + wantsBps + savingsBps !== 10000) {
      throw new AppError('Allocation percentages must total exactly 100%', 400, 'BAD_REQUEST');
    }

    const { tier, needs_bps: sysNeeds, wants_bps: sysWants, savings_bps: sysSavings } = AllocationService.calculateTierAndBps(expectedIncome);
    const source = (needsBps === sysNeeds && wantsBps === sysWants && savingsBps === sysSavings) ? 'system_tier' : 'user_adjusted';

    let paymentDay = data.paymentDay ? Number(data.paymentDay) : null;
    if (paymentDay !== null && (!Number.isSafeInteger(paymentDay) || paymentDay < 1 || paymentDay > 31)) {
      throw new AppError('Salary payment day must be between 1 and 31', 400, 'BAD_REQUEST');
    }

    const connection = await db.getConnection();
    let transactionActive = false;
    try {
      await connection.beginTransaction();
      transactionActive = true;

      // Lock user_profiles
      await connection.execute('SELECT user_id FROM user_profiles WHERE user_id = ? FOR UPDATE', [userId]);
      // Lock financial_profiles
      await connection.execute('SELECT user_id FROM financial_profiles WHERE user_id = ? FOR UPDATE', [userId]);
      // Lock allocation_preferences
      await connection.execute('SELECT user_id FROM allocation_preferences WHERE user_id = ? FOR UPDATE', [userId]);

      if (data.incomeSources !== undefined) {
        await connection.execute('UPDATE user_profiles SET income_sources = ? WHERE user_id = ?', [JSON.stringify(data.incomeSources), userId]);
      }

      await connection.execute(`
        INSERT INTO allocation_preferences (user_id, needs_bps, wants_bps, savings_bps, source, based_on_income)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE needs_bps = VALUES(needs_bps), wants_bps = VALUES(wants_bps), savings_bps = VALUES(savings_bps), source = VALUES(source), based_on_income = VALUES(based_on_income)
      `, [userId, needsBps, wantsBps, savingsBps, source, expectedIncome]);

      const finUpdates = ['expected_monthly_income = ?', 'detected_tier = ?'];
      const finVals = [expectedIncome, tier];

      if (paymentDay !== null) {
        finUpdates.push('payment_day = ?');
        finVals.push(paymentDay);
      }
      if (data.currency) {
        finUpdates.push('currency = ?');
        finVals.push(data.currency);
      }
      if (data.timezone) {
        finUpdates.push('timezone = ?');
        finVals.push(data.timezone);
      }
      finVals.push(userId);

      await connection.execute(`UPDATE financial_profiles SET ${finUpdates.join(', ')} WHERE user_id = ?`, finVals);

      await connection.execute('UPDATE users SET is_onboarded = 1 WHERE id = ?', [userId]);

      await connection.commit();
      transactionActive = false;
      return { success: true };
    } catch (error) {
      if (transactionActive) await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }
}

module.exports = { FinanceService };
