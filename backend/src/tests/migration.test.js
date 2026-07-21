const { db } = require('../config/database');
const { up, down } = require('../database/migrations/009_phase1_goal_ledger');
const { env } = require('../config/env');

describe('Migration 009: Phase 1 Goal Ledger Idempotency & Balances', () => {
  let testUserId = null;

  beforeAll(async () => {
    // Setup test user
    const [userRes] = await db.execute('INSERT INTO users (full_name, email, password_hash, created_at) VALUES ("Test Migr", "migr_' + Date.now() + '@example.com", "hash", NOW())');
    testUserId = userRes.insertId;
  });

  afterAll(async () => {
    if (env.dbName.endsWith('_test')) {
      await db.execute('DELETE FROM goal_transactions WHERE user_id = ?', [testUserId]);
      await db.execute('DELETE FROM goals WHERE user_id = ?', [testUserId]);
      await db.execute('DELETE FROM users WHERE id = ?', [testUserId]);
    }
    await db.end();
  });

  beforeEach(async () => {
    if (env.dbName.endsWith('_test')) {
      try { await db.execute('DELETE FROM goal_transactions WHERE user_id = ?', [testUserId]); } catch(e) {}
      try { await db.execute('DELETE FROM goals WHERE user_id = ?', [testUserId]); } catch(e) {}
    }
  });

  test('Migration creates exactly one opening adjustment for balance > 0', async () => {
    // Insert a legacy goal with balance > 0
    const [goalRes] = await db.execute(`
      INSERT INTO goals (user_id, name, target_amount, current_balance, status, planning_mode, cycle_allocation, goal_type)
      VALUES (?, 'Legacy Goal 1', 1000, 300, 'active', 'contribution_based', 0, 'short_term')
    `, [testUserId]);

    // Run migration
    await up();

    const [txRows] = await db.execute('SELECT * FROM goal_transactions WHERE goal_id = ? AND transaction_type = "adjustment"', [goalRes.insertId]);

    expect(txRows.length).toBe(1);
    expect(parseFloat(txRows[0].amount)).toBe(300);
    expect(txRows[0].idempotency_key).toBe(`phase1-opening-balance:${goalRes.insertId}`);
  });

  test('Migration creates no adjustments for zero balance', async () => {
    const [goalRes] = await db.execute(`
      INSERT INTO goals (user_id, name, target_amount, current_balance, status, planning_mode, cycle_allocation, goal_type)
      VALUES (?, 'Legacy Goal 2', 1000, 0, 'active', 'contribution_based', 0, 'short_term')
    `, [testUserId]);

    await up();

    const [txRows] = await db.execute('SELECT * FROM goal_transactions WHERE goal_id = ?', [goalRes.insertId]);
    expect(txRows.length).toBe(0);
  });

  test('Migration maps completed goals to ready but not executed', async () => {
    const [goalRes] = await db.execute(`
      INSERT INTO goals (user_id, name, target_amount, current_balance, status, planning_mode, cycle_allocation, goal_type)
      VALUES (?, 'Completed Goal', 1000, 1000, 'active', 'contribution_based', 0, 'short_term')
    `, [testUserId]);

    await up();

    const [rows] = await db.execute('SELECT status, ready_at FROM goals WHERE id = ?', [goalRes.insertId]);
    expect(rows[0].status).toBe('ready');
    expect(rows[0].ready_at).not.toBeNull();
  });

  test('Migration respects idempotency on rerun', async () => {
    const [goalRes] = await db.execute(`
      INSERT INTO goals (user_id, name, target_amount, current_balance, status, planning_mode, cycle_allocation, goal_type)
      VALUES (?, 'Idemp Goal', 1000, 500, 'active', 'contribution_based', 0, 'short_term')
    `, [testUserId]);

    // Run twice
    await up();
    await up();

    const [txRows] = await db.execute('SELECT * FROM goal_transactions WHERE goal_id = ? AND transaction_type = "adjustment"', [goalRes.insertId]);
    expect(txRows.length).toBe(1);
  });
});
