const { db } = require('../config/database');
const { up, down } = require('../database/migrations/020_reconcile_cycle_settlements_schema');
const { env } = require('../config/env');

describe('Migration 020: Settlement Schema Reconciliation', () => {
  let testUserId = null;
  let testCycleId = null;

  beforeAll(async () => {
    if (!env.dbName.endsWith('_test')) {
      throw new Error('Refusing to run tests outside of test DB');
    }
    const [userRes] = await db.execute('INSERT INTO users (full_name, email, password_hash, created_at) VALUES ("Test Migr020", "migr020_' + Date.now() + '@example.com", "hash", NOW())');
    testUserId = userRes.insertId;
  });

  afterAll(async () => {
    if (env.dbName.endsWith('_test')) {
      await db.execute('DELETE FROM transactions WHERE user_id = ?', [testUserId]);
      await db.execute('DELETE FROM cycle_settlements WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?)', [testUserId]);
      await db.execute('DELETE FROM financial_cycles WHERE user_id = ?', [testUserId]);
      await db.execute('DELETE FROM users WHERE id = ?', [testUserId]);
    }
    await db.end();
  });

  beforeEach(async () => {
    if (env.dbName.endsWith('_test')) {
      // Clear data for this user
      await db.execute('DELETE FROM transactions WHERE user_id = ?', [testUserId]);
      await db.execute('DELETE FROM cycle_settlements WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?)', [testUserId]);
      await db.execute('DELETE FROM financial_cycles WHERE user_id = ?', [testUserId]);
      
      const [cycleRes] = await db.execute('INSERT INTO financial_cycles (user_id, start_date, end_date, expected_income) VALUES (?, NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY), 1000)', [testUserId]);
      testCycleId = cycleRes.insertId;
    }
  });

  test('Migration handles empty table safely', async () => {
    await up();
    // Verify columns exist
    const [cols] = await db.execute('SHOW COLUMNS FROM cycle_settlements LIKE "total_actual_outflows"');
    expect(cols.length).toBe(1);
    expect(cols[0].Null).toBe('NO');
  });

  test('Migration preserves existing statuses and backfills outflows', async () => {
    // We must ensure the schema is in legacy state before inserting
    await down();

    // Insert legacy row
    await db.execute(`
      INSERT INTO cycle_settlements (cycle_id, expected_income, status)
      VALUES (?, 1000, 'draft')
    `, [testCycleId]);

    // Insert some transactions
    await db.execute(`
      INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, status, occurred_at, confirmed_at)
      VALUES (?, ?, 100, 'outflow', 'expense', 'confirmed', NOW(), NOW())
    `, [testUserId, testCycleId]);

    await db.execute(`
      INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, status, occurred_at, confirmed_at)
      VALUES (?, ?, 200, 'outflow', 'saving', 'confirmed', NOW(), NOW())
    `, [testUserId, testCycleId]);

    // Run migration
    await up();

    const [rows] = await db.execute('SELECT total_actual_outflows, status FROM cycle_settlements WHERE cycle_id = ?', [testCycleId]);
    expect(rows[0].status).toBe('draft');
    expect(parseFloat(rows[0].total_actual_outflows)).toBe(300);
  });

  test('Migration rejects unknown status values', async () => {
    await down();
    await db.execute(`ALTER TABLE cycle_settlements MODIFY COLUMN status VARCHAR(20)`);
    await db.execute(`INSERT INTO cycle_settlements (cycle_id, expected_income, status) VALUES (?, 1000, 'unknown')`, [testCycleId]);
    
    await expect(up()).rejects.toThrow(/unknown/);
    
    // Cleanup
    await db.execute(`DELETE FROM cycle_settlements WHERE cycle_id = ?`, [testCycleId]);
  });

  test('Migration is resumable (partially applied)', async () => {
    await down();
    // Partially apply by adding total_actual_outflows manually as nullable
    await db.execute(`ALTER TABLE cycle_settlements ADD COLUMN total_actual_outflows BIGINT UNSIGNED NULL AFTER actual_savings`);
    
    await db.execute(`INSERT INTO cycle_settlements (cycle_id, expected_income, status, total_actual_outflows) VALUES (?, 1000, 'draft', NULL)`, [testCycleId]);

    // Run migration, should not fail on ADD COLUMN and should complete
    await up();

    const [cols] = await db.execute('SHOW COLUMNS FROM cycle_settlements LIKE "total_actual_outflows"');
    expect(cols[0].Null).toBe('NO');
  });

  test('Migration creates intended check constraints', async () => {
    await up();

    // Check constraints via information_schema
    const [rows] = await db.execute(`
      SELECT CONSTRAINT_NAME FROM information_schema.table_constraints
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cycle_settlements' AND CONSTRAINT_TYPE = 'CHECK'
    `);
    const constraints = rows.map(r => r.CONSTRAINT_NAME);
    expect(constraints).toContain('chk_settlement_amounts');
    expect(constraints).toContain('chk_settlement_surplus_deficit');
  });

  test('Second official migration run is a no-op', async () => {
    await up(); // First run
    await expect(up()).resolves.not.toThrow(); // Second run
  });

});
