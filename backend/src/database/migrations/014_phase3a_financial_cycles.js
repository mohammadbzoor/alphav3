/**
 * Migration 014 – Phase 3A.1: Financial Cycles & Immutable Snapshots
 *
 * Goals:
 *   1. Ensure financial_cycles and cycle_allocation_snapshots exist (they are
 *      present in 000_initial_schema.sql for fresh installs; this migration
 *      hardens them for databases that were set up before the canonical schema
 *      was committed, and adds the idempotency_key column used for concurrent-
 *      creation protection).
 *   2. Add an idempotency_key column + unique index on financial_cycles so that
 *      simultaneous POST requests deduplicate at the DB level.
 *   3. Add a BEFORE UPDATE trigger that blocks any mutation to
 *      cycle_allocation_snapshots rows after insertion.
 *   4. Add a BEFORE DELETE trigger that blocks deletion of snapshot rows.
 *
 * Safe to run multiple times (all DDL is guarded with IF NOT EXISTS / IF
 * column does not already exist).
 */

const { db } = require('../../config/database');

async function columnExists(conn, table, column) {
  const [rows] = await conn.query(
    `SELECT COLUMN_NAME
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME   = ?
        AND COLUMN_NAME  = ?`,
    [table, column]
  );
  return rows.length > 0;
}

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

async function triggerExists(conn, triggerName) {
  const [rows] = await conn.query(
    `SELECT TRIGGER_NAME
       FROM information_schema.TRIGGERS
      WHERE TRIGGER_SCHEMA = DATABASE()
        AND TRIGGER_NAME   = ?`,
    [triggerName]
  );
  return rows.length > 0;
}

