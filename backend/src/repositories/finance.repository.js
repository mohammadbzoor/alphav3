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
}

module.exports = { FinanceRepository };
