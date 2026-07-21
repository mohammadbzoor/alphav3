const { db } = require('../../config/database');

const up = async () => {
  console.log('Running migration 012: Phase 2C Savings Allocations');

  await db.execute('DROP TABLE IF EXISTS savings_allocations');

  await db.execute(`
    CREATE TABLE savings_allocations (
      id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      user_id BIGINT UNSIGNED NOT NULL,
      savings_amount BIGINT NOT NULL,
      emergency_fund_rate DECIMAL(5,2) NOT NULL DEFAULT 10.00,
      emergency_fund_amount BIGINT NOT NULL,
      total_goal_allocations BIGINT NOT NULL,
      unallocated_savings_amount BIGINT NOT NULL,
      status VARCHAR(50) NOT NULL DEFAULT 'provisional',
      idempotency_key VARCHAR(255) NULL,
      request_hash VARCHAR(255) NULL,
      approved_at DATETIME NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      CONSTRAINT fk_savings_alloc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
    )
  `);

  await db.execute(`
    CREATE TABLE IF NOT EXISTS goal_savings_allocations (
      id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      allocation_id BIGINT UNSIGNED NOT NULL,
      goal_id BIGINT UNSIGNED NOT NULL,
      planned_amount BIGINT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      CONSTRAINT fk_goal_alloc_parent FOREIGN KEY (allocation_id) REFERENCES savings_allocations(id) ON DELETE RESTRICT,
      CONSTRAINT fk_goal_alloc_goal FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE RESTRICT
    )
  `);

  console.log('Migration 012 applied successfully.');
};

const down = async () => {
  console.log('Reverting migration 012: Phase 2C Savings Allocations');
  await db.execute('DROP TABLE IF EXISTS goal_savings_allocations');
  await db.execute('DROP TABLE IF EXISTS savings_allocations');
  console.log('Migration 012 reverted successfully.');
};

module.exports = { up, down };
