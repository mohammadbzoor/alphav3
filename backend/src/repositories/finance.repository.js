const { db } = require('../config/database');

class FinanceRepository {
  // ---------------------------------------------------------
  // EXPENSES
  // ---------------------------------------------------------
  static async getExpenses(userId) {
    const [rows] = await db.execute(
      `SELECT id, amount, budget_bucket as bucket, category, payment_method as paymentMethod, description, source_type as sourceType, DATE_FORMAT(occurred_at, '%Y-%m-%d') as date
       FROM transactions
       WHERE user_id = ? AND transaction_type = 'expense'
       ORDER BY occurred_at DESC`,
      [userId]
    );
    return rows;
  }

  static async createExpense(userId, data) {
    const amount = Math.round(data.amount || 0);
    const category = data.category || 'other';
    const bucket = data.bucket || 'needs';
    const description = data.description || null;
    const occurredAt = data.expenseDate ? new Date(data.expenseDate) : new Date();
    const sourceType = data.sourceType || 'manual';
    const paymentMethod = data.paymentMethod || 'cash';
    const originalImageUrl = data.originalImageUrl || null;
    const originalTranscript = data.originalTranscript || null;
    // cycle_id is required for new transactions (resolved by service layer)
    const cycleId = data.cycleId || null;

    const [result] = await db.execute(
      `INSERT INTO transactions
       (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, category,
        description, occurred_at, status, confirmed_at,
        source_type, payment_method, original_image_url, original_transcript)
       VALUES (?, ?, ?, 'outflow', 'expense', ?, ?, ?, ?, 'confirmed', NOW(), ?, ?, ?, ?)`,
      [userId, cycleId, amount, bucket, category, description, occurredAt,
       sourceType, paymentMethod, originalImageUrl, originalTranscript]
    );
    return result.insertId;
  }

  static async deleteExpense(userId, expenseId) {
    const [result] = await db.execute(
      `DELETE FROM transactions
       WHERE id = ? AND user_id = ? AND transaction_type = 'expense'`,
      [expenseId, userId]
    );
    return result.affectedRows > 0;
  }

  // ---------------------------------------------------------
  // INCOMES
  // ---------------------------------------------------------
  static async getIncomes(userId) {
    const [rows] = await db.execute(
      `SELECT * FROM transactions
       WHERE user_id = ? AND transaction_type = 'income'
       ORDER BY occurred_at DESC`,
      [userId]
    );
    return rows;
  }

  static async createIncome(userId, data) {
    const amount = Math.round(data.amount || 0);
    const category = data.source || 'uncategorized';
    const description = data.description || null;
    const occurredAt = data.incomeDate ? new Date(data.incomeDate) : new Date();
    const incomeKind = data.isRecurring ? 'recurring' : 'unexpected';
    const sourceType = data.sourceType || 'manual';
    const originalImageUrl = data.originalImageUrl || null;
    const originalTranscript = data.originalTranscript || null;
    // cycle_id is required for new transactions (resolved by service layer)
    const cycleId = data.cycleId || null;

    const [result] = await db.execute(
      `INSERT INTO transactions
       (user_id, cycle_id, amount, direction, transaction_type, category, description,
        occurred_at, income_kind, status, confirmed_at,
        source_type, original_image_url, original_transcript)
       VALUES (?, ?, ?, 'inflow', 'income', ?, ?, ?, ?, 'confirmed', NOW(), ?, ?, ?)`,
      [userId, cycleId, amount, category, description, occurredAt, incomeKind,
       sourceType, originalImageUrl, originalTranscript]
    );
    return result.insertId;
  }

  static async deleteIncome(userId, incomeId) {
    const [result] = await db.execute(
      `DELETE FROM transactions
       WHERE id = ? AND user_id = ? AND transaction_type = 'income'`,
      [incomeId, userId]
    );
    return result.affectedRows > 0;
  }

  // ---------------------------------------------------------
  // GOALS
  // ---------------------------------------------------------
  static async getGoals(userId) {
    const [rows] = await db.execute(
      `SELECT * FROM goals WHERE user_id = ? ORDER BY created_at DESC`,
      [userId]
    );
    return rows;
  }

