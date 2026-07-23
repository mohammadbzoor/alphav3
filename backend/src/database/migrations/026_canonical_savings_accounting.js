'use strict';

const { db } = require('../../config/database');

async function up() {
  console.log('Running migration 026: Canonical Savings Accounting');
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    await conn.query(`
      ALTER TABLE goal_transactions
      ADD COLUMN cycle_id BIGINT UNSIGNED NULL AFTER goal_id,
      ADD COLUMN source_type VARCHAR(50) NULL AFTER cycle_id,
      ADD COLUMN source_id BIGINT UNSIGNED NULL AFTER source_type,
      ADD COLUMN settlement_id BIGINT UNSIGNED NULL AFTER source_id;
    `);

    await conn.query(`
      ALTER TABLE goal_transactions
      ADD CONSTRAINT fk_goal_transactions_cycle
        FOREIGN KEY (cycle_id) REFERENCES financial_cycles (id)
        ON DELETE SET NULL ON UPDATE RESTRICT
    `);

    await conn.query(`
      ALTER TABLE goal_transactions
      ADD CONSTRAINT fk_goal_transactions_settlement
        FOREIGN KEY (settlement_id) REFERENCES cycle_settlements (id)
        ON DELETE SET NULL ON UPDATE RESTRICT
    `);

    await conn.query(`
      CREATE INDEX idx_goal_tx_user_cycle_type ON goal_transactions (user_id, cycle_id, transaction_type);
    `);
    
    await conn.query(`
      CREATE INDEX idx_goal_tx_goal_cycle ON goal_transactions (goal_id, cycle_id);
    `);
    
    await conn.query(`
      CREATE INDEX idx_goal_tx_source ON goal_transactions (source_type, source_id);
    `);

    await conn.query(`
      CREATE UNIQUE INDEX uq_goal_tx_settlement ON goal_transactions (settlement_id, goal_id, transaction_type);
    `);

    await conn.commit();
    console.log('Migration 026 applied successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 026 failed, rolled back:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

async function down() {
  console.log('Reverting migration 026: Canonical Savings Accounting');
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    await conn.query(`ALTER TABLE goal_transactions DROP INDEX uq_goal_tx_settlement`);
    await conn.query(`ALTER TABLE goal_transactions DROP INDEX idx_goal_tx_source`);
    await conn.query(`ALTER TABLE goal_transactions DROP INDEX idx_goal_tx_goal_cycle`);
    await conn.query(`ALTER TABLE goal_transactions DROP INDEX idx_goal_tx_user_cycle_type`);
    
    await conn.query(`ALTER TABLE goal_transactions DROP FOREIGN KEY fk_goal_transactions_settlement`);
    await conn.query(`ALTER TABLE goal_transactions DROP FOREIGN KEY fk_goal_transactions_cycle`);

    await conn.query(`
      ALTER TABLE goal_transactions
      DROP COLUMN settlement_id,
      DROP COLUMN source_id,
      DROP COLUMN source_type,
      DROP COLUMN cycle_id;
    `);

    await conn.commit();
    console.log('Migration 026 reverted successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 026 revert failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { up, down };
