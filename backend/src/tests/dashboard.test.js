const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const { env } = require('../config/env');
const jwt = require('jsonwebtoken');

describe('Dashboard API', () => {
  let userToken;
  let userId;
  let authHeader;
  let dbConnection;

  beforeAll(async () => {
    if (!env.dbName.endsWith('_test')) {
      throw new Error('Tests must run against a test database');
    }
    dbConnection = await db.getConnection();

    // Create user
    const email = `dashboard${Date.now()}@test.com`;
    const [userRes] = await dbConnection.execute(
      'INSERT INTO users (full_name, email, password_hash, account_status) VALUES (?, ?, ?, ?)',
      ['Dash User', email, 'hash', 'active']
    );
    userId = userRes.insertId;

    const [profileRes] = await dbConnection.execute(
      'INSERT INTO financial_profiles (user_id, expected_monthly_income, currency, timezone, onboarding_status) VALUES (?, ?, ?, ?, ?)',
      [userId, 1000, 'JOD', 'Asia/Amman', 'completed']
    );

    userToken = jwt.sign({ id: userId, email }, env.jwtAccessSecret || 'secret');
    authHeader = { 'Authorization': `Bearer ${userToken}` };
  });

  afterAll(async () => {
    await dbConnection.execute('DELETE FROM cycle_allocation_snapshots WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?)', [userId]);
    await dbConnection.execute('DELETE FROM transactions WHERE user_id = ?', [userId]);
    await dbConnection.execute('DELETE FROM financial_cycles WHERE user_id = ?', [userId]);
    await dbConnection.execute('DELETE FROM financial_profiles WHERE user_id = ?', [userId]);
    await dbConnection.execute('DELETE FROM users WHERE id = ?', [userId]);
    dbConnection.release();
  });

  it('should return setupRequired when no active cycle exists', async () => {
    const res = await request(app).get('/api/v1/dashboard/summary').set(authHeader);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.setupRequired).toBe(true);
    expect(res.body.data.warnings).toContain('NO_ACTIVE_FINANCIAL_CYCLE');
  });

  it('should return valid dashboard summary when active cycle exists', async () => {
    const now = new Date();
    const end = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000); // 7 days from now
    
    // Convert to MySQL datetime string
    const formatDateTime = (date) => date.toISOString().slice(0, 19).replace('T', ' ');
    
    const [cycleRes] = await dbConnection.execute(
      `INSERT INTO financial_cycles (user_id, start_date, end_date, status, expected_income) 
       VALUES (?, ?, ?, 'open', ?)`,
      [userId, formatDateTime(now), formatDateTime(end), 1000]
    );
    const cycleId = cycleRes.insertId;

    // Create snapshots
    await dbConnection.execute(
      `INSERT INTO cycle_allocation_snapshots 
       (cycle_id, allocation_base_income, allocation_source, needs_bps, wants_bps, savings_bps, needs_target, wants_target, savings_target, policy_version, calculation_version)
       VALUES (?, ?, 'system_tier', 5000, 3000, 2000, 500, 300, 200, '1.0', '1.0')`,
      [cycleId, 1000]
    );

    // Create some transactions
    await dbConnection.execute(
      `INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, status, occurred_at, confirmed_at)
       VALUES (?, ?, ?, 'outflow', 'expense', 'needs', 'confirmed', ?, ?)`,
      [userId, cycleId, 100, formatDateTime(now), formatDateTime(now)]
    );

    const res = await request(app).get('/api/v1/dashboard/summary').set(authHeader);
    expect(res.status).toBe(200);
    expect(res.body.data.setupRequired).toBe(false);
    expect(res.body.data.cycle.status).toBe('open');
    expect(res.body.data.buckets.needs.target).toBe(500);
    expect(res.body.data.buckets.needs.actual).toBe(100);
    expect(res.body.data.buckets.needs.remaining).toBe(400);
  });
});
