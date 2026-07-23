const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');

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

  /**
   * Retrieves the top expense categories for a user within a specific cycle.
   * Returns an array of objects with `category` and `total` fields, ordered by total descending.
   * @param {number|string} userId - The ID of the user.
   * @param {number|string} cycleId - The ID of the financial cycle.
   * @param {number} [limit=5] - Maximum number of categories to return.
   */
  static async getTopExpenseCategories(userId, cycleId, limit = 5) {
    const limitInt = Number(limit) || 5;
    const [rows] = await db.execute(
      `SELECT category, SUM(amount) AS amount, COUNT(*) as transactionCount
       FROM transactions
       WHERE user_id = ? AND cycle_id = ? AND transaction_type = 'expense' AND status = 'confirmed'
       GROUP BY category
       ORDER BY amount DESC, category ASC
       LIMIT ${limitInt}`,
      [userId, cycleId]
    );
    return rows.map(r => {
      const parsed = Number(r.amount);
      return {
        category: r.category,
        amount: Number.isFinite(parsed) ? parsed : 0,
        transactionCount: Number(r.transactionCount)
      };
    });
  }

  static async createExpense(conn, userId, data) {
    const { amount, category, bucket, description, expenseDate, sourceType, paymentMethod, cycleId, originalImageUrl, originalTranscript } = data;
    const [result] = await conn.execute(
      `INSERT INTO transactions
       (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, category,
        description, occurred_at, status, confirmed_at,
        source_type, payment_method, original_image_url, original_transcript)
       VALUES (?, ?, ?, 'outflow', 'expense', ?, ?, ?, ?, 'confirmed', NOW(), ?, ?, ?, ?)`,
      [userId, cycleId, amount, bucket, category, description || null, expenseDate, sourceType, paymentMethod, originalImageUrl || null, originalTranscript || null]
    );
    return result.insertId;
  }

  static async deleteExpense(conn, userId, expenseId) {
    const [result] = await conn.execute(
      `DELETE FROM transactions
       WHERE id = ? AND user_id = ? AND transaction_type = 'expense'`,
      [expenseId, userId]
    );
    return result.affectedRows > 0;
  }

  static async lockTransactionForMutation(conn, userId, transactionId, transactionType) {
    const [rows] = await conn.execute(
      `SELECT t.id, t.cycle_id, c.status as cycle_status
       FROM transactions t
       JOIN financial_cycles c ON t.cycle_id = c.id
       WHERE t.id = ? AND t.user_id = ? AND t.transaction_type = ?
       FOR UPDATE`,
      [transactionId, userId, transactionType]
    );
    return rows[0] || null;
  }

  // ---------------------------------------------------------
  // INCOMES
  // ---------------------------------------------------------
  static async getIncomes(userId) {
    const [rows] = await db.execute(
      `SELECT id, amount, category as source, description, occurred_at as incomeDate,
              income_kind AS incomeKind, created_at as createdAt
       FROM transactions
       WHERE user_id = ? AND transaction_type = 'income'
       ORDER BY occurred_at DESC`,
      [userId]
    );
    return rows;
  }

  static async createIncome(conn, userId, data) {
    const { amount, source, description, incomeDate, isRecurring, sourceType, cycleId, originalImageUrl, originalTranscript } = data;
    const incomeKind = isRecurring ? 'recurring' : 'unexpected';
    
    const [result] = await conn.execute(
      `INSERT INTO transactions
       (user_id, cycle_id, amount, direction, transaction_type, category, description,
        occurred_at, income_kind, status, confirmed_at,
        source_type, original_image_url, original_transcript)
       VALUES (?, ?, ?, 'inflow', 'income', ?, ?, ?, ?, 'confirmed', NOW(), ?, ?, ?)`,
      [userId, cycleId, amount, source, description || null, incomeDate, incomeKind, sourceType, originalImageUrl || null, originalTranscript || null]
    );
    return result.insertId;
  }

  static async deleteIncome(conn, userId, incomeId) {
    const [result] = await conn.execute(
      `DELETE FROM transactions
       WHERE id = ? AND user_id = ? AND transaction_type = 'income'`,
      [incomeId, userId]
    );
    return result.affectedRows > 0;
  }

  // ---------------------------------------------------------
  // GOALS
  // ---------------------------------------------------------
  static async findGoalIdentityByIdAndUserId(executor, goalId, userId) {
    const [rows] = await (executor || db).execute(`SELECT id, user_id, goal_type, is_system_managed, status FROM goals WHERE id = ? AND user_id = ? LIMIT 1`, [goalId, userId]);
    return rows[0] || null;
  }

  static async findLegacyEmergencyFundGoalByUserId(executor, userId) {
    const [rows] = await (executor || db).execute(
      `SELECT id, goal_type, is_system_managed FROM goals WHERE user_id = ? AND goal_type = 'emergency_fund' AND is_system_managed = FALSE LIMIT 1`,
      [userId]
    );
    return rows[0] || null;
  }

  static async getGoals(userId) {
    const [rows] = await db.execute(
      `SELECT id, name, target_amount, current_balance, cycle_allocation,
              planned_contribution, priority, status, target_date, custom_name, goal_type, created_at, ready_at, executed_at, is_system_managed
       FROM goals WHERE user_id = ? ORDER BY created_at DESC`,
      [userId]
    );
    return rows;
  }

  static async createGoal(userId, data) {
    const { goalType, customName, targetAmount, plannedContribution, targetDate, planningMode, priority } = data;
    const [result] = await db.execute(
      `INSERT INTO goals
       (user_id, goal_type, name, custom_name, target_amount, planned_contribution, target_date, planning_mode, priority, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')`,
      [userId, goalType, goalType, customName || null, targetAmount, plannedContribution, targetDate || null, planningMode, priority]
    );
    return result.insertId;
  }

  static async updateGoal(userId, goalId, data) {
    const { goalType, customName, targetAmount, plannedContribution, targetDate, planningMode, priority } = data;
    const [result] = await db.execute(
      `UPDATE goals SET
        goal_type = ?, name = ?, custom_name = ?, target_amount = ?, planned_contribution = ?, target_date = ?, planning_mode = ?, priority = ?
       WHERE id = ? AND user_id = ?`,
      [goalType, goalType, customName || null, targetAmount, plannedContribution, targetDate || null, planningMode, priority, goalId, userId]
    );
    return result.affectedRows;
  }

  static async findGoalForUpdate(connection, goalId, userId) {
    const [rows] = await connection.execute(
      `SELECT id, user_id, status, target_amount, current_balance, planned_contribution, ready_at, name, is_system_managed FROM goals WHERE id = ? AND user_id = ? FOR UPDATE`,
      [goalId, userId]
    );
    return rows[0] || null;
  }

  static async findIdempotencyRecord(connection, userId, idempotencyKey) {
    const [rows] = await connection.execute(
      `SELECT id, user_id, request_hash, idempotency_key FROM goal_transactions WHERE user_id = ? AND idempotency_key = ?`,
      [userId, idempotencyKey]
    );
    return rows[0] || null;
  }

  static async createGoalTransaction(connection, data) {
    const { userId, goalId, amount, transactionType, relatedGoalId, idempotencyKey, requestHash, description } = data;
    try {
      const [result] = await connection.execute(
        `INSERT INTO goal_transactions
         (user_id, goal_id, amount, transaction_type, related_goal_id, idempotency_key, request_hash, description)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [userId, goalId, amount, transactionType, relatedGoalId || null, idempotencyKey || null, requestHash || null, description || null]
      );
      const [rows] = await connection.execute(
        `SELECT id, goal_id, amount, transaction_type FROM goal_transactions WHERE id = ?`,
        [result.insertId]
      );
      return rows[0];
    } catch (e) {
      if (e.code === 'ER_DUP_ENTRY') {
        const [existing] = await connection.execute(
          `SELECT id, user_id, request_hash, idempotency_key FROM goal_transactions WHERE user_id = ? AND idempotency_key = ? FOR SHARE`,
          [userId, idempotencyKey]
        );
        if (existing.length > 0) {
          if (existing[0].request_hash === requestHash) {
            const err = new Error('Concurrent idempotent replay');
            err.code = 'CONCURRENT_IDEMPOTENT_REPLAY';
            err.existingTransaction = existing[0];
            throw err;
          } else {
            throw new AppError('Idempotency key reused with different payload concurrently', 409, 'IDEMPOTENCY_KEY_REUSED');
          }
        }
      }
      throw e;
    }
  }

  static async updateGoalBalanceAndStatus(connection, data) {
    const { goalId, userId, newBalance, newStatus, readyAt, executedAt } = data;
    const updates = ['current_balance = ?', 'status = ?'];
    const values = [newBalance, newStatus];
    if (readyAt !== undefined) { updates.push('ready_at = ?'); values.push(readyAt); }
    if (executedAt !== undefined) { updates.push('executed_at = ?'); values.push(executedAt); }
    
    values.push(goalId, userId);
    
    const [result] = await connection.execute(
      `UPDATE goals
       SET ${updates.join(', ')}
       WHERE id = ? AND user_id = ?`,
      values
    );
    return result.affectedRows;
  }

  static async getGoalTransactions(userId, goalId, limit, offset) {
    const [rows] = await db.execute(
      `SELECT id, goal_id, amount, transaction_type, created_at, description
       FROM goal_transactions
       WHERE user_id = ? AND goal_id = ?
       ORDER BY created_at DESC, id DESC
       LIMIT ? OFFSET ?`,
      [userId, goalId, limit, offset]
    );
    return rows;
  }

  static async getReadyGoals(userId) {
    const [rows] = await db.execute(
      `SELECT id, name, target_amount, current_balance, ready_at
       FROM goals WHERE user_id = ? AND status = 'ready' ORDER BY ready_at ASC`,
      [userId]
    );
    return rows;
  }

  static async getLedgerBalance(connection, goalId, userId) {
    const [ledgerRows] = await connection.execute(
      `SELECT
         COALESCE(SUM(CASE WHEN transaction_type IN ('contribution', 'adjustment', 'reallocation_in') THEN amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN transaction_type IN ('withdrawal', 'reallocation_out', 'execution') THEN amount ELSE 0 END), 0) AS actual_balance
       FROM goal_transactions
       WHERE goal_id = ? AND user_id = ?`,
      [goalId, userId]
    );
    return Number(ledgerRows[0].actual_balance || 0);
  }

  static async createCapitalExpense(connection, userId, amount, description, cycleId) {
    const [res] = await connection.execute(
      `INSERT INTO transactions
       (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, status, occurred_at, confirmed_at, description)
       VALUES (?, ?, ?, 'outflow', 'capital_expense', 'capital_expense', 'confirmed', NOW(), NOW(), CONCAT('Goal executed: ', ?))`,
      [userId, cycleId, amount, description]
    );
    return res.insertId;
  }

  static async deleteGoal(userId, goalId) {
    const [txRows] = await db.execute(
      'SELECT id FROM goal_transactions WHERE goal_id = ? AND user_id = ? LIMIT 1',
      [goalId, userId]
    );
    if (txRows.length > 0) {
      throw new AppError('Cannot hard-delete a goal with financial ledger history. Please soft-delete or cancel the goal instead.', 409, 'GOAL_HAS_LEDGER_HISTORY');
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
      `SELECT id, name, amount, frequency, next_due_date, status, flexibility
       FROM financial_commitments
       WHERE user_id = ? AND status != 'cancelled' ORDER BY next_due_date ASC`,
      [userId]
    );
    return rows;
  }

  static async createCommitment(userId, data) {
    const { amount, name, frequency, nextDueDate, flexibility, sourceType } = data;
    const [result] = await db.execute(
      `INSERT INTO financial_commitments
       (user_id, name, amount, frequency, next_due_date, budget_bucket, flexibility, status, source_type)
       VALUES (?, ?, ?, ?, ?, 'needs', ?, 'active', ?)`,
      [userId, name, amount, frequency, nextDueDate, flexibility, sourceType]
    );
    return result.insertId;
  }

  static async updateCommitment(userId, commitmentId, data) {
    const updates = [];
    const values = [];

    if (data.name !== undefined) { updates.push('name = ?'); values.push(data.name); }
    if (data.amount !== undefined) { updates.push('amount = ?'); values.push(data.amount); }
    if (data.frequency !== undefined) { updates.push('frequency = ?'); values.push(data.frequency); }
    if (data.nextDueDate !== undefined) { updates.push('next_due_date = ?'); values.push(data.nextDueDate); }
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
    const [result] = await db.execute(
      `UPDATE financial_commitments SET status = 'cancelled' WHERE id = ? AND user_id = ?`,
      [commitmentId, userId]
    );
    return result.affectedRows > 0;
  }

  static async getConfirmedNeedsExpenses(userId) {
    const [rows] = await db.execute(
      `SELECT SUM(amount) as total FROM transactions
       WHERE user_id = ?
         AND transaction_type = 'expense'
         AND budget_bucket = 'needs'
         AND status = 'confirmed'`,
      [userId]
    );
    return Number(rows[0].total || 0);
  }

  static async getDashboardTotals(userId) {
    const [rows] = await db.execute(
      `SELECT
        SUM(CASE WHEN transaction_type = 'income' THEN amount ELSE 0 END) as totalIncome,
        SUM(CASE WHEN transaction_type = 'expense' THEN amount ELSE 0 END) as totalExpenses
       FROM transactions
       WHERE user_id = ? AND status = 'confirmed'`,
      [userId]
    );

    const [goalRows] = await db.execute(
      `SELECT COUNT(*) as activeGoals FROM goals WHERE user_id = ? AND status = 'active'`,
      [userId]
    );

    const totalIncome = Number(rows[0].totalIncome || 0);
    const totalExpenses = Number(rows[0].totalExpenses || 0);
    const activeGoals = Number(goalRows[0].activeGoals || 0);

    return { totalIncome, totalExpenses, activeGoals };
  }

  static async getSavingsAllocation(userId) {
    const [rows] = await db.execute(
      "SELECT id, savings_amount, emergency_fund_rate, emergency_fund_amount, total_goal_allocations, unallocated_savings_amount, status FROM savings_allocations WHERE user_id = ? AND status = 'provisional' ORDER BY id DESC LIMIT 1",
      [userId]
    );
    if (rows.length === 0) return null;
    const allocation = rows[0];

    const [goalRows] = await db.execute('SELECT goal_id, planned_amount FROM goal_savings_allocations WHERE allocation_id = ?', [allocation.id]);

    return {
      id: allocation.id,
      savingsAmount: Number(allocation.savings_amount),
      emergencyFundRate: Number(allocation.emergency_fund_rate),
      emergencyFundAmount: Number(allocation.emergency_fund_amount),
      totalGoalAllocations: Number(allocation.total_goal_allocations),
      unallocatedSavingsAmount: Number(allocation.unallocated_savings_amount),
      status: allocation.status,
      goals: goalRows.map(r => ({ goalId: r.goal_id, plannedAmount: Number(r.planned_amount) }))
    };
  }

  // ---------------------------------------------------------
  // CYCLE-ACTIVITY: open-cycle lookup
  // ---------------------------------------------------------
  static async lockOpenCycleForUser(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, user_id, status, start_date, end_date
       FROM financial_cycles
       WHERE user_id = ? AND status = 'open'
       ORDER BY start_date DESC, id DESC
       LIMIT 1
       FOR UPDATE`,
      [userId]
    );
    return rows[0] || null;
  }

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
  static async getActiveCommitmentsForUser(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, name, amount, frequency, next_due_date, budget_bucket
         FROM financial_commitments
        WHERE user_id = ? AND status = 'active'`,
      [userId]
    );
    return rows;
  }

  static async createOccurrence(conn, { commitmentId, cycleId, dueDate, amount, status }) {
    const [result] = await conn.execute(
      `INSERT IGNORE INTO commitment_occurrences
         (commitment_id, cycle_id, due_date, amount, status)
       VALUES (?, ?, ?, ?, ?)`,
      [commitmentId, cycleId, dueDate, amount, status || 'upcoming']
    );
    return result.insertId;
  }

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

  static async markOccurrencePaid(conn, userId, occurrenceId, transactionId) {
    const [occRows] = await conn.execute(
      `SELECT co.id, co.status, co.cycle_id, co.amount, fc.user_id AS commitment_user_id
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

    const [txRows] = await conn.execute(
      `SELECT id, status, user_id, amount, transaction_type, direction, cycle_id FROM transactions
        WHERE id = ? AND user_id = ? AND status = 'confirmed'`,
      [transactionId, userId]
    );
    if (txRows.length === 0) {
      throw new AppError('Transaction not found, not confirmed, or access denied.', 422, 'TRANSACTION_NOT_CONFIRMED');
    }
    
    const tx = txRows[0];
    if (tx.transaction_type !== 'expense' || tx.direction !== 'outflow') {
      throw new AppError('Transaction must be a confirmed expense outflow.', 400, 'INVALID_TRANSACTION_TYPE');
    }
    if (String(tx.cycle_id) !== String(occ.cycle_id)) {
      throw new AppError('Transaction cycle does not match occurrence cycle.', 400, 'CYCLE_MISMATCH');
    }
    if (Number(tx.amount) !== Number(occ.amount)) {
      throw new AppError('Transaction amount must match occurrence amount exactly.', 400, 'AMOUNT_MISMATCH');
    }

    const [checkUsage] = await conn.execute(
      `SELECT id FROM commitment_occurrences WHERE paid_transaction_id = ? AND id != ? LIMIT 1`,
      [transactionId, occurrenceId]
    );
    if (checkUsage.length > 0) {
      throw new AppError('Transaction already linked to another occurrence.', 409, 'TRANSACTION_ALREADY_USED');
    }

    await conn.execute(
      `UPDATE commitment_occurrences
          SET status = 'paid', paid_transaction_id = ?
        WHERE id = ?`,
      [transactionId, occurrenceId]
    );

    return occurrenceId;
  }

  static async getConfirmedTotalsByCycle(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT budget_bucket, SUM(amount) AS total
         FROM transactions
        WHERE user_id = ? AND cycle_id = ? AND status = 'confirmed'
          AND transaction_type = 'expense' AND budget_bucket IN ('needs','wants')
        GROUP BY budget_bucket`,
      [userId, cycleId]
    );
    const totals = { needs: 0, wants: 0 };
    for (const r of rows) { totals[r.budget_bucket] = Number(r.total || 0); }
    return totals;
  }

  static async getUnpaidOccurrencesTotal(userId, cycleId) {
    const [rows] = await db.execute(
      `SELECT COALESCE(SUM(co.amount), 0) AS total
         FROM commitment_occurrences co
         JOIN financial_commitments fc ON fc.id = co.commitment_id
        WHERE co.cycle_id = ? AND fc.user_id  = ? AND co.status IN ('upcoming','due','overdue')`,
      [cycleId, userId]
    );
    return Number(rows[0].total || 0);
  }

  // ---------------------------------------------------------
  // ANALYSIS: bounded read-only methods
  // ---------------------------------------------------------

  /**
   * Returns at most `limit` recent confirmed current-cycle transactions.
   * Excludes descriptions, IDs, and free-text fields for n8n privacy.
   */
  static async getBoundedRecentTransactions(userId, cycleId, limit = 10) {
    const limitInt = Math.min(Math.max(Number(limit) || 10, 1), 10);
    const [rows] = await db.execute(
      `SELECT DATE_FORMAT(occurred_at, '%Y-%m-%dT%H:%i:%s') AS date,
              transaction_type AS type,
              direction,
              status,
              budget_bucket AS budgetBucket,
              amount,
              category
         FROM transactions
        WHERE user_id = ? AND cycle_id = ? AND status = 'confirmed'
          AND transaction_type IN ('expense', 'income')
        ORDER BY occurred_at DESC, id DESC
        LIMIT ${limitInt}`,
      [userId, cycleId]
    );
    return rows;
  }

  /**
   * Returns commitment occurrence summary for analysis.
   * Counts paid/upcoming/overdue and lists up to `limit` unpaid items.
   * Enforces user ownership via financial_commitments join.
   * Does not return names or descriptions.
   */
  static async getCommitmentDetails(userId, limit = 5) {
    const limitInt = Math.min(Math.max(Number(limit) || 5, 1), 10);

    // Aggregates across all non-cancelled commitments for the user
    const [countRows] = await db.execute(
      `SELECT
         SUM(CASE WHEN co.status = 'paid' THEN 1 ELSE 0 END) AS paidCount,
         SUM(CASE WHEN co.status = 'upcoming' THEN 1 ELSE 0 END) AS upcomingCount,
         SUM(CASE WHEN co.status IN ('due', 'overdue') THEN 1 ELSE 0 END) AS overdueCount,
         COALESCE(SUM(CASE WHEN co.status IN ('upcoming', 'due', 'overdue') THEN co.amount ELSE 0 END), 0) AS unpaidAmount
       FROM commitment_occurrences co
       JOIN financial_commitments fc ON fc.id = co.commitment_id
       WHERE fc.user_id = ? AND fc.status != 'cancelled'`,
      [userId]
    );

    const summary = countRows[0] || {};

    // Detailed unpaid items (bounded)
    const [itemRows] = await db.execute(
      `SELECT co.amount,
              fc.frequency,
              co.due_date AS dueDate,
              co.status,
              fc.flexibility
         FROM commitment_occurrences co
         JOIN financial_commitments fc ON fc.id = co.commitment_id
        WHERE fc.user_id = ? AND co.status IN ('upcoming', 'due', 'overdue')
        ORDER BY co.due_date ASC, co.id ASC
        LIMIT ${limitInt}`,
      [userId]
    );

    return {
      paidCount: Number(summary.paidCount || 0),
      upcomingCount: Number(summary.upcomingCount || 0),
      overdueCount: Number(summary.overdueCount || 0),
      unpaidAmount: Number(summary.unpaidAmount || 0),
      items: itemRows
    };
  }

  /**
   * Returns up to `limit` ordinary (non-system, non-emergency-fund) goals for analysis.
   * Enforces user ownership. Does not return names or descriptions.
   */
  static async getOrdinaryGoalDetails(userId, limit = 5) {
    const limitInt = Math.min(Math.max(Number(limit) || 5, 1), 10);

    // Aggregates
    const [aggRows] = await db.execute(
      `SELECT
         COUNT(*) AS totalCount,
         SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS activeCount,
         SUM(CASE WHEN status = 'ready' THEN 1 ELSE 0 END) AS readyCount,
         COALESCE(SUM(target_amount), 0) AS totalTargetAmount,
         COALESCE(SUM(current_balance), 0) AS totalCurrentBalance,
         COALESCE(SUM(target_amount - current_balance), 0) AS totalRemainingAmount
       FROM goals
       WHERE user_id = ? AND is_system_managed = FALSE AND goal_type != 'emergency_fund'
         AND status IN ('active', 'ready')`,
      [userId]
    );

    const agg = aggRows[0] || {};

    // Detailed items (bounded)
    const [itemRows] = await db.execute(
      `SELECT goal_type AS goalType,
              target_amount AS targetAmount,
              current_balance AS currentBalance,
              planned_contribution AS plannedContribution,
              priority,
              status,
              target_date AS targetDate
         FROM goals
        WHERE user_id = ? AND is_system_managed = FALSE AND goal_type != 'emergency_fund'
          AND status IN ('active', 'ready')
        ORDER BY priority ASC, created_at ASC
        LIMIT ${limitInt}`,
      [userId]
    );

    return {
      activeCount: Number(agg.activeCount || 0),
      readyCount: Number(agg.readyCount || 0),
      totalTargetAmount: Number(agg.totalTargetAmount || 0),
      totalCurrentBalance: Number(agg.totalCurrentBalance || 0),
      totalRemainingAmount: Number(agg.totalRemainingAmount || 0),
      items: itemRows
    };
  }

  /**
   * Returns emergency fund goal details for analysis.
   * Looks for the system-managed emergency_fund goal owned by the user.
   */
  static async getEmergencyFundDetails(userId) {
    const [rows] = await db.execute(
      `SELECT target_amount AS targetAmount,
              current_balance AS currentBalance,
              status
         FROM goals
        WHERE user_id = ? AND goal_type = 'emergency_fund' AND is_system_managed = TRUE
        LIMIT 1`,
      [userId]
    );

    if (rows.length === 0) {
      return { exists: false, targetAmount: null, currentBalance: null, status: null };
    }

    const row = rows[0];
    return {
      exists: true,
      targetAmount: Number(row.targetAmount || 0),
      currentBalance: Number(row.currentBalance || 0),
      status: row.status
    };
  }

  /**
   * Returns up to `limit` most recently completed/closed cycles for analysis.
   * Enforces user ownership. Does not return descriptions or free text.
   */
  static async getHistoricalCycles(userId, limit = 3) {
    const limitInt = Math.min(Math.max(Number(limit) || 3, 1), 5);
    const [rows] = await db.execute(
      `SELECT fc.id,
              fc.status,
              DATE_FORMAT(fc.start_date, '%Y-%m-%d') AS startDate,
              DATE_FORMAT(fc.end_date, '%Y-%m-%d') AS endDate,
              fc.expected_income AS expectedIncome,
              cs.actual_recurring_income AS actualRecurringIncome,
              cs.unexpected_income AS unexpectedIncome,
              cs.actual_needs AS actualNeeds,
              cs.actual_wants AS actualWants,
              cs.actual_savings AS actualSavings,
              cs.surplus,
              cs.deficit
         FROM financial_cycles fc
         LEFT JOIN cycle_settlements cs ON cs.cycle_id = fc.id
        WHERE fc.user_id = ? AND fc.status IN ('closed', 'settled')
        ORDER BY fc.end_date DESC, fc.id DESC
        LIMIT ${limitInt}`,
      [userId]
    );
    return rows;
  }
}

module.exports = { FinanceRepository };
