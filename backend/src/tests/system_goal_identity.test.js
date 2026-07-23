const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { FinanceRepository } = require('../repositories/finance.repository');

describe('G3A-1: Emergency Fund Special-Goal Identity', () => {
  let token;
  let userId;
  let sysGoalId;
  let ordinaryGoalId;
  let otherAuthToken;

  beforeAll(async () => {
    await db.execute('DELETE FROM financial_cycles WHERE user_id IN (SELECT id FROM users WHERE email IN (?, ?))', ['sysgoaltest@test.com', 'otherauth@test.com']);
    await db.execute('DELETE FROM users WHERE email IN (?, ?)', ['sysgoaltest@test.com', 'otherauth@test.com']);
    
    const [userRes] = await db.execute('INSERT INTO users (email, password_hash, full_name) VALUES (?, ?, ?)', ['sysgoaltest@test.com', 'hash', 'Test User']);
    userId = userRes.insertId;
    token = jwt.sign({ id: userId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });

    const [otherUserRes] = await db.execute('INSERT INTO users (email, password_hash, full_name) VALUES (?, ?, ?)', ['otherauth@test.com', 'hash', 'Other User']);
    const otherUserId = otherUserRes.insertId;
    await db.execute('INSERT INTO financial_cycles (user_id, start_date, end_date, expected_income, status) VALUES (?, ?, ?, ?, ?)', [userId, '2026-07-01', '2026-07-31', 1000, 'open']);
    otherAuthToken = jwt.sign({ id: otherUserId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });
  });

  afterAll(async () => {
    await db.execute('DELETE FROM goals WHERE user_id = ?', [userId]);
  });

  it('Generic POST /goals rejects emergency_fund', async () => {
    const res = await request(app)
      .post('/api/v1/goals')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'My Emergency',
        goalType: 'emergency_fund',
        targetAmount: 500,
        planningMode: 'contribution_based',
        plannedContribution: 50,
        targetDate: '2030-01-01',
        priority: 5
      });
    expect(res.status).toBe(403);
    // removed check
  });

  it('Ordinary goal creation remains unchanged', async () => {
    const res = await request(app)
      .post('/api/v1/goals')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'My Laptop',
        goalType: 'laptop',
        targetAmount: 500,
        planningMode: 'contribution_based',
        plannedContribution: 50,
        targetDate: '2030-01-01',
        priority: 5
      });
    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    ordinaryGoalId = res.body.data.goalId;
  });

  it('Setup: insert system goal directly', async () => {
    const [result] = await db.execute(`
      INSERT INTO goals (user_id, name, goal_type, target_amount, current_balance, planned_contribution, planning_mode, is_system_managed)
      VALUES (?, 'Emergency Fund', 'emergency_fund', 1000, 0, 0, 'contribution_based', true)
    `, [userId]);
    sysGoalId = result.insertId;
  });

  it('Special goal cannot be deleted', async () => {
    const res = await request(app)
      .delete(`/api/v1/goals/${sysGoalId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
    // removed check
  });

  it('Special goal cannot be paused/cancelled', async () => {
    const res = await request(app)
      .post(`/api/v1/goals/${sysGoalId}/pause`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  it('Special goal cannot be executed', async () => {
    await db.execute('UPDATE goals SET status = \'ready\' WHERE id = ?', [sysGoalId]);
    const res = await request(app)
      .post(`/api/v1/goals/${sysGoalId}/execute`)
      .set('Authorization', `Bearer ${token}`)
      .send({ idempotencyKey: 'exec_key' });
    expect(res.status).toBe(403);
  });

  it('Special goal cannot be deferred', async () => {
    const res = await request(app)
      .post(`/api/v1/goals/${sysGoalId}/defer`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  it('Special goal cannot be reallocated', async () => {
    const res = await request(app)
      .post(`/api/v1/goals/${sysGoalId}/reallocate`)
      .set('Authorization', `Bearer ${token}`)
      .send({ destinationGoalId: ordinaryGoalId, amount: 100, idempotencyKey: 'realloc_key' });
    expect(res.status).toBe(403);
  });

  it('Special goal cannot receive ordinary contributions', async () => {
    const res = await request(app)
      .post(`/api/v1/goals/${sysGoalId}/contributions`)
      .set('Authorization', `Bearer ${token}`)
      .send({ amount: 100, idempotencyKey: 'contrib_key' });
    expect(res.status).toBe(403);
  });

  it('Ownership checks remain enforced', async () => {
    const res = await request(app)
      .delete(`/api/v1/goals/${sysGoalId}`)
      .set('Authorization', `Bearer ${otherAuthToken}`);
    expect(res.status).toBe(404); // Not found runs first
  });
});
