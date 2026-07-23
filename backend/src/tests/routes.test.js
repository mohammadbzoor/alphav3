const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');

describe('Finance Routes Validation', () => {
  let token = '';

  beforeAll(async () => {
    // Generate valid token
    token = jwt.sign({ id: 1 }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });

    // We don't need a real user if we just mock the controller or see if it reaches the DB and throws a generic DB error or empty array.
    // If we have a user 1, it returns an empty array.
  });

  afterAll(async () => {
    await db.end();
  });

  test('GET /api/v1/goals/ready routes correctly', async () => {
    const res = await request(app)
      .get('/api/v1/goals/ready')
      .set('Authorization', `Bearer ${token}`);

    // It should hit getReadyGoals and return 200 with an array
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('POST /api/v1/goals creates a goal with canonical response and persists exactly one row', async () => {
    // 1. Create a real test user
    const [userRes] = await db.execute(
      `INSERT INTO users (full_name, email, password_hash) VALUES ('Route Test User', CONCAT(UUID(), '@example.com'), 'hash')`
    );
    const userId = userRes.insertId;
    const realToken = jwt.sign({ id: userId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });

    // 2. Count existing goals for this user (should be 0)
    const [preGoals] = await db.execute('SELECT COUNT(*) as count FROM goals WHERE user_id = ?', [userId]);
    expect(Number(preGoals[0].count)).toBe(0);

    // 3. Make the actual request
    const res = await request(app)
      .post('/api/v1/goals')
      .set('Authorization', `Bearer ${realToken}`)
      .send({
        goalType: 'laptop',
        targetAmount: 5000,
        planningMode: 'contribution_based',
        plannedContribution: 500,
        priority: 5
      });

    // 4. Assert the exact canonical response contract
    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toBe('Goal created successfully');
    expect(res.body.data).toBeDefined();
    expect(typeof res.body.data).toBe('object');
    expect(res.body.meta).toBeNull();
    
    const goalId = res.body.data.goalId;
    expect(goalId).toBeDefined();
    expect(Number.isInteger(goalId)).toBe(true);
    expect(goalId).toBeGreaterThan(0);

    // Ensure NO internal DB fields (like user_id, status, created_at) leaked into the response
    expect(Object.keys(res.body.data)).toHaveLength(1);
    expect(Object.keys(res.body.data)[0]).toBe('goalId');

    // 5. Verify database state
    const [postGoals] = await db.execute('SELECT * FROM goals WHERE user_id = ?', [userId]);
    
    // Exactly one row created
    expect(postGoals.length).toBe(1);
    
    // The ID matches the actual row ID
    expect(Number(postGoals[0].id)).toBe(Number(goalId));
    expect(Number(postGoals[0].target_amount)).toBe(5000);
    expect(Number(postGoals[0].planned_contribution)).toBe(500);
    expect(Number(postGoals[0].current_balance)).toBe(0);
    expect(Number(postGoals[0].cycle_allocation)).toBe(0);

    // Verify no transactions were created
    const [goalTxs] = await db.execute('SELECT * FROM goal_transactions WHERE goal_id = ?', [goalId]);
    expect(goalTxs.length).toBe(0);
    
    const [finTxs] = await db.execute('SELECT * FROM transactions WHERE user_id = ?', [userId]);
    expect(finTxs.length).toBe(0);
  });

  test('POST /api/v1/goals creates a deadline_based goal and persists distinct plannedContribution', async () => {
    const [userRes] = await db.execute(
      `INSERT INTO users (full_name, email, password_hash) VALUES ('Route Test User 2', CONCAT(UUID(), '@example.com'), 'hash')`
    );
    const userId = userRes.insertId;
    const realToken = jwt.sign({ id: userId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });

    const target = new Date();
    target.setFullYear(target.getFullYear() + 1);

    const res = await request(app)
      .post('/api/v1/goals')
      .set('Authorization', `Bearer ${realToken}`)
      .send({
        goalType: 'laptop',
        targetAmount: 8000,
        planningMode: 'deadline_based',
        targetDate: target.toISOString(),
        plannedContribution: 800,
        priority: 5
      });

    expect(res.status).toBe(201);
    const goalId = res.body.data.goalId;

    const [postGoals] = await db.execute('SELECT * FROM goals WHERE id = ?', [goalId]);
    expect(postGoals.length).toBe(1);
    
    expect(Number(postGoals[0].target_amount)).toBe(8000);
    expect(Number(postGoals[0].planned_contribution)).toBe(800);
    expect(Number(postGoals[0].current_balance)).toBe(0);
  });
});
