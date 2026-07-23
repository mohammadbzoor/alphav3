/**
 * Migration 020: Reconcile cycle_settlements schema (Task A)
 * 
 * Safely resolves the discrepancy between legacy schema from 000_initial_schema.sql
 * and intended Phase 3B schema from 017_phase3b_settlement.js.
 * 
 * Stages:
 * 1. Ensure idempotency via column checks.
 * 2. Add nullable total_actual_outflows and updated_at.
 * 3. Backfill total_actual_outflows exactly from confirmed transaction outflows.
 * 4. Verify all rows are backfilled; block NOT NULL conversion if any are missing.
 * 5. Safely expand status ENUM to preserve legacy values (draft, pending, approved, closed).
 * 6. Audit and replace CHECK constraints.
 * 7. Apply NOT NULL constraints.
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

async function columnExists(conn, tableName, columnName) {
  const [rows] = await conn.execute(
    `SELECT COUNT(*) as cnt FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?`,
    [tableName, columnName]
  );
  return rows[0].cnt > 0;
}

async function getConstraintDefinition(conn, tableName, constraintName) {
  const [rows] = await conn.execute(
    `SELECT CHECK_CLAUSE FROM information_schema.CHECK_CONSTRAINTS
     WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = ?`,
    [constraintName]
  );
  return rows[0] ? rows[0].CHECK_CLAUSE : null;
}

async function dropConstraintIfExists(conn, tableName, constraintName) {
  const def = await getConstraintDefinition(conn, tableName, constraintName);
  if (def) {
    console.log(`  Dropping existing constraint ${constraintName}...`);
    await conn.query(`ALTER TABLE ${tableName} DROP CHECK ${constraintName}`);
  }
}

exports.up = async function() {
  const conn = await db.getConnection();
  try {
    console.log('Running migration 020: Reconcile cycle_settlements schema');

    if (!(await tableExists(conn, 'cycle_settlements'))) {
      console.log('  cycle_settlements table does not exist. Skipping reconciliation.');
      return;
    }

    // Phase 1 & 2: Add columns as nullable
    const hasTotalOutflows = await columnExists(conn, 'cycle_settlements', 'total_actual_outflows');
    if (!hasTotalOutflows) {
      console.log('  Adding total_actual_outflows (NULL) to cycle_settlements...');
      await conn.query(`ALTER TABLE cycle_settlements ADD COLUMN total_actual_outflows BIGINT UNSIGNED NULL AFTER actual_savings`);
    } else {
      console.log('  total_actual_outflows already exists.');
    }

    const hasUpdatedAt = await columnExists(conn, 'cycle_settlements', 'updated_at');
    if (!hasUpdatedAt) {
      console.log('  Adding updated_at to cycle_settlements...');
      await conn.query(`ALTER TABLE cycle_settlements ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`);
    } else {
      console.log('  updated_at already exists.');
    }

    // Phase 3: Backfill total_actual_outflows deterministically
    console.log('  Backfilling total_actual_outflows from transactions...');
    await conn.query(`
      UPDATE cycle_settlements cs
      LEFT JOIN (
        SELECT cycle_id, COALESCE(SUM(amount), 0) as total
        FROM transactions
        WHERE direction = 'outflow' AND status = 'confirmed'
          AND transaction_type IN ('expense', 'capital_expense', 'saving')
        GROUP BY cycle_id
      ) t ON cs.cycle_id = t.cycle_id
      SET cs.total_actual_outflows = COALESCE(t.total, 0)
      WHERE cs.total_actual_outflows IS NULL
    `);

    // Phase 4: Validate backfill completeness
    const [missingRows] = await conn.execute(`SELECT COUNT(*) as cnt FROM cycle_settlements WHERE total_actual_outflows IS NULL`);
    if (missingRows[0].cnt > 0) {
      throw new Error(`CRITICAL: ${missingRows[0].cnt} rows remain NULL after backfill. Cannot safely convert total_actual_outflows to NOT NULL. Migration blocked.`);
    }

    // Apply NOT NULL defaults for total_actual_outflows
    console.log('  Enforcing NOT NULL on total_actual_outflows...');
    await conn.query(`ALTER TABLE cycle_settlements MODIFY COLUMN total_actual_outflows BIGINT UNSIGNED NOT NULL DEFAULT 0`);

    // Phase 5 & 6: Expand status ENUM
    // First, verify we don't have unknown statuses
    const [invalidStatuses] = await conn.execute(`
      SELECT DISTINCT status FROM cycle_settlements 
      WHERE status NOT IN ('draft', 'pending', 'approved', 'closed')
    `);
    if (invalidStatuses.length > 0) {
      throw new Error(`CRITICAL: Found unknown status values: ${invalidStatuses.map(r => r.status).join(', ')}`);
    }

    console.log('  Expanding status ENUM to preserve legacy values...');
    await conn.query(`
      ALTER TABLE cycle_settlements 
      MODIFY COLUMN status ENUM('draft', 'pending', 'approved', 'closed') NOT NULL DEFAULT 'pending'
    `);

    // Phase 7 & 8: Reconcile check constraints exactly
    console.log('  Reconciling check constraints...');
    await dropConstraintIfExists(conn, 'cycle_settlements', 'chk_settlement_surplus_deficit');
    await dropConstraintIfExists(conn, 'cycle_settlements', 'chk_settlement_amounts');

    // Add intended constraints
    await conn.query(`
      ALTER TABLE cycle_settlements 
      ADD CONSTRAINT chk_settlement_amounts
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
             deficit >= 0)
    `);

    await conn.query(`
      ALTER TABLE cycle_settlements
      ADD CONSTRAINT chk_settlement_surplus_deficit
      CHECK ((surplus > 0 AND deficit = 0) OR
             (deficit > 0 AND surplus = 0) OR
             (surplus = 0 AND deficit = 0))
    `);

    console.log('Migration 020 applied successfully.');
  } catch (err) {
    console.error('Migration 020 failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
};

exports.down = async function() {
  const conn = await db.getConnection();
  try {
    console.log('Rolling back migration 020');

    await dropConstraintIfExists(conn, 'cycle_settlements', 'chk_settlement_amounts');
    await dropConstraintIfExists(conn, 'cycle_settlements', 'chk_settlement_surplus_deficit');

    // Restore legacy constraint
    await conn.query(`
      ALTER TABLE cycle_settlements
      ADD CONSTRAINT chk_settlement_surplus_deficit
      CHECK (surplus = 0 OR deficit = 0)
    `);

    // Revert status enum to legacy if safe? In a rollback, returning to 'draft','approved','closed' might fail if 'pending' rows exist.
    // It is generally not safe to drop columns without data loss, but we drop them in DOWN
    const hasTotalOutflows = await columnExists(conn, 'cycle_settlements', 'total_actual_outflows');
    if (hasTotalOutflows) {
      await conn.query(`ALTER TABLE cycle_settlements DROP COLUMN total_actual_outflows`);
    }

    const hasUpdatedAt = await columnExists(conn, 'cycle_settlements', 'updated_at');
    if (hasUpdatedAt) {
      await conn.query(`ALTER TABLE cycle_settlements DROP COLUMN updated_at`);
    }

    // Leave status enum expanded to prevent data loss on rollback
    console.log('Migration 020 rolled back successfully.');
  } catch (err) {
    console.error('Migration 020 rollback failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
};