  static async createGoal(userId, data) {
    const targetAmount = Math.round(data.targetAmount || 0);
    const plannedContribution = Math.round(data.plannedContribution || 0);
    const targetDate = data.targetDate ? new Date(data.targetDate) : null;
    const priority = data.priority || 5;

    const [result] = await db.execute(
      `INSERT INTO goals
       (user_id, goal_type, name, custom_name, target_amount, planned_contribution, target_date, planning_mode, priority, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')`,
      [userId, data.goalType, data.goalType, data.customName || null, targetAmount, plannedContribution, targetDate, data.planningMode, priority]
    );
    return result.insertId;
  }

  static async updateGoal(userId, goalId, data) {
    const targetAmount = Math.round(data.targetAmount || 0);
    const plannedContribution = Math.round(data.plannedContribution || 0);
    const targetDate = data.targetDate ? new Date(data.targetDate) : null;
    const priority = data.priority || 5;

    await db.execute(
      `UPDATE goals SET
        goal_type = ?, name = ?, custom_name = ?, target_amount = ?, planned_contribution = ?, target_date = ?, planning_mode = ?, priority = ?
       WHERE id = ? AND user_id = ?`,
      [data.goalType, data.goalType, data.customName || null, targetAmount, plannedContribution, targetDate, data.planningMode, priority, goalId, userId]
    );
  }

  static async findGoalForUpdate(connection, goalId, userId) {
    const [rows] = await connection.execute(
      `SELECT * FROM goals WHERE id = ? AND user_id = ? FOR UPDATE`,
      [goalId, userId]
    );
    return rows[0] || null;
  }

  static async findIdempotencyRecord(connection, userId, idempotencyKey) {
    const [rows] = await connection.execute(
      `SELECT * FROM goal_transactions WHERE user_id = ? AND idempotency_key = ?`,
      [userId, idempotencyKey]
    );
    return rows[0] || null;
  }

