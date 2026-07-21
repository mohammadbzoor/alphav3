const crypto = require('crypto');
const { db } = require('../config/database');
const { FinanceRepository } = require('../repositories/finance.repository');
const { CycleRepository } = require('../repositories/cycle.repository');
const { AppError } = require('../utils/app-error');

class FinanceService {
  // ---------------------------------------------------------
  // EXPENSES
  // ---------------------------------------------------------
  static async getExpenses(userId) {
    const rawExpenses = await FinanceRepository.getExpenses(userId);
    const formatted = rawExpenses.map(row => ({
      id: row.id,
      amount: parseInt(row.amount || 0), // whole JOD
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
    if (!data.amount || data.amount <= 0) {
      const error = new Error('Amount must be positive');
      error.statusCode = 400;
      throw error;
    }

    if (!data.bucket || !['needs', 'wants'].includes(data.bucket)) {
      const error = new Error('Bucket must be either needs or wants');
      error.statusCode = 400;
      throw error;
    }

    const needsCategories = ['rent', 'electricity', 'water', 'internet', 'transportation', 'healthcare', 'education', 'family', 'loan', 'other'];
    const wantsCategories = ['restaurant', 'coffee', 'entertainment', 'shopping', 'travel', 'subscription', 'hobbies', 'other'];

    const allowedCategories = data.bucket === 'needs' ? needsCategories : wantsCategories;

    if (!data.category || !allowedCategories.includes(data.category)) {
      const error = new Error(`Invalid category for bucket ${data.bucket}. Allowed: ${allowedCategories.join(', ')}`);
      error.statusCode = 400;
      throw error;
    }

    if (data.paymentMethod && !['cash', 'card', 'wallet', 'bank_transfer', 'other'].includes(data.paymentMethod)) {
      const error = new Error('Invalid payment method');
      error.statusCode = 400;
      throw error;
    }

    // Validate source type
    if (data.sourceType && !['manual', 'image', 'voice'].includes(data.sourceType)) {
      const error = new Error('Invalid source type');
      error.statusCode = 400;
      throw error;
    }
    if (!data.sourceType) {
      data.sourceType = 'manual';
    }

    // Reject userId from request payload
    if (data.userId !== undefined) {
      const error = new Error('userId must not be provided in request payload');
      error.statusCode = 400;
      throw error;
    }

    // Resolve cycle_id: if provided, validate ownership and status; otherwise auto-link to open cycle
    let cycleId = data.cycleId;
    if (cycleId) {
      // Validate cycle belongs to user and is open
      const cycle = await CycleRepository.findCycleById(userId, cycleId);
      if (!cycle) {
        throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
      }
      if (cycle.status !== 'open') {
        throw new AppError('Cannot add transactions to a closed cycle.', 409, 'CLOSED_CYCLE_IMMUTABLE');
      }
    } else {
      // Auto-link to open cycle
      const openCycle = await CycleRepository.findOpenCycle(null, userId);
      if (!openCycle) {
        throw new AppError(
          'No active financial cycle. Create a cycle before adding transactions.',
          422,
          'NO_ACTIVE_FINANCIAL_CYCLE'
        );
      }
      cycleId = openCycle.id;
    }

    data.cycleId = cycleId;
    const id = await FinanceRepository.createExpense(userId, data);
    return { id, ...data };
  }

  static async deleteExpense(userId, expenseId) {
    const success = await FinanceRepository.deleteExpense(userId, expenseId);
    if (!success) {
      const error = new Error('Expense not found or unauthorized');
      error.statusCode = 404;
      throw error;
    }
    return { success: true };
  }

  // ---------------------------------------------------------
  // INCOMES
  // ---------------------------------------------------------
  static async getIncomes(userId) {
    const rawIncomes = await FinanceRepository.getIncomes(userId);
    const formatted = rawIncomes.map(row => ({
      id: row.id,
      amount: parseInt(row.amount || 0),
      source: row.category,
      description: row.description,
      incomeDate: row.occurred_at,
      isRecurring: row.income_kind === 'recurring',
      createdAt: row.created_at
    }));
    return { items: formatted, total: formatted.length };
  }

  static async createIncome(userId, data) {
    // Reject userId from request payload
    if (data.userId !== undefined) {
      const error = new Error('userId must not be provided in request payload');
      error.statusCode = 400;
      throw error;
    }

    // Resolve cycle_id: if provided, validate ownership and status; otherwise auto-link to open cycle
    let cycleId = data.cycleId;
    if (cycleId) {
      // Validate cycle belongs to user and is open
      const cycle = await CycleRepository.findCycleById(userId, cycleId);
      if (!cycle) {
        throw new AppError('Cycle not found or access denied.', 404, 'CYCLE_NOT_FOUND');
      }
      if (cycle.status !== 'open') {
        throw new AppError('Cannot add transactions to a closed cycle.', 409, 'CLOSED_CYCLE_IMMUTABLE');
      }
    } else {
      // Auto-link to open cycle
      const openCycle = await CycleRepository.findOpenCycle(null, userId);
      if (!openCycle) {
        throw new AppError(
          'No active financial cycle. Create a cycle before adding transactions.',
          422,
          'NO_ACTIVE_FINANCIAL_CYCLE'
        );
      }
      cycleId = openCycle.id;
    }

    data.cycleId = cycleId;
    const id = await FinanceRepository.createIncome(userId, data);
    return { id, ...data };
  }

  static async deleteIncome(userId, incomeId) {
    const success = await FinanceRepository.deleteIncome(userId, incomeId);
    if (!success) {
      const error = new Error('Income not found or unauthorized');
      error.statusCode = 404;
      throw error;
    }
    return { success: true };
  }

  // ---------------------------------------------------------
  // GOALS
  // ---------------------------------------------------------
  static async getGoals(userId) {
    const rawGoals = await FinanceRepository.getGoals(userId);
    const formatted = rawGoals.map(row => {
      const targetAmount = parseInt(row.target_amount || 0);
      const currentBalance = parseInt(row.current_balance || 0);
      const monthlyContribution = parseInt(row.cycle_allocation || 0);

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
    let { targetAmount, planningMode, plannedContribution, targetDate } = data;
    targetAmount = Math.round(targetAmount || 0);
    plannedContribution = Math.round(plannedContribution || 0);

    const result = {
      isEstimated: true,
      remainingAmount: targetAmount, // Assuming new goal (currentBalance = 0)
      cyclesRequired: null,
      requiredContribution: null,
    };

    if (planningMode === 'contribution_based') {
      if (plannedContribution > 0) {
        result.cyclesRequired = Math.ceil(result.remainingAmount / plannedContribution);
      }
    } else if (planningMode === 'deadline_based') {
      if (targetDate) {
        const now = new Date();
        const dateObj = new Date(targetDate);
        const months = (dateObj.getFullYear() - now.getFullYear()) * 12 + (dateObj.getMonth() - now.getMonth());
        const estimatedPeriodsRemaining = Math.max(1, months); // Fallback to 1 minimum
        result.requiredContribution = Math.ceil(result.remainingAmount / estimatedPeriodsRemaining);
      }
    }

    return result;
  }

  static async savingsAllocationPreview(userId, savingsAmount, emergencyFundRate = 10.0, inputGoalAllocations = []) {
    if (emergencyFundRate < 0 || emergencyFundRate > 100) {
      const { AppError } = require('../utils/app-error');
      throw new AppError('Emergency fund rate must be between 0 and 100', 400, 'BAD_REQUEST');
    }

    const goals = await FinanceRepository.getGoals(userId);
    const activeGoals = goals.filter(g => g.status === 'active');

    const emergencyFundAmount = Math.round(savingsAmount * (emergencyFundRate / 100));

    let totalGoalAllocations = 0;
    const goalAllocations = [];

    // Create a map for O(1) lookup of provided amounts
    const providedAmounts = {};
    for (const alloc of inputGoalAllocations) {
      providedAmounts[alloc.goalId] = alloc.amount || alloc.allocationAmount || 0;
    }

    for (const goal of activeGoals) {
      const planned = providedAmounts[goal.id] !== undefined ? parseInt(providedAmounts[goal.id]) : parseInt(goal.planned_contribution || 0);
      totalGoalAllocations += planned;
      goalAllocations.push({
        goalId: goal.id,
        name: goal.name,
        targetAmount: parseInt(goal.target_amount || 0),
        currentBalance: parseInt(goal.current_balance || 0),
        plannedContribution: planned
      });
    }

    const unallocatedSavings = Math.round(savingsAmount - emergencyFundAmount - totalGoalAllocations);

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
    const { savingsAmount, goals: allocations } = data;
    let emergencyFundRate = data.emergencyFundRate !== undefined ? parseFloat(data.emergencyFundRate) : 10.0;
    const idempotencyKey = data.idempotencyKey;

    if (emergencyFundRate < 0 || emergencyFundRate > 100) {
      const { AppError } = require('../utils/app-error');
      throw new AppError('Emergency fund rate must be between 0 and 100', 400, 'BAD_REQUEST');
    }

    const emergencyFundAmount = Math.round(savingsAmount * (emergencyFundRate / 100));
    let totalGoalAllocations = 0;

    for (const alloc of allocations) {
      totalGoalAllocations += Math.round(alloc.allocationAmount || 0);
    }

    const unallocated = savingsAmount - emergencyFundAmount - totalGoalAllocations;

    if (unallocated < 0) {
      const { AppError } = require('../utils/app-error');
      throw new AppError('Total goal allocations exceed available savings amount after emergency fund', 400, 'SAVINGS_ALLOCATION_EXCEEDED');
    }

    const requestHash = crypto.createHash('sha256')
      .update(`savings_alloc|${userId}|${savingsAmount}|${emergencyFundRate}|${JSON.stringify(allocations)}`)
      .digest('hex');

    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      // Acquire lock on the user to prevent concurrent savings allocation creations
      await connection.execute(
        'SELECT id FROM users WHERE id = ? FOR UPDATE',
        [userId]
      );

      if (idempotencyKey) {
        const [existing] = await connection.execute(
          'SELECT * FROM savings_allocations WHERE user_id = ? AND idempotency_key = ?',
          [userId, idempotencyKey]
        );
        if (existing.length > 0) {
          if (existing[0].request_hash === requestHash) {
            await connection.commit();
            return { success: true, replayed: true, message: 'Savings allocation approved successfully' };
          } else {
            const { AppError } = require('../utils/app-error');
            throw new AppError('Idempotency key reused with different payload', 409, 'IDEMPOTENCY_KEY_REUSED');
          }
        }
      }

      // Update the provisional allocation
      // We will invalidate any old provisional allocations by setting them to 'superseded'
      await connection.execute(
        "UPDATE savings_allocations SET status = 'superseded' WHERE user_id = ? AND status = 'provisional'",
        [userId]
      );

      // Create new provisional allocation
      const [allocRes] = await connection.execute(
        `INSERT INTO savings_allocations (
          user_id, savings_amount, emergency_fund_rate, emergency_fund_amount,
          total_goal_allocations, unallocated_savings_amount, status,
          idempotency_key, request_hash, approved_at
        ) VALUES (?, ?, ?, ?, ?, ?, 'provisional', ?, ?, NOW())`,
        [userId, savingsAmount, emergencyFundRate, emergencyFundAmount, totalGoalAllocations, unallocated, idempotencyKey || null, requestHash]
      );
      const allocationId = allocRes.insertId;

      for (const alloc of allocations) {
        const goal = await FinanceRepository.findGoalForUpdate(connection, alloc.goalId, userId);
        if (!goal) {
          throw Object.assign(new Error(`Goal ${alloc.goalId} not found`), { statusCode: 404 });
        }
        if (goal.status !== 'active') {
          throw Object.assign(new Error(`Cannot allocate to ${goal.status} goal`), { statusCode: 400 });
        }

        const allocAmt = Math.round(alloc.allocationAmount || 0);

        // Insert into goal_savings_allocations
        await connection.execute(
          'INSERT INTO goal_savings_allocations (allocation_id, goal_id, planned_amount) VALUES (?, ?, ?)',
          [allocationId, alloc.goalId, allocAmt]
        );
      }

      await connection.commit();
      return { success: true, message: 'Savings allocation approved successfully' };
    } catch (e) {
      await connection.rollback();
      throw e;
    } finally {
      connection.release();
    }
  }

  static validateGoalData(data, currentBalance = 0) {
    const validGoalTypes = [
      'emergency_fund', 'laptop', 'travel', 'religious_travel',
      'holiday_expenses', 'tuition', 'car_down_payment',
      'home_down_payment', 'business_startup',
      'electrical_appliances', 'furniture',
      'clothing_accessories', 'custom'
    ];

    if (!data.targetAmount || data.targetAmount <= 0) {
      throw Object.assign(new Error('Target amount must be greater than zero'), { statusCode: 400 });
    }
    if (data.targetAmount < currentBalance) {
      throw Object.assign(new Error('Target amount cannot be lower than current balance'), { statusCode: 400 });
    }
    if (!validGoalTypes.includes(data.goalType)) {
      throw Object.assign(new Error('Unsupported goal type'), { statusCode: 400 });
    }
    if (data.goalType === 'custom' && !data.customName) {
      throw Object.assign(new Error('Custom name is required for custom goals'), { statusCode: 400 });
    }
    if (data.priority < 1 || data.priority > 10) {
      throw Object.assign(new Error('Priority must be between 1 and 10'), { statusCode: 400 });
    }

    if (data.planningMode === 'contribution_based') {
      if (!data.plannedContribution || data.plannedContribution <= 0) {
        throw Object.assign(new Error('Planned contribution must be greater than zero'), { statusCode: 400 });
      }
    } else if (data.planningMode === 'deadline_based') {
      if (!data.targetDate) {
        throw Object.assign(new Error('Target date is required for deadline based planning'), { statusCode: 400 });
      }
      const dateObj = new Date(data.targetDate);
      const now = new Date();
      now.setHours(0,0,0,0);
      const sevenYearsFromNow = new Date(now);
      sevenYearsFromNow.setFullYear(sevenYearsFromNow.getFullYear() + 7);

      if (dateObj < now) {
        throw Object.assign(new Error('Target date cannot be in the past'), { statusCode: 400 });
      }
      if (dateObj > sevenYearsFromNow) {
        throw Object.assign(new Error('Target date cannot be more than 7 years ahead'), { statusCode: 400 });
      }
    } else {
      throw Object.assign(new Error('Invalid planning mode'), { statusCode: 400 });
    }
  }

  static async createGoal(userId, data) {
    this.validateGoalData(data, 0);
    const id = await FinanceRepository.createGoal(userId, data);
    return { success: true, goalId: id };
  }

  static async updateGoal(userId, goalId, data) {
    const goals = await FinanceRepository.getGoals(userId);
    const goal = goals.find(g => String(g.id) === String(goalId));

    if (!goal) {
      throw Object.assign(new Error('Goal not found'), { statusCode: 404 });
    }
    if (goal.status === 'executed') {
      throw Object.assign(new Error('Executed goals cannot be edited'), { statusCode: 400 });
    }

    this.validateGoalData(data, goal.current_balance);

    await FinanceRepository.updateGoal(userId, goalId, data);
    return { success: true, goalId };
  }

  static async addGoalContribution(userId, goalId, data) {
    const { amount, idempotencyKey, description } = data;

    if (!amount || amount <= 0) {
      const err = new Error('Contribution amount must be greater than zero');
      err.statusCode = 400;
      throw err;
    }
    if (!idempotencyKey) {
      const err = new Error('Idempotency key is required');
      err.statusCode = 400;
      throw err;
    }

    // Deterministic Request Hash
    const requestHash = crypto.createHash('sha256')
      .update(`contribution|${userId}|${goalId}|${amount}|${description || ''}`)
      .digest('hex');

    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      // 1. Idempotency Check
      const existingTx = await FinanceRepository.findIdempotencyRecord(connection, userId, idempotencyKey);
      if (existingTx) {
        if (existingTx.request_hash === requestHash) {
          await connection.commit();
          return { success: true, replayed: true, transaction: existingTx };
        }
        const err = new Error('Idempotency key reused with different payload');
        err.statusCode = 409;
        err.code = 'IDEMPOTENCY_KEY_REUSED';
        throw err;
      }

      // 2. Lock Goal for Update
      const goal = await FinanceRepository.findGoalForUpdate(connection, goalId, userId);
      if (!goal) {
        const err = new Error('Goal not found or unauthorized');
        err.statusCode = 404;
        throw err;
      }
      if (goal.status !== 'active') {
        const err = new Error(`Cannot contribute to a ${goal.status} goal`);
        err.statusCode = 400;
        throw err;
      }

      const targetAmount = parseFloat(goal.target_amount);
      const currentBalance = parseFloat(goal.current_balance || 0);
      const contributionAmount = parseFloat(amount);
      const remainingAmount = targetAmount - currentBalance;

      // 3. Over-contribution Check
      if (contributionAmount > remainingAmount) {
        const err = new Error('Contribution exceeds the remaining goal amount.');
        err.statusCode = 409;
        err.code = 'GOAL_CONTRIBUTION_EXCEEDS_REMAINING';
        err.details = {
          targetAmount,
          currentAmount: currentBalance,
          remainingAmount,
          requestedAmount: contributionAmount
        };
        throw err;
      }

      // 4. Create Ledger Entry
      let transaction;
      try {
        transaction = await FinanceRepository.createGoalTransaction(connection, {
          userId, goalId,
          amount: contributionAmount,
          transactionType: 'contribution',
          idempotencyKey, requestHash, description
        });
      } catch (err) {
        if (err.code === 'CONCURRENT_IDEMPOTENT_REPLAY') {
          await connection.rollback();
          return { success: true, replayed: true, transaction: err.existingTransaction };
        }
        throw err;
      }

      // 5. Update Balance and Status
      const newBalance = currentBalance + contributionAmount;
      let newStatus = 'active';
      let readyAt = null;

      if (newBalance >= targetAmount) {
        newStatus = 'ready';
        readyAt = new Date();
      }

      await FinanceRepository.updateGoalBalanceAndStatus(connection, {
        goalId, userId, newBalance, newStatus, readyAt
      });

      await connection.commit();

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
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async getReadyGoals(userId) {
    return await FinanceRepository.getReadyGoals(userId);
  }

  static async getGoalTransactions(userId, goalId, limit = 50, offset = 0) {
    // Verify goal exists first (so we return 404 if not found)
    const goal = await FinanceRepository.getGoals(userId);
    if (!goal.some(g => g.id == goalId)) {
      const error = new Error('Goal not found or unauthorized');
      error.statusCode = 404;
      throw error;
    }
    return await FinanceRepository.getGoalTransactions(userId, goalId, limit, offset);
  }

  static async changeGoalStatus(userId, goalId, newStatus) {
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();
      const goal = await FinanceRepository.findGoalForUpdate(connection, goalId, userId);
      if (!goal) {
        const err = new Error('Goal not found or unauthorized');
        err.statusCode = 404;
        throw err;
      }

      // Pause/Resume Rules
      if (newStatus === 'paused') {
        if (goal.status !== 'active') {
          const err = new Error(`Cannot pause a ${goal.status} goal`);
          err.statusCode = 400;
          throw err;
        }
      } else if (newStatus === 'active') {
        if (goal.status !== 'paused') {
          const err = new Error(`Cannot resume a ${goal.status} goal`);
          err.statusCode = 400;
          throw err;
        }
      } else {
        const err = new Error(`Invalid status transition to ${newStatus}`);
        err.statusCode = 400;
        throw err;
      }

      await FinanceRepository.updateGoalBalanceAndStatus(connection, {
        goalId, userId,
        newBalance: goal.current_balance,
        newStatus,
        readyAt: goal.ready_at
      });

      await connection.commit();
      return { success: true, status: newStatus };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async deleteGoal(userId, goalId) {
    const success = await FinanceRepository.deleteGoal(userId, goalId);
    if (!success) {
      const error = new Error('Goal not found or unauthorized');
      error.statusCode = 404;
      throw error;
    }
    return { success: true };
  }

  static async executeGoal(userId, goalId, idempotencyKey) {
    return await FinanceRepository.executeGoal(userId, goalId, idempotencyKey);
  }

  static async deferGoal(userId, goalId) {
    return await FinanceRepository.deferGoal(userId, goalId);
  }

  static async reallocateGoal(userId, sourceGoalId, destinationGoalId, amount, idempotencyKey) {
    return await FinanceRepository.reallocateGoal(userId, sourceGoalId, destinationGoalId, amount, idempotencyKey);
  }

  // ---------------------------------------------------------
  // COMMITMENTS
  // ---------------------------------------------------------
  static async getCommitments(userId) {
    const rawCommitments = await FinanceRepository.getCommitments(userId);
    const formatted = rawCommitments.map(row => ({
      id: row.id,
      name: row.name,
      amount: parseInt(row.amount || 0),
      frequency: row.frequency,
      nextDueDate: row.next_due_date,
      status: row.status,
      flexibility: row.flexibility
    }));
    return { items: formatted, total: formatted.length };
  }

  static async createCommitment(userId, data) {
    if (!data.amount || data.amount <= 0) {
      const error = new Error('Amount must be positive');
      error.statusCode = 400;
      throw error;
    }
    const id = await FinanceRepository.createCommitment(userId, data);
    return { id, ...data };
  }

  static async updateCommitment(userId, commitmentId, data) {
    if (data.amount !== undefined && data.amount <= 0) {
      const error = new Error('Amount must be positive');
      error.statusCode = 400;
      throw error;
    }
    const success = await FinanceRepository.updateCommitment(userId, commitmentId, data);
    if (!success) {
      const error = new Error('Commitment not found or unauthorized');
      error.statusCode = 404;
      throw error;
    }
    return { success: true };
  }

  static async deleteCommitment(userId, commitmentId) {
    const success = await FinanceRepository.deleteCommitment(userId, commitmentId);
    if (!success) {
      const error = new Error('Commitment not found or unauthorized');
      error.statusCode = 404;
      throw error;
    }
    return { success: true };
  }

  static async getExpenseCategories() {
    // Static list of predefined categories to return
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

  static async getAllocation(userId) {
    const data = await FinanceRepository.getAllocation(userId);
    if (!data) return null;

    const { AllocationService } = require('./allocation.service');

    // Dynamically calculate amounts
    const amounts = AllocationService.calculateAmounts(
      data.income,
      data.needsBps,
      data.wantsBps,
      data.savingsBps
    );

    // Only confirmed transactions affect metrics (enforced at repository level)
    const confirmedNeedsExpenses = await FinanceRepository.getConfirmedNeedsExpenses(userId);
    const unpaidActiveCommitments = await FinanceRepository.getActiveCommitmentsTotal(userId);

    const needsAmount = amounts.needsAmount;
    const reservedNeedsAmount = unpaidActiveCommitments;

    const reservedNeeds = unpaidActiveCommitments;
    const availableVariableNeeds = Math.max(0, needsAmount - confirmedNeedsExpenses - reservedNeeds);

    return {
      income: data.income,
      tier: data.tier,
      needsAmount: amounts.needsAmount,
      wantsAmount: amounts.wantsAmount,
      savingsAmount: amounts.savingsAmount,
      confirmedNeedsExpenses: confirmedNeedsExpenses,
      reservedNeedsAmount: reservedNeeds,
      availableVariableNeeds: availableVariableNeeds
    };
  }
  static async updateFinancialProfile(userId, data) {
    const { expectedIncome, salaryPaymentDay, additionalIncomeSources } = data;
    
    if (expectedIncome !== undefined && expectedIncome < 0) {
      const { AppError } = require('../utils/app-error');
      throw new AppError('Expected income cannot be negative', 400, 'BAD_REQUEST');
    }
    
    if (salaryPaymentDay !== undefined && (salaryPaymentDay < 1 || salaryPaymentDay > 31)) {
      const { AppError } = require('../utils/app-error');
      throw new AppError('Salary payment day must be between 1 and 31', 400, 'BAD_REQUEST');
    }
    
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      // Build incremental updates for financial_profiles
      const updates = [];
      const values = [];
      
      if (expectedIncome !== undefined) {
        updates.push('expected_monthly_income = ?');
        values.push(expectedIncome);
      }
      if (salaryPaymentDay !== undefined) {
        updates.push('payment_day = ?');
        values.push(salaryPaymentDay);
      }
      
      if (updates.length > 0) {
        const [existing] = await connection.execute('SELECT id FROM financial_profiles WHERE user_id = ?', [userId]);
        
        if (existing.length > 0) {
          values.push(userId);
          await connection.execute(
            `UPDATE financial_profiles SET ${updates.join(', ')} WHERE user_id = ?`,
            values
          );
        } else {
          await connection.execute(
            'INSERT INTO financial_profiles (user_id, expected_monthly_income, payment_day) VALUES (?, ?, ?)',
            [userId, expectedIncome || 0, salaryPaymentDay || 1]
          );
        }
      }

      // Additional recurring income sources: no canonical persistence table exists.
      // Values are not stored — they are only used in the allocation preview calculation.
      // This is a known schema gap: no table for recurring income sources.

      await connection.commit();
      return { success: true };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async financialProfileAllocationPreview(userId, data) {
    const expectedIncome = parseFloat(data.expectedIncome || 0);
    const { AllocationService } = require('./allocation.service');
    
    if (expectedIncome < 0) {
      const { AppError } = require('../utils/app-error');
      throw new AppError('Expected income cannot be negative', 400, 'BAD_REQUEST');
    }

    const { tier, needs_bps, wants_bps, savings_bps } = AllocationService.calculateTierAndBps(expectedIncome);
    
    const amounts = AllocationService.calculateAmounts(expectedIncome, needs_bps, wants_bps, savings_bps);
    
    // Commitments calculation
    const activeCommitments = await FinanceRepository.getCommitments(userId);
    let reservedAmount = 0;
    for (const comm of activeCommitments) {
      reservedAmount += parseFloat(comm.amount || 0);
    }
    
    const availableVariableNeeds = Math.max(0, amounts.needsAmount - reservedAmount);

    return {
      expectedIncome,
      tier,
      allocation: {
        needsBps: needs_bps,
        needsAmount: amounts.needsAmount,
        wantsBps: wants_bps,
        wantsAmount: amounts.wantsAmount,
        savingsBps: savings_bps,
        savingsAmount: amounts.savingsAmount
      },
      commitments: {
        reservedAmount,
        availableVariableNeeds
      }
    };
  }

  static async approveFinancialProfileAllocation(userId, data) {
    const { expectedIncome, needsBps, wantsBps, savingsBps } = data;
    
    if (needsBps + wantsBps + savingsBps !== 10000) {
      const { AppError } = require('../utils/app-error');
      throw new AppError('Allocation percentages must total exactly 100%', 400, 'BAD_REQUEST');
    }

    const { AllocationService } = require('./allocation.service');
    const { tier } = AllocationService.calculateTierAndBps(expectedIncome);

    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      const [existing] = await connection.execute('SELECT * FROM allocation_preferences WHERE user_id = ?', [userId]);
      if (existing.length > 0) {
        await connection.execute(
          'UPDATE allocation_preferences SET needs_bps = ?, wants_bps = ?, savings_bps = ?, source = "user_adjusted", based_on_income = ? WHERE user_id = ?',
          [needsBps, wantsBps, savingsBps, expectedIncome, userId]
        );
      } else {
        await connection.execute(
          'INSERT INTO allocation_preferences (user_id, needs_bps, wants_bps, savings_bps, source, based_on_income) VALUES (?, ?, ?, ?, "user_adjusted", ?)',
          [userId, needsBps, wantsBps, savingsBps, expectedIncome]
        );
      }

      // Also ensure expected income is up to date in financial_profiles
      const [existingProfile] = await connection.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      if (existingProfile.length > 0) {
        await connection.execute(
          'UPDATE financial_profiles SET expected_monthly_income = ?, detected_tier = ? WHERE user_id = ?',
          [expectedIncome, tier, userId]
        );
      } else {
        await connection.execute(
          'INSERT INTO financial_profiles (user_id, expected_monthly_income, detected_tier) VALUES (?, ?, ?)',
          [userId, expectedIncome, tier]
        );
      }

      await connection.commit();
      
      // Update Onboarding status if not already
      const { OnboardingRepository } = require('../repositories/onboarding.repository');
      await OnboardingRepository.markOnboarded(userId);
      
      return { success: true };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }
}

module.exports = { FinanceService };
