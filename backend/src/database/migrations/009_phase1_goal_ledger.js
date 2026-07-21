const { db } = require('../../config/database');

async function up() {
  console.log('Running migration 009: Phase 1 Goal Ledger');
  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    // 1. Modify existing `goals` table safely via information_schema
    console.log('Modifying goals table...');

    // Helper to check if column exists
    const checkColumn = async (colName) => {
      const [rows] = await connection.query(
        `SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'goals' AND COLUMN_NAME = ?`,
        [colName]
      );
      return rows.length > 0;
    };

    const hasCompletedAt = await checkColumn('completed_at');
    const hasReadyAt = await checkColumn('ready_at');
    const hasExecutedAt = await checkColumn('executed_at');
    const hasPriority = await checkColumn('priority');

    if (hasCompletedAt && !hasReadyAt) {
      await connection.query(`ALTER TABLE goals RENAME COLUMN completed_at TO ready_at`);
    } else if (!hasReadyAt) {
      await connection.query(`ALTER TABLE goals ADD COLUMN ready_at TIMESTAMP NULL AFTER status`);
    }

    if (!hasExecutedAt) {
      await connection.query(`ALTER TABLE goals ADD COLUMN executed_at TIMESTAMP NULL AFTER ready_at`);
    }
    if (!hasPriority) {
      await connection.query(`ALTER TABLE goals ADD COLUMN priority INT DEFAULT 5 AFTER target_date`);
    }

    // Always update the status ENUM to include all required values.
    await connection.query(`
      ALTER TABLE goals
      MODIFY COLUMN status ENUM('draft', 'active', 'paused', 'ready', 'executed', 'cancelled') DEFAULT 'draft'
    `);

    // 2. Data Migration for Goals
    console.log('Migrating old goal statuses...');

    // Map goals to 'ready' only if they reached target amount, and aren't already executed/ready/cancelled
    const [completedGoals] = await connection.query(`
      UPDATE goals
      SET status = 'ready', ready_at = CURRENT_TIMESTAMP
      WHERE current_balance >= target_amount AND status NOT IN ('executed', 'ready', 'cancelled')
    `);
    console.log(`Updated ${completedGoals.affectedRows} goals to 'ready' state.`);

    // 3. Create `goal_transactions` table
    console.log('Creating goal_transactions table...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS goal_transactions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id BIGINT UNSIGNED NOT NULL,
        goal_id BIGINT UNSIGNED NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        transaction_type ENUM('contribution', 'withdrawal', 'reallocation_in', 'reallocation_out', 'execution', 'adjustment') NOT NULL,
        related_goal_id BIGINT UNSIGNED NULL,
        source_transaction_id BIGINT UNSIGNED NULL,
        idempotency_key VARCHAR(255) NULL,
        request_hash VARCHAR(255) NULL,
        description VARCHAR(255) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT uq_user_idempotency UNIQUE (user_id, idempotency_key)
      )
    `);

    // Helper to check if index exists
    const checkIndex = async (tableName, indexName) => {
      const [rows] = await connection.query(
        `SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?`,
        [tableName, indexName]
      );
      return rows.length > 0;
    };

    if (!(await checkIndex('goal_transactions', 'idx_goal_trans_goal_date'))) {
      await connection.query('CREATE INDEX idx_goal_trans_goal_date ON goal_transactions(goal_id, created_at)');
    }
    if (!(await checkIndex('goal_transactions', 'idx_goal_trans_user_date'))) {
      await connection.query('CREATE INDEX idx_goal_trans_user_date ON goal_transactions(user_id, created_at)');
    }
    if (!(await checkIndex('goal_transactions', 'idx_goal_trans_type'))) {
      await connection.query('CREATE INDEX idx_goal_trans_type ON goal_transactions(transaction_type)');
    }

    // 4. Balance Migration Strategy (Opening Adjustments)
    console.log('Migrating existing balances to ledger...');
    const [activeBalances] = await connection.query(`
      SELECT id, user_id, current_balance
      FROM goals
      WHERE current_balance > 0
    `);

    let adjustmentsCreated = 0;
    for (const goal of activeBalances) {
      const idempotencyKey = `phase1-opening-balance:${goal.id}`;
      const requestHash = `hash-phase1-opening-balance:${goal.id}`;
      const description = 'Migration opening balance';

      const [insertResult] = await connection.query(`
        INSERT IGNORE INTO goal_transactions
        (user_id, goal_id, amount, transaction_type, idempotency_key, request_hash, description)
        VALUES (?, ?, ?, 'adjustment', ?, ?, ?)
      `, [goal.user_id, goal.id, goal.current_balance, idempotencyKey, requestHash, description]);

      if (insertResult.affectedRows > 0) adjustmentsCreated++;
    }

    console.log(`Created ${adjustmentsCreated} opening balance adjustments.`);

    await connection.commit();
    console.log('Migration 009 applied successfully.');
  } catch (error) {
    await connection.rollback();
    console.error('Migration failed, rolled back:', error);
    throw error;
  } finally {
    connection.release();
  }
}

async function down() {
  console.log('Rolling back migration 009');
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    await connection.query('DROP TABLE IF EXISTS goal_transactions');
    await connection.query('ALTER TABLE goals DROP COLUMN priority, DROP COLUMN ready_at, DROP COLUMN executed_at');
    await connection.commit();
    console.log('Rollback successful.');
  } catch (error) {
    await connection.rollback();
    console.error('Rollback failed:', error);
    throw error;
  } finally {
    connection.release();
  }
}

module.exports = { up, down };