async function up() {
  console.log('Running migration 014: Phase 3A.1 Financial Cycles hardening');

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // ------------------------------------------------------------------ //
    // 1. Ensure financial_cycles table exists                             //
    // ------------------------------------------------------------------ //
    await conn.query(`
      CREATE TABLE IF NOT EXISTS financial_cycles (
        id                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        user_id               BIGINT UNSIGNED NOT NULL,
        start_date            DATETIME        NOT NULL,
        end_date              DATETIME        NOT NULL,
        status                ENUM('open','settlement_pending','closed')
                                              NOT NULL DEFAULT 'open',
        expected_income       BIGINT UNSIGNED NOT NULL DEFAULT 0,
        recorded_income       BIGINT UNSIGNED NOT NULL DEFAULT 0,
        unexpected_income     BIGINT UNSIGNED NOT NULL DEFAULT 0,
        policy_version        VARCHAR(30)     NOT NULL DEFAULT '1.0',
        created_at            TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
        settlement_started_at DATETIME        NULL,
        closed_at             DATETIME        NULL,
        open_user_id          BIGINT UNSIGNED GENERATED ALWAYS AS (
                                CASE WHEN status = 'open' THEN user_id ELSE NULL END
                              ) STORED,
        PRIMARY KEY (id),
        UNIQUE KEY uq_one_open_cycle_per_user (open_user_id),
        KEY idx_financial_cycles_user_status (user_id, status),
        KEY idx_financial_cycles_user_dates  (user_id, start_date, end_date),
        CONSTRAINT fk_cycles_user
          FOREIGN KEY (user_id) REFERENCES users (id)
          ON DELETE RESTRICT ON UPDATE RESTRICT,
        CONSTRAINT chk_cycles_dates
          CHECK (end_date > start_date)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  financial_cycles: ensured');

    // ------------------------------------------------------------------ //
    // 2. Add idempotency_key column to financial_cycles                   //
    //    Used to deduplicate concurrent POST /financial-cycles requests.  //
    // ------------------------------------------------------------------ //
    const hasIdempotencyKey = await columnExists(conn, 'financial_cycles', 'idempotency_key');
    if (!hasIdempotencyKey) {
      await conn.query(
        `ALTER TABLE financial_cycles
           ADD COLUMN idempotency_key VARCHAR(255) NULL
             AFTER policy_version`
      );
      console.log('  financial_cycles.idempotency_key: added');
    } else {
      console.log('  financial_cycles.idempotency_key: already exists, skipped');
    }

    // Unique index: one idempotency key per user (NULLs are excluded from
    // unique constraints in MySQL, so rows without a key are always allowed).
    const hasIdemIdx = await indexExists(conn, 'financial_cycles', 'uq_cycles_user_idempotency');
    if (!hasIdemIdx) {
      await conn.query(
        `CREATE UNIQUE INDEX uq_cycles_user_idempotency
             ON financial_cycles (user_id, idempotency_key)`
      );
      console.log('  uq_cycles_user_idempotency: created');
    } else {
      console.log('  uq_cycles_user_idempotency: already exists, skipped');
    }

    // ------------------------------------------------------------------ //
    // 3. Ensure cycle_allocation_snapshots table exists                   //
    // ------------------------------------------------------------------ //
    await conn.query(`
      CREATE TABLE IF NOT EXISTS cycle_allocation_snapshots (
        id                    BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
        cycle_id              BIGINT UNSIGNED  NOT NULL,
        allocation_base_income BIGINT UNSIGNED NOT NULL,
        tier_code             VARCHAR(50)      NULL,
        tier_label            VARCHAR(100)     NULL,
        allocation_source     ENUM('system_tier','user_adjusted','transition_plan')
                                               NOT NULL,
        needs_bps             SMALLINT UNSIGNED NOT NULL,
        wants_bps             SMALLINT UNSIGNED NOT NULL,
        savings_bps           SMALLINT UNSIGNED NOT NULL,
        needs_target          BIGINT UNSIGNED   NOT NULL DEFAULT 0,
        wants_target          BIGINT UNSIGNED   NOT NULL DEFAULT 0,
        savings_target        BIGINT UNSIGNED   NOT NULL DEFAULT 0,
        policy_version        VARCHAR(30)       NOT NULL,
        calculation_version   VARCHAR(30)       NOT NULL,
        created_at            TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_cycle_snapshot (cycle_id),
        CONSTRAINT fk_cycle_snapshot_cycle
          FOREIGN KEY (cycle_id) REFERENCES financial_cycles (id)
          ON DELETE RESTRICT ON UPDATE RESTRICT,
        CONSTRAINT chk_cycle_snapshot_bps
          CHECK (needs_bps <= 10000 AND wants_bps <= 10000 AND savings_bps <= 10000),
        CONSTRAINT chk_cycle_snapshot_bps_total
          CHECK (needs_bps + wants_bps + savings_bps = 10000),
        CONSTRAINT chk_cycle_snapshot_amount_total
          CHECK (needs_target + wants_target + savings_target = allocation_base_income)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  cycle_allocation_snapshots: ensured');

    // ------------------------------------------------------------------ //
    // 4. BEFORE UPDATE trigger – blocks snapshot mutation                 //
    // ------------------------------------------------------------------ //
    // Requires SUPER privilege or log_bin_trust_function_creators=ON.
    // If the DB user lacks that privilege we log a warning and rely solely
    // on application-layer enforcement (CycleRepository has no update/delete
    // methods for snapshots).
    if (!(await triggerExists(conn, 'trg_snapshot_no_update'))) {
      try {
        await conn.query(`
          CREATE TRIGGER trg_snapshot_no_update
          BEFORE UPDATE ON cycle_allocation_snapshots
          FOR EACH ROW
          BEGIN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'cycle_allocation_snapshots rows are immutable and cannot be updated';
          END
        `);
        console.log('  trg_snapshot_no_update: created');
      } catch (trigErr) {
        if (trigErr.code === 'ER_BINLOG_CREATE_ROUTINE_NEED_SUPER') {
          console.warn(
            '  trg_snapshot_no_update: SKIPPED – DB user lacks SUPER privilege. ' +
            'Immutability enforced at application layer only. ' +
            'Grant log_bin_trust_function_creators=ON or SUPER to add DB-level protection.'
          );
        } else {
          throw trigErr;
        }
      }
    } else {
      console.log('  trg_snapshot_no_update: already exists, skipped');
    }

    // ------------------------------------------------------------------ //
    // 5. BEFORE DELETE trigger – blocks snapshot deletion                 //
    // ------------------------------------------------------------------ //
    if (!(await triggerExists(conn, 'trg_snapshot_no_delete'))) {
      try {
        await conn.query(`
          CREATE TRIGGER trg_snapshot_no_delete
          BEFORE DELETE ON cycle_allocation_snapshots
          FOR EACH ROW
          BEGIN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'cycle_allocation_snapshots rows are immutable and cannot be deleted';
          END
        `);
        console.log('  trg_snapshot_no_delete: created');
      } catch (trigErr) {
        if (trigErr.code === 'ER_BINLOG_CREATE_ROUTINE_NEED_SUPER') {
          console.warn(
            '  trg_snapshot_no_delete: SKIPPED – DB user lacks SUPER privilege. ' +
            'Immutability enforced at application layer only.'
          );
        } else {
          throw trigErr;
        }
      }
    } else {
      console.log('  trg_snapshot_no_delete: already exists, skipped');
    }

    await conn.commit();
    console.log('Migration 014 applied successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 014 failed, rolled back:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

async function down() {
  console.log('Reverting migration 014: Phase 3A.1 Financial Cycles hardening');

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // Drop triggers first (they reference the tables)
    for (const t of ['trg_snapshot_no_update', 'trg_snapshot_no_delete']) {
      if (await triggerExists(conn, t)) {
        await conn.query(`DROP TRIGGER ${t}`);
        console.log(`  ${t}: dropped`);
      }
    }

    // Drop snapshot table (no other table references it in our scope)
    await conn.query('DROP TABLE IF EXISTS cycle_allocation_snapshots');
    console.log('  cycle_allocation_snapshots: dropped');

    // Drop idempotency index and column only (leave table intact for safety)
    if (await indexExists(conn, 'financial_cycles', 'uq_cycles_user_idempotency')) {
      await conn.query('DROP INDEX uq_cycles_user_idempotency ON financial_cycles');
    }
    if (await columnExists(conn, 'financial_cycles', 'idempotency_key')) {
      await conn.query('ALTER TABLE financial_cycles DROP COLUMN idempotency_key');
    }

    await conn.commit();
    console.log('Migration 014 reverted successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 014 revert failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { up, down };