  static async createGoalTransaction(connection, data) {
    const { userId, goalId, amount, transactionType, idempotencyKey, requestHash, description } = data;
    try {
      const [result] = await connection.execute(
        `INSERT INTO goal_transactions
         (user_id, goal_id, amount, transaction_type, idempotency_key, request_hash, description)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [userId, goalId, amount, transactionType, idempotencyKey || null, requestHash || null, description || null]
      );

      const [rows] = await connection.execute(
        `SELECT * FROM goal_transactions WHERE id = ?`,
        [result.insertId]
      );
      return rows[0];
    } catch (e) {
      if (e.code === 'ER_DUP_ENTRY' && e.message.includes('uq_user_idempotency')) {
        // Fetch the existing transaction that caused the conflict (use FOR SHARE to bypass repeatable read snapshot)
        const [existing] = await connection.execute(
          `SELECT * FROM goal_transactions WHERE user_id = ? AND idempotency_key = ? FOR SHARE`,
          [userId, idempotencyKey]
        );

        if (existing.length > 0) {
          if (existing[0].request_hash === requestHash) {
            // It's the exact same payload, return a special marker for the service
            const err = new Error('Concurrent idempotent replay');
            err.code = 'CONCURRENT_IDEMPOTENT_REPLAY';
            err.existingTransaction = existing[0];
            throw err;
          } else {
            const err = new Error('Idempotency key reused with different payload concurrently');
            err.statusCode = 409;
            err.code = 'IDEMPOTENCY_KEY_REUSED';
            throw err;
          }
        }
      }
      throw e;
    }
  }

  static async updateGoalBalanceAndStatus(connection, data) {
    const { goalId, userId, newBalance, newStatus, readyAt } = data;
    await connection.execute(
      `UPDATE goals
       SET current_balance = ?, status = ?, ready_at = ?
       WHERE id = ? AND user_id = ?`,
      [newBalance, newStatus, readyAt, goalId, userId]
    );
  }

  static async getGoalTransactions(userId, goalId, limit = 50, offset = 0) {
    const [rows] = await db.execute(
      `SELECT * FROM goal_transactions
       WHERE user_id = ? AND goal_id = ?
       ORDER BY created_at DESC, id DESC
       LIMIT ? OFFSET ?`,
      [userId, goalId, limit.toString(), offset.toString()]
    );
    return rows;
  }

  static async getReadyGoals(userId) {
    const [rows] = await db.execute(
      `SELECT * FROM goals WHERE user_id = ? AND status = 'ready' ORDER BY ready_at ASC`,
      [userId]
    );
    return rows;
  }

  static async reconcileGoalBalance(userId, goalId) {
    const [goalRows] = await db.execute(
      `SELECT current_balance FROM goals WHERE id = ? AND user_id = ?`,
      [goalId, userId]
    );
    if (goalRows.length === 0) return null;

    const storedBalance = parseFloat(goalRows[0].current_balance || 0);

    const [txRows] = await db.execute(
      `SELECT amount, transaction_type FROM goal_transactions WHERE goal_id = ? AND user_id = ?`,
      [goalId, userId]
    );

    let ledgerBalance = 0;
    for (const tx of txRows) {
      const amt = parseFloat(tx.amount);
      switch (tx.transaction_type) {
        case 'contribution':
        case 'reallocation_in':
        case 'adjustment':
          ledgerBalance += amt;
          break;
        case 'withdrawal':
        case 'reallocation_out':
        case 'execution':
          ledgerBalance -= amt;
          break;
      }
    }

    const difference = storedBalance - ledgerBalance;
    return {
      storedBalance,
      ledgerBalance,
      difference,
      reconciled: Math.abs(difference) < 0.01
    };
  }



  static async executeGoal(userId, goalId, idempotencyKey) {
    const { AppError } = require('../utils/app-error');
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      // Lock goal
      const [goalRows] = await connection.execute(
        'SELECT * FROM goals WHERE id = ? FOR UPDATE',
        [goalId]
      );
      if (goalRows.length === 0) {
        throw new AppError('Goal not found', 404, 'NOT_FOUND');
      }
      const goal = goalRows[0];

      if (goal.user_id.toString() !== userId.toString()) {
        throw new AppError('Unauthorized', 404, 'NOT_FOUND');
      }

      const requestHash = require('crypto').createHash('sha256')
        .update(JSON.stringify({ operation: 'execute', userId, goalId }))
        .digest('hex');

      // Idempotency pre-check FIRST
      if (idempotencyKey) {
        const [existing] = await connection.execute(
          'SELECT request_hash FROM goal_transactions WHERE user_id = ? AND idempotency_key = ?',
          [userId, idempotencyKey]
        );
        if (existing.length > 0) {
          if (existing[0].request_hash === requestHash) {
            await connection.rollback();
            return { success: true, message: 'Goal executed successfully (idempotent)' };
          } else {
            throw new AppError('Idempotency key reused for a different request', 409, 'IDEMPOTENCY_KEY_REUSED');
          }
        }
      }

      if (goal.status !== 'ready') {
        throw new AppError('Goal is not in ready status', 400, 'BAD_REQUEST');
      }

      // Reconcile balance
      const [ledgerRows] = await connection.execute(
        `SELECT
           COALESCE(SUM(CASE WHEN transaction_type IN ('contribution', 'adjustment', 'reallocation_in') THEN amount ELSE 0 END), 0) -
           COALESCE(SUM(CASE WHEN transaction_type IN ('withdrawal', 'reallocation_out', 'execution') THEN amount ELSE 0 END), 0) AS actual_balance
         FROM goal_transactions
         WHERE goal_id = ?`,
        [goalId]
      );

      const actualBalance = Number(ledgerRows[0].actual_balance || 0);

      if (actualBalance < Number(goal.target_amount)) {
        throw new AppError('Goal balance is less than target amount', 400, 'BAD_REQUEST');
      }

      // Create goal transaction
      await connection.execute(
        `INSERT INTO goal_transactions
         (user_id, goal_id, amount, transaction_type, idempotency_key, request_hash, description)
         VALUES (?, ?, ?, 'execution', ?, ?, 'Goal execution')`,
        [userId, goalId, Number(goal.target_amount), idempotencyKey || null, requestHash || null]
      );

      // Create transaction
      await connection.execute(
        `INSERT INTO transactions
         (user_id, amount, direction, transaction_type, budget_bucket, status, occurred_at, confirmed_at, description)
         VALUES (?, ?, 'outflow', 'capital_expense', 'capital_expense', 'confirmed', NOW(), NOW(), CONCAT('Goal executed: ', ?))`,
        [userId, Number(goal.target_amount), goal.name]
      );

      // Update goal status
      const newBalance = actualBalance - Number(goal.target_amount);
      await connection.execute(
        'UPDATE goals SET status = ?, executed_at = NOW(), current_balance = ? WHERE id = ?',
        ['executed', newBalance, goalId]
      );

      await connection.commit();
      return { success: true, message: 'Goal executed successfully' };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async deferGoal(userId, goalId) {
    const { AppError } = require('../utils/app-error');
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      const [goalRows] = await connection.execute(
        'SELECT user_id, status FROM goals WHERE id = ? FOR UPDATE',
        [goalId]
      );
      if (goalRows.length === 0 || goalRows[0].user_id.toString() !== userId.toString()) {
        throw new AppError('Goal not found or unauthorized', 404, 'NOT_FOUND');
      }
      if (goalRows[0].status !== 'ready') {
        throw new AppError('Goal is not in ready status', 400, 'BAD_REQUEST');
      }

      await connection.commit();
      return { success: true, message: 'Goal deferred successfully' };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async reallocateGoal(userId, sourceGoalId, destinationGoalId, amount, idempotencyKey) {
    const { AppError } = require('../utils/app-error');
    const amountVal = Number(amount);
    if (!amountVal || amountVal <= 0) {
      throw new AppError('Invalid reallocation amount', 400, 'BAD_REQUEST');
    }

    if (sourceGoalId.toString() === destinationGoalId.toString()) {
      throw new AppError('Source and destination goals must differ', 400, 'BAD_REQUEST');
    }

    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      // Lock both goals in ascending ID order to prevent deadlocks
      const sourceBigInt = BigInt(sourceGoalId);
      const destBigInt = BigInt(destinationGoalId);

      const firstId = sourceBigInt < destBigInt ? sourceGoalId : destinationGoalId;
      const secondId = sourceBigInt < destBigInt ? destinationGoalId : sourceGoalId;

      const [firstRows] = await connection.execute('SELECT * FROM goals WHERE id = ? FOR UPDATE', [firstId.toString()]);
      const [secondRows] = await connection.execute('SELECT * FROM goals WHERE id = ? FOR UPDATE', [secondId.toString()]);

      if (firstRows.length === 0 || secondRows.length === 0) {
        throw new AppError('Goal not found', 404, 'NOT_FOUND');
      }

      const sourceGoal = firstId.toString() === sourceGoalId.toString() ? firstRows[0] : secondRows[0];
      const destGoal = firstId.toString() === destinationGoalId.toString() ? firstRows[0] : secondRows[0];

      if (sourceGoal.user_id.toString() !== userId.toString() || destGoal.user_id.toString() !== userId.toString()) {
        throw new AppError('Unauthorized', 404, 'NOT_FOUND');
      }

      const requestHash = require('crypto').createHash('sha256')
        .update(JSON.stringify({ operation: 'reallocate', userId, sourceGoalId, destinationGoalId, amount: amountVal }))
        .digest('hex');

      // Idempotency pre-check FIRST
      if (idempotencyKey) {
        const [existing] = await connection.execute(
          'SELECT request_hash FROM goal_transactions WHERE user_id = ? AND idempotency_key = ?',
          [userId, idempotencyKey]
        );
        if (existing.length > 0) {
          if (existing[0].request_hash === requestHash) {
            await connection.rollback();
            return { success: true, message: 'Goal reallocated successfully (idempotent)' };
          } else {
            throw new AppError('Idempotency key reused for a different request', 409, 'IDEMPOTENCY_KEY_REUSED');
          }
        }
      }

      if (sourceGoal.status !== 'ready') {
        throw new AppError('Source goal must be in ready status', 400, 'BAD_REQUEST');
      }

      if (destGoal.status !== 'active' && destGoal.status !== 'paused') {
        throw new AppError('Destination goal must be active or paused', 400, 'BAD_REQUEST');
      }

      // Check source balance
      const [sourceLedger] = await connection.execute(
        `SELECT
           COALESCE(SUM(CASE WHEN transaction_type IN ('contribution', 'adjustment', 'reallocation_in') THEN amount ELSE 0 END), 0) -
           COALESCE(SUM(CASE WHEN transaction_type IN ('withdrawal', 'reallocation_out', 'execution') THEN amount ELSE 0 END), 0) AS actual_balance
         FROM goal_transactions
         WHERE goal_id = ?`,
        [sourceGoal.id]
      );
      const sourceBalance = Number(sourceLedger[0].actual_balance || 0);

      if (amountVal > sourceBalance) {
        throw new AppError('Amount exceeds source goal balance', 400, 'BAD_REQUEST');
      }

      // Check destination balance
      const [destLedger] = await connection.execute(
        `SELECT
           COALESCE(SUM(CASE WHEN transaction_type IN ('contribution', 'adjustment', 'reallocation_in') THEN amount ELSE 0 END), 0) -
           COALESCE(SUM(CASE WHEN transaction_type IN ('withdrawal', 'reallocation_out', 'execution') THEN amount ELSE 0 END), 0) AS actual_balance
         FROM goal_transactions
         WHERE goal_id = ?`,
        [destGoal.id]
      );
      const destBalance = Number(destLedger[0].actual_balance || 0);
      const destTarget = Number(destGoal.target_amount);

      if (destBalance + amountVal > destTarget) {
        throw new AppError('Reallocation amount causes destination overfunding', 400, 'BAD_REQUEST');
      }

      // Reallocation out
      await connection.execute(
        `INSERT INTO goal_transactions
         (user_id, goal_id, amount, transaction_type, related_goal_id, idempotency_key, request_hash, description)
         VALUES (?, ?, ?, 'reallocation_out', ?, ?, ?, CONCAT('Reallocated to ', ?))`,
        [userId, sourceGoal.id, amountVal, destGoal.id, idempotencyKey || null, requestHash || null, destGoal.name]
      );

      // Reallocation in
      await connection.execute(
        `INSERT INTO goal_transactions
         (user_id, goal_id, amount, transaction_type, related_goal_id, description)
         VALUES (?, ?, ?, 'reallocation_in', ?, CONCAT('Reallocated from ', ?))`,
        [userId, destGoal.id, amountVal, sourceGoal.id, sourceGoal.name]
      );

      const newSourceBalance = sourceBalance - amountVal;
      const newSourceStatus = newSourceBalance < Number(sourceGoal.target_amount) ? 'active' : 'ready';
      await connection.execute(
        'UPDATE goals SET current_balance = ?, status = ? WHERE id = ?',
        [newSourceBalance, newSourceStatus, sourceGoal.id]
      );

      const newDestBalance = destBalance + amountVal;
      let newDestStatus = destGoal.status;
      let readyAt = destGoal.ready_at;
      if (newDestBalance === destTarget) {
        newDestStatus = 'ready';
        readyAt = new Date();
      }

      if (newDestStatus === 'ready') {
         await connection.execute(
           'UPDATE goals SET current_balance = ?, status = ?, ready_at = ? WHERE id = ?',
           [newDestBalance, newDestStatus, readyAt, destGoal.id]
         );
      } else {
         await connection.execute(
           'UPDATE goals SET current_balance = ?, status = ? WHERE id = ?',
           [newDestBalance, newDestStatus, destGoal.id]
         );
      }

      await connection.commit();
      return { success: true, message: 'Goal reallocated successfully' };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  static async deleteGoal(userId, goalId) {
    const [txRows] = await db.execute(
      'SELECT id FROM goal_transactions WHERE goal_id = ? LIMIT 1',
      [goalId]
    );

    if (txRows.length > 0) {
      const err = new Error('Cannot hard-delete a goal with financial ledger history. Please soft-delete or cancel the goal instead.');
      err.statusCode = 409;
      err.code = 'GOAL_HAS_LEDGER_HISTORY';
      throw err;
    }

    const [result] = await db.execute(
      `DELETE FROM goals WHERE id = ? AND user_id = ?`,
      [goalId, userId]
    );
    return result.affectedRows > 0;
  }

  // ---------------------------------------------------------
  // COMMITMENTS
  // ---------------------------------------------------------
  static async getCommitments(userId) {
    const [rows] = await db.execute(
      `SELECT * FROM financial_commitments WHERE user_id = ? AND status != 'cancelled' ORDER BY next_due_date ASC`,
      [userId]
    );
    return rows;
  }

  static async createCommitment(userId, data) {
    const amount = Math.round(data.amount || 0);
    const name = data.name || data.type; // fallback to type if name not provided
    const frequency = data.frequency || 'monthly';
    let nextDueDate = data.nextDueDate ? new Date(data.nextDueDate) : null;
    
    // If dueDay is provided, calculate the next due date
    if (data.dueDay && !nextDueDate) {
       const today = new Date();
       let month = today.getMonth();
       let year = today.getFullYear();
       if (today.getDate() > data.dueDay) {
           month++;
           if (month > 11) {
               month = 0;
               year++;
           }
       }
       nextDueDate = new Date(year, month, data.dueDay);
    }

    const flexibility = data.flexibility || 'fixed';

    const sourceType = data.sourceType || 'manual';
    const originalImageUrl = data.originalImageUrl || null;
    const originalTranscript = data.originalTranscript || null;

    const [result] = await db.execute(
      `INSERT INTO financial_commitments
       (user_id, name, amount, frequency, next_due_date, budget_bucket, flexibility, status, source_type, original_image_url, original_transcript)
       VALUES (?, ?, ?, ?, ?, 'needs', ?, 'active', ?, ?, ?)`,
      [userId, name, amount, frequency, nextDueDate, flexibility, sourceType, originalImageUrl, originalTranscript]
    );
    return result.insertId;
  }

  static async updateCommitment(userId, commitmentId, data) {
    const updates = [];
    const values = [];

    if (data.name !== undefined) { updates.push('name = ?'); values.push(data.name); }
    if (data.amount !== undefined) { updates.push('amount = ?'); values.push(Math.round(data.amount)); }
    if (data.frequency !== undefined) { updates.push('frequency = ?'); values.push(data.frequency); }
    if (data.nextDueDate !== undefined) { updates.push('next_due_date = ?'); values.push(new Date(data.nextDueDate)); }
    if (data.flexibility !== undefined) { updates.push('flexibility = ?'); values.push(data.flexibility); }
    if (data.status !== undefined) { updates.push('status = ?'); values.push(data.status); }

    if (updates.length === 0) return true;

    values.push(commitmentId, userId);

    const [result] = await db.execute(
      `UPDATE financial_commitments SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`,
      values
    );
    return result.affectedRows > 0;
  }

  static async deleteCommitment(userId, commitmentId) {
    // Soft delete per user instructions
    const [result] = await db.execute(
      `UPDATE financial_commitments SET status = 'cancelled' WHERE id = ? AND user_id = ?`,
      [commitmentId, userId]
    );
    return result.affectedRows > 0;
  }

  static async getActiveCommitmentsTotal(userId) {
    const [rows] = await db.execute(
      `SELECT SUM(amount) as total FROM financial_commitments WHERE user_id = ? AND status = 'active'`,
      [userId]
    );
    return parseInt(rows[0].total || 0);
  }

  static async getConfirmedNeedsExpenses(userId) {
    // Only confirmed transactions affect metrics, exclude capital_expense from needs/wants
    const [rows] = await db.execute(
      `SELECT SUM(amount) as total FROM transactions
       WHERE user_id = ?
         AND transaction_type = 'expense'
         AND budget_bucket = 'needs'
         AND status = 'confirmed'`,
      [userId]
    );
    return parseInt(rows[0].total || 0);
  }

  static async getDashboardTotals(userId) {
    const [rows] = await db.execute(
      `SELECT
        SUM(CASE WHEN transaction_type = 'income' THEN amount ELSE 0 END) as totalIncome,
        SUM(CASE WHEN transaction_type = 'expense' THEN amount ELSE 0 END) as totalExpenses
       FROM transactions
       WHERE user_id = ?`,
      [userId]
    );

    const [goalRows] = await db.execute(
      `SELECT COUNT(*) as activeGoals FROM goals WHERE user_id = ? AND status = 'active'`,
      [userId]
    );

    const totalIncome = parseInt(rows[0].totalIncome || 0);
    const totalExpenses = parseInt(rows[0].totalExpenses || 0);
    const activeGoals = parseInt(goalRows[0].activeGoals || 0);

    return { totalIncome, totalExpenses, activeGoals };
  }

  static async getAllocation(userId) {
    const [profileRows] = await db.execute(
      `SELECT expected_monthly_income, detected_tier FROM financial_profiles WHERE user_id = ?`,
      [userId]
    );
    const [prefRows] = await db.execute(
      `SELECT needs_bps, wants_bps, savings_bps FROM allocation_preferences WHERE user_id = ?`,
      [userId]
    );

    if (profileRows.length === 0 || prefRows.length === 0) {
      return null;
    }

    return {
      income: parseInt(profileRows[0].expected_monthly_income || 0),
      tier: profileRows[0].detected_tier,
      needsBps: parseInt(prefRows[0].needs_bps || 0),
      wantsBps: parseInt(prefRows[0].wants_bps || 0),
      savingsBps: parseInt(prefRows[0].savings_bps || 0)
    };
  }

  static async getSavingsAllocation(userId) {
    const [rows] = await db.execute("SELECT * FROM savings_allocations WHERE user_id = ? AND status = 'provisional' ORDER BY id DESC LIMIT 1", [userId]);
    if (rows.length === 0) return null;
    const allocation = rows[0];

    const [goalRows] = await db.execute('SELECT goal_id, planned_amount FROM goal_savings_allocations WHERE allocation_id = ?', [allocation.id]);

    return {
      id: allocation.id,
      savingsAmount: parseInt(allocation.savings_amount),
      emergencyFundRate: parseFloat(allocation.emergency_fund_rate),
      emergencyFundAmount: parseInt(allocation.emergency_fund_amount),
      totalGoalAllocations: parseInt(allocation.total_goal_allocations),
      unallocatedSavingsAmount: parseInt(allocation.unallocated_savings_amount),
      status: allocation.status,
      goals: goalRows.map(r => ({ goalId: r.goal_id, plannedAmount: parseInt(r.planned_amount) }))
    };
  }

  // ---------------------------------------------------------
  // CYCLE-ACTIVITY: open-cycle lookup
  // ---------------------------------------------------------

  /**
   * Find the user's open cycle. connOrNull: pass an open connection to run
   * inside a transaction, or null to use the pool.
   */
  static async findOpenCycleForUser(connOrNull, userId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT id, user_id, start_date, end_date, status
         FROM financial_cycles
        WHERE user_id = ? AND status = 'open'
        LIMIT 1`,
      [userId]
    );
    return rows[0] || null;
  }

  // ---------------------------------------------------------
  // COMMITMENT OCCURRENCES
  // ---------------------------------------------------------

  /**
   * Return active commitments for the user (used when generating occurrences
   * at cycle-open time). Accepts an open connection so it runs inside the
   * same transaction as cycle creation.
   */
  static async getActiveCommitmentsForUser(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, name, amount, frequency, next_due_date, budget_bucket
         FROM financial_commitments
        WHERE user_id = ? AND status = 'active'`,
      [userId]
    );
    return rows;
  }

  /**
   * Insert one occurrence row. Uses INSERT IGNORE so the unique constraint
   * (commitment_id, cycle_id, due_date) acts as the idempotency guard —
   * calling this twice for the same key is a silent no-op.
   */
  static async createOccurrence(conn, { commitmentId, cycleId, dueDate, amount, status }) {
    const [result] = await conn.execute(
      `INSERT IGNORE INTO commitment_occurrences
         (commitment_id, cycle_id, due_date, amount, status)
       VALUES (?, ?, ?, ?, ?)`,
      [commitmentId, cycleId, dueDate, amount, status || 'upcoming']
    );
    return result.insertId; // 0 when ignored (duplicate)
  }

  /**
   * Fetch all occurrences for a cycle, scoped to the authenticated user via
   * the commitment's user_id join.
   */
  static async getOccurrencesByCycle(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT co.id, co.commitment_id, co.cycle_id, co.due_date,
              co.amount, co.status, co.paid_transaction_id,
              fc.name AS commitment_name
         FROM commitment_occurrences co
         JOIN financial_commitments fc ON fc.id = co.commitment_id
        WHERE co.cycle_id = ? AND fc.user_id = ?
        ORDER BY co.due_date ASC`,
      [cycleId, userId]
    );
    return rows;
  }

