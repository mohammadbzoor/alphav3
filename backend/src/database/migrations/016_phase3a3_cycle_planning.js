/**
 * Migration 016 – Phase 3A.3: Cycle Planning and Dashboard Integration
 *
 * Creates goal_cycle_allocations table for linking goals to cycles with planned
 * and actual amounts. Also adds cycle_savings_allocations table to link Phase 2C
 * provisional savings allocations to cycles.
 *
 * Safe to run multiple times.
 */

'use strict';

const { db } = require('../../config/database');

async function indexExists(conn, table, indexName) {
  const [rows] = await conn.query(
    `SELECT INDEX_NAME
       FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME   = ?
        AND INDEX_NAME   = ?`,
    [table, indexName]
  );
  return rows.length > 0;
}

async function tableExists(conn, tableName) {
  const [rows] = await conn.query(
    `SELECT TABLE_NAME
       FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ?`,
    [tableName]
  );
  return rows.length > 0;
}

async function up() {
  console.log('Running migration 016: Phase 3A.3 Cycle Planning and Dashboard Integration');

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // ── 1. Create goal_cycle_allocations table ─────────────────────── //
    if (!(await tableExists(conn, 'goal_cycle_allocations'))) {
      await conn.query(`
        CREATE TABLE goal_cycle_allocations (
          id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          cycle_id            BIGINT UNSIGNED NOT NULL,
          goal_id             BIGINT UNSIGNED NOT NULL,
          planned_amount      BIGINT UNSIGNED NOT NULL,
          actual_amount       BIGINT UNSIGNED NOT NULL DEFAULT 0,
          priority_snapshot   TINYINT UNSIGNED NOT NULL,
          created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          UNIQUE KEY uq_goal_cycle (goal_id, cycle_id),
          KEY idx_cycle_allocations (cycle_id),
          KEY idx_goal_allocations (goal_id),
          CONSTRAINT fk_goal_cycle_allocation_cycle
            FOREIGN KEY (cycle_id) REFERENCES financial_cycles (id)
            ON DELETE RESTRICT ON UPDATE RESTRICT,
          CONSTRAINT fk_goal_cycle_allocation_goal
            FOREIGN KEY (goal_id) REFERENCES goals (id)
            ON DELETE RESTRICT ON UPDATE RESTRICT,
          CONSTRAINT chk_goal_cycle_planned_amount
            CHECK (planned_amount >= 0),
          CONSTRAINT chk_goal_cycle_actual_amount
            CHECK (actual_amount >= 0)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `);
      console.log('  goal_cycle_allocations: created');
    } else {
      console.log('  goal_cycle_allocations: already exists, skipped');
    }

    // ── 2. Create cycle_savings_allocations table ───────────────────── //
    if (!(await tableExists(conn, 'cycle_savings_allocations'))) {
      await conn.query(`
        CREATE TABLE cycle_savings_allocations (
          id                          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          cycle_id                    BIGINT UNSIGNED NOT NULL,
          savings_amount              BIGINT UNSIGNED NOT NULL,
          emergency_fund_amount       BIGINT UNSIGNED NOT NULL,
          emergency_fund_rate         DECIMAL(5,2)    NOT NULL,
          total_goal_allocations      BIGINT UNSIGNED NOT NULL,
          unallocated_savings_amount  BIGINT UNSIGNED NOT NULL,
          status                      ENUM('planned','executed') NOT NULL DEFAULT 'planned',
          created_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          UNIQUE KEY uq_cycle_savings (cycle_id),
          KEY idx_cycle_savings_cycle (cycle_id),
          CONSTRAINT chk_cycle_savings_amount
            CHECK (savings_amount >= 0),
          CONSTRAINT chk_cycle_savings_invariant
            CHECK (
              savings_amount =
              emergency_fund_amount + total_goal_allocations + unallocated_savings_amount
            )
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `);
      console.log('  cycle_savings_allocations: created');
    } else {
      console.log('  cycle_savings_allocations: already exists, skipped');
    }

    await conn.commit();
    console.log('Migration 016 applied successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 016 failed, rolled back:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

async function down() {
  console.log('Reverting migration 016: Phase 3A.3 Cycle Planning and Dashboard Integration');
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    await conn.query('DROP TABLE IF EXISTS cycle_savings_allocations');
    await conn.query('DROP TABLE IF EXISTS goal_cycle_allocations');

    await conn.commit();
    console.log('Migration 016 reverted successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 016 revert failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { up, down };
