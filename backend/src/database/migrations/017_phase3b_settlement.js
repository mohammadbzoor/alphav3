/**
 * Migration 017: Phase 3B – Financial Cycle Settlement and Closure
 *
 * Creates:
 *   - cycle_settlements: Stores settlement calculations and lifecycle state
 *   - settlement_actions: Stores approved surplus distribution actions
 *
 * Enforces:
 *   - One settlement per cycle (unique constraint)
 *   - Settlement actions cannot be cascade-deleted
 *   - Non-negative amounts
 *   - target_goal_id required only for goal_allocation actions
 */

'use strict';

const { db } = require('../../config/database');

async function tableExists(conn, tableName) {
  const [rows] = await conn.execute(
    `SELECT COUNT(*) as cnt FROM information_schema.tables
     WHERE table_schema = DATABASE() AND table_name = ?`,
    [tableName]
  );
  return rows[0].cnt > 0;
}

exports.up = async function() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    console.log('Running migration 017: Phase 3B – Financial Cycle Settlement and Closure');

    // ── 1. Create cycle_settlements table ───────────────────────────── //
    if (!(await tableExists(conn, 'cycle_settlements'))) {
      await conn.query(`
        CREATE TABLE cycle_settlements (
          id                          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          cycle_id                    BIGINT UNSIGNED NOT NULL,
          expected_income             BIGINT UNSIGNED NOT NULL,
          actual_recurring_income     BIGINT UNSIGNED NOT NULL,
          unexpected_income           BIGINT UNSIGNED NOT NULL,
          planned_needs               BIGINT UNSIGNED NOT NULL,
          actual_needs                BIGINT UNSIGNED NOT NULL,
          planned_wants               BIGINT UNSIGNED NOT NULL,
          actual_wants                BIGINT UNSIGNED NOT NULL,
          planned_savings             BIGINT UNSIGNED NOT NULL,
          actual_savings              BIGINT UNSIGNED NOT NULL,
          total_actual_outflows       BIGINT UNSIGNED NOT NULL,
          surplus                     BIGINT UNSIGNED NOT NULL,
          deficit                     BIGINT UNSIGNED NOT NULL,
          status                      ENUM('pending','approved') NOT NULL DEFAULT 'pending',
          approved_at                 TIMESTAMP       NULL,
          closed_at                   TIMESTAMP       NULL,
          created_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          UNIQUE KEY uq_settlement_cycle (cycle_id),
          KEY idx_settlement_cycle (cycle_id),
          KEY idx_settlement_status (status),
          CONSTRAINT chk_settlement_amounts
            CHECK (expected_income >= 0 AND
                   actual_recurring_income >= 0 AND
                   unexpected_income >= 0 AND
                   planned_needs >= 0 AND
                   actual_needs >= 0 AND
                   planned_wants >= 0 AND
                   actual_wants >= 0 AND
                   planned_savings >= 0 AND
                   actual_savings >= 0 AND
                   total_actual_outflows >= 0 AND
                   surplus >= 0 AND
                   deficit >= 0),
          CONSTRAINT chk_settlement_surplus_deficit
            CHECK ((surplus > 0 AND deficit = 0) OR
                   (deficit > 0 AND surplus = 0) OR
                   (surplus = 0 AND deficit = 0))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `);
      console.log('  cycle_settlements: created');
    } else {
      console.log('  cycle_settlements: already exists, skipped');
    }

    // ── 2. Create settlement_actions table ──────────────────────────── //
    if (!(await tableExists(conn, 'settlement_actions'))) {
      await conn.query(`
        CREATE TABLE settlement_actions (
          id                          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          settlement_id              BIGINT UNSIGNED NOT NULL,
          action_type                 ENUM('carry_forward','emergency_fund','goal_allocation','unallocated_savings','custom') NOT NULL,
          amount                      BIGINT UNSIGNED NOT NULL,
          target_goal_id              BIGINT UNSIGNED NULL,
          description                 VARCHAR(255)    NULL,
          created_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          KEY idx_settlement_action_settlement (settlement_id),
          KEY idx_settlement_action_goal (target_goal_id),
          CONSTRAINT chk_settlement_action_amount
            CHECK (amount >= 0),
          CONSTRAINT chk_settlement_action_goal_required
            CHECK (
              (action_type = 'goal_allocation' AND target_goal_id IS NOT NULL) OR
              (action_type != 'goal_allocation')
            )
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `);
      console.log('  settlement_actions: created');
    } else {
      console.log('  settlement_actions: already exists, skipped');
    }

    // ── 3. Add closed_at column to financial_cycles ─────────────────── //
    const [columns] = await conn.execute(
      `SELECT COLUMN_NAME FROM information_schema.columns
       WHERE table_schema = DATABASE() AND table_name = 'financial_cycles' AND column_name = 'closed_at'`
    );
    if (columns.length === 0) {
      await conn.query(`
        ALTER TABLE financial_cycles
        ADD COLUMN closed_at TIMESTAMP NULL AFTER status
      `);
      console.log('  financial_cycles.closed_at: added');
    } else {
      console.log('  financial_cycles.closed_at: already exists, skipped');
    }

    // ── 4. Update financial_cycles status ENUM to include settlement_pending and closed ── //
    const [statusEnum] = await conn.execute(`
      SELECT COLUMN_TYPE FROM information_schema.columns
      WHERE table_schema = DATABASE() AND table_name = 'financial_cycles' AND column_name = 'status'
    `);
    const currentStatus = statusEnum[0]?.COLUMN_TYPE || '';
    if (!currentStatus.includes('settlement_pending')) {
      await conn.query(`
        ALTER TABLE financial_cycles
        MODIFY COLUMN status ENUM('open','settlement_pending','closed') NOT NULL DEFAULT 'open'
      `);
      console.log('  financial_cycles.status: updated to include settlement_pending and closed');
    } else {
      console.log('  financial_cycles.status: already includes settlement_pending and closed, skipped');
    }

    await conn.commit();
    console.log('Migration 017 applied successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 017 failed, rolled back:', err.message);
    throw err;
  } finally {
    conn.release();
  }
};

exports.down = async function() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    console.log('Rolling back migration 017');

    await conn.query('DROP TABLE IF EXISTS settlement_actions');
    console.log('  settlement_actions: dropped');

    await conn.query('DROP TABLE IF EXISTS cycle_settlements');
    console.log('  cycle_settlements: dropped');

    await conn.query('ALTER TABLE financial_cycles DROP COLUMN IF EXISTS closed_at');
    console.log('  financial_cycles.closed_at: dropped');

    await conn.query(`
      ALTER TABLE financial_cycles
      MODIFY COLUMN status ENUM('open') NOT NULL DEFAULT 'open'
    `);
    console.log('  financial_cycles.status: reverted to open only');

    await conn.commit();
    console.log('Migration 017 rolled back successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 017 rollback failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
};