  /**
   * Mark an occurrence as paid by linking it to a confirmed transaction.
   * Enforces:
   *   - occurrence belongs to a cycle owned by userId
   *   - transaction is confirmed and owned by userId
   *   - occurrence is not already paid/waived
   * Returns the updated occurrence id, or throws AppError.
   */
  static async markOccurrencePaid(conn, userId, occurrenceId, transactionId) {
    const { AppError } = require('../utils/app-error');

    // Lock occurrence + verify ownership via cycle
    const [occRows] = await conn.execute(
      `SELECT co.id, co.status, co.cycle_id, fc.user_id AS commitment_user_id
         FROM commitment_occurrences co
         JOIN financial_commitments fc ON fc.id = co.commitment_id
        WHERE co.id = ? AND fc.user_id = ?
          FOR UPDATE`,
      [occurrenceId, userId]
    );
    if (occRows.length === 0) {
      throw new AppError('Occurrence not found or access denied.', 404, 'OCCURRENCE_NOT_FOUND');
    }
    const occ = occRows[0];
    if (occ.status === 'paid') {
      throw new AppError('Occurrence is already marked as paid.', 409, 'OCCURRENCE_ALREADY_PAID');
    }
    if (occ.status === 'waived') {
      throw new AppError('Cannot pay a waived occurrence.', 409, 'OCCURRENCE_WAIVED');
    }

    // Verify transaction: must be confirmed and owned by same user
    const [txRows] = await conn.execute(
      `SELECT id, status, user_id FROM transactions
        WHERE id = ? AND user_id = ? AND status = 'confirmed'`,
      [transactionId, userId]
    );
    if (txRows.length === 0) {
      throw new AppError(
        'Transaction not found, not confirmed, or access denied.',
        422,
        'TRANSACTION_NOT_CONFIRMED'
      );
    }

    await conn.execute(
      `UPDATE commitment_occurrences
          SET status = 'paid', paid_transaction_id = ?
        WHERE id = ?`,
      [transactionId, occurrenceId]
    );

    return occurrenceId;
  }

  /**
   * Return confirmed totals per bucket for a cycle (used in tests and future
   * dashboard queries). Excludes capital_expense from needs/wants.
   */
  static async getConfirmedTotalsByCycle(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT
         budget_bucket,
         SUM(amount) AS total
         FROM transactions
        WHERE user_id    = ?
          AND cycle_id   = ?
          AND status     = 'confirmed'
          AND transaction_type = 'expense'
          AND budget_bucket IN ('needs','wants')
        GROUP BY budget_bucket`,
      [userId, cycleId]
    );
    const totals = { needs: 0, wants: 0 };
    for (const r of rows) {
      totals[r.budget_bucket] = Number(r.total || 0);
    }
    return totals;
  }

  /**
   * Return total of unpaid occurrence amounts for a cycle (reserves Needs).
   */
  static async getUnpaidOccurrencesTotal(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT COALESCE(SUM(co.amount), 0) AS total
         FROM commitment_occurrences co
         JOIN financial_commitments fc ON fc.id = co.commitment_id
        WHERE co.cycle_id = ?
          AND fc.user_id  = ?
          AND co.status IN ('upcoming','due','overdue')`,
      [cycleId, userId]
    );
    return Number(rows[0].total || 0);
  }
}

module.exports = { FinanceRepository };
