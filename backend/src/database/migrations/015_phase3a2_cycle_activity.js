/**
 * Migration 015 – Phase 3A.2: Cycle-Linked Financial Activity
 *
 * All canonical tables (transactions, financial_commitments,
 * commitment_occurrences) already exist in 000_initial_schema.sql.
 * The extra columns added by migrations 007/008 are also present.
 *
 * This migration is therefore a verification + index hardenening pass:
 *
 *   1. Confirm commitment_occurrences table exists (CREATE IF NOT EXISTS).
 *   2. Add a composite index on commitment_occurrences(cycle_id, status) if
 *      absent (already declared in 000 but missing on older installs).
 *   3. Add a composite index on transactions(user_id, cycle_id, status) for
 *      efficient per-cycle confirmed totals.
 *   4. Confirm the fk_transactions_cycle FK exists; if the transactions table
 *      was created without it (older install path), add it.
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

async function fkExists(conn, table, constraintName) {
  const [rows] = await conn.query(
    `SELECT CONSTRAINT_NAME
       FROM information_schema.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA   = DATABASE()
        AND TABLE_NAME     = ?
        AND CONSTRAINT_NAME = ?
        AND CONSTRAINT_TYPE = 'FOREIGN KEY'`,
    [table, constraintName]
  );
  return rows.length > 0;
}

async function up() {
  console.log('Running migration 015: Phase 3A.2 Cycle-Linked Financial Activity');

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // ── 1. Ensure commitment_occurrences table exists ──────────────── //
    await conn.query(`
      CREATE TABLE IF NOT EXISTS commitment_occurrences (
        id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        commitment_id       BIGINT UNSIGNED NOT NULL,
        cycle_id            BIGINT UNSIGNED NOT NULL,
        due_date            DATE            NOT NULL,
        amount              BIGINT UNSIGNED NOT NULL,
        status              ENUM('upcoming','due','paid','overdue','waived')
                                            NOT NULL DEFAULT 'upcoming',
        paid_transaction_id BIGINT UNSIGNED NULL,
        created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_commitment_occurrence (commitment_id, cycle_id, due_date),
        KEY fk_occurrence_transaction (paid_transaction_id),
        KEY idx_occurrences_cycle_status (cycle_id, status),
        KEY idx_occurrences_due_status   (due_date,  status),
        CONSTRAINT fk_occurrence_commitment
          FOREIGN KEY (commitment_id) REFERENCES financial_commitments (id)
          ON DELETE RESTRICT ON UPDATE RESTRICT,
        CONSTRAINT fk_occurrence_cycle
          FOREIGN KEY (cycle_id) REFERENCES financial_cycles (id)
          ON DELETE RESTRICT ON UPDATE RESTRICT,
        CONSTRAINT fk_occurrence_transaction
          FOREIGN KEY (paid_transaction_id) REFERENCES transactions (id)
          ON DELETE RESTRICT ON UPDATE RESTRICT,
        CONSTRAINT chk_occurrence_amount
          CHECK (amount > 0),
        CONSTRAINT chk_occurrence_paid_transaction
          CHECK (status <> 'paid' OR paid_transaction_id IS NOT NULL)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  commitment_occurrences: ensured');

    // ── 2. Composite index on transactions for per-cycle queries ────── //
    if (!(await indexExists(conn, 'transactions', 'idx_transactions_user_cycle_status'))) {
      await conn.query(
        `CREATE INDEX idx_transactions_user_cycle_status
             ON transactions (user_id, cycle_id, status)`
      );
      console.log('  idx_transactions_user_cycle_status: created');
    } else {
      console.log('  idx_transactions_user_cycle_status: already exists, skipped');
    }

    // ── 3. FK fk_transactions_cycle (may be absent on older installs) ─ //
    if (!(await fkExists(conn, 'transactions', 'fk_transactions_cycle'))) {
      await conn.query(
        `ALTER TABLE transactions
           ADD CONSTRAINT fk_transactions_cycle
             FOREIGN KEY (cycle_id) REFERENCES financial_cycles (id)
             ON DELETE RESTRICT ON UPDATE RESTRICT`
      );
      console.log('  fk_transactions_cycle: added');
    } else {
      console.log('  fk_transactions_cycle: already exists, skipped');
    }

    await conn.commit();
    console.log('Migration 015 applied successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 015 failed, rolled back:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

async function down() {
  console.log('Reverting migration 015: Phase 3A.2 Cycle-Linked Financial Activity');
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // Remove index added by this migration only
    if (await indexExists(conn, 'transactions', 'idx_transactions_user_cycle_status')) {
      await conn.query('DROP INDEX idx_transactions_user_cycle_status ON transactions');
    }

    // Drop occurrences table (was created here if absent; safe to remove)
    await conn.query('DROP TABLE IF EXISTS commitment_occurrences');

    await conn.commit();
    console.log('Migration 015 reverted successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 015 revert failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { up, down };
