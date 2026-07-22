/**
 * Phase 3A.3 – Cycle Planning and Dashboard Integration
 *
 * Test matrix
 * ───────────
 * Integration (real DB, alpha_test)
 *   1.  POST /financial-cycles/:cycleId/goal-allocations – unique per cycle
 *   2.  POST /financial-cycles/:cycleId/goal-allocations – cross-user goal rejected
 *   3.  POST /financial-cycles/:cycleId/goal-allocations – no goal balance modification
 *   4.  POST /financial-cycles/:cycleId/goal-allocations – no ledger movement
 *   5.  POST /financial-cycles/:cycleId/savings-allocation – invariant enforced
 *   6.  POST /financial-cycles/:cycleId/savings-allocation – mismatch causes rollback
 *   7.  GET /dashboard/summary – uses snapshot targets
 *   8.  GET /dashboard/summary – uses confirmed actuals only
 *   9.  GET /dashboard/summary – includes commitment reserves
 *   10. GET /dashboard/summary – no-cycle setup state
 *   11. Phase 3A.1 regression – cycle creation still works
 *   12. Phase 3A.2 regression – transaction auto-linking still works
 */

'use strict';

process.env.NODE_ENV = 'test';

const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const { env } = require('../config/env');

// ─────────────────────────────────────────────────────────────────────────── //
// Helpers                                                                      //
// ─────────────────────────────────────────────────────────────────────────── //

function makeToken(userId) {
  const jwt = require('jsonwebtoken');
  return jwt.sign(
    { id: userId, email: `user${userId}@test.com` },
    env.jwtAccessSecret || 'secret',
    { expiresIn: '1h' }
  );
}

function authHeader(userId) {
  return `Bearer ${makeToken(userId)}`;
}

async function seedUser(conn, { income = 1000, paymentDay = 15 } = {}) {
  const [userRes] = await conn.execute(
    `INSERT INTO users (email, password_hash, full_name) VALUES (?, ?, ?)`,
    [`user${Date.now()}@test.com`, 'hash', 'Test User']
  );
  const userId = userRes.insertId;

  await conn.execute(
    `INSERT INTO financial_profiles (user_id, expected_monthly_income, payment_day, detected_tier, currency, timezone, onboarding_status) VALUES (?, ?, ?, 'Middle', 'JOD', 'Asia/Amman', 'completed')`,
    [userId, income, paymentDay]
  );

  await conn.execute(
    `INSERT INTO allocation_preferences (user_id, needs_bps, wants_bps, savings_bps, source, based_on_income) VALUES (?, 5000, 3000, 2000, 'system_tier', ?)`,
    [userId, income]
  );

  return userId;
}

async function createCycleForUser(userId) {
  const res = await request(app)
    .post('/api/v1/financial-cycles')
    .set('Authorization', authHeader(userId))
    .send({});
  return res.body.data.id;
}

async function createGoal(conn, userId, { amount = 500, name = 'Test Goal' } = {}) {
  const [res] = await conn.execute(
    `INSERT INTO goals (user_id, name, target_amount, current_balance, status, goal_type)
     VALUES (?, ?, ?, 0, 'active', 'savings')`,
    [userId, name, amount]
  );
  return res.insertId;
}

async function teardownUser(conn, userId) {
  if (!userId) return;
  await conn.execute(
    `DELETE co FROM commitment_occurrences co
       JOIN financial_commitments fc ON fc.id = co.commitment_id
      WHERE fc.user_id = ?`,
    [userId]
  );
  await conn.execute(
    `DELETE cas FROM cycle_allocation_snapshots cas
       JOIN financial_cycles fc ON fc.id = cas.cycle_id
      WHERE fc.user_id = ?`,
    [userId]
  );
  await conn.execute('DELETE FROM transactions WHERE user_id = ?', [userId]);
  // Handle new tables that may not exist in all test environments
  try {
    await conn.execute('DELETE FROM goal_cycle_allocations WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?)', [userId]);
  } catch (e) { /* Table may not exist */ }
  try {
    await conn.execute('DELETE FROM cycle_savings_allocations WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?)', [userId]);
  } catch (e) { /* Table may not exist */ }
  await conn.execute('DELETE FROM financial_cycles WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM financial_commitments WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM goals WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM allocation_preferences WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM financial_profiles WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM users WHERE id = ?', [userId]);
}

// ─────────────────────────────────────────────────────────────────────────── //
// Tests                                                                        //
// ─────────────────────────────────────────────────────────────────────────── //

describe('Phase 3A.3 – Cycle Planning and Dashboard Integration (integration)', () => {
  let conn;

  beforeAll(async () => {
    conn = await db.getConnection();
    // Ensure migration tables exist for test environment
    try {
      const { up } = require('../database/migrations/016_phase3a3_cycle_planning.js');
      await up();
    } catch (e) {
      // Migration may already be applied, ignore errors
    }
  });

  afterAll(async () => {
    conn.release();
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 1-4. Goal Cycle Allocations
  // ────────────────────────────────────────────────────────────────────── //
  describe('POST /financial-cycles/:cycleId/goal-allocations', () => {
    let userId;
    let cycleId;
    let goalId1;
    let goalId2;
    let goalId3;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycleForUser(userId);
      goalId1 = await createGoal(conn, userId, { amount: 500, name: 'Vacation' });
      goalId2 = await createGoal(conn, userId, { amount: 300, name: 'Emergency Fund' });
      goalId3 = await createGoal(conn, userId, { amount: 200, name: 'Car' });
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('creates unique goal allocation per cycle', async () => {
      const res = await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/goal-allocations`)
        .set('Authorization', authHeader(userId))
        .send({
          goalAllocations: [
            { goalId: goalId1, plannedAmount: 200, prioritySnapshot: 1 }
          ]
        })
        .expect(201);

      expect(res.body.success).toBe(true);

      // Verify allocation was created
      const [rows] = await conn.execute(
        `SELECT * FROM goal_cycle_allocations WHERE cycle_id = ? AND goal_id = ?`,
        [cycleId, goalId1]
      );
      expect(rows.length).toBe(1);
      expect(Number(rows[0].planned_amount)).toBe(200);
    });

    it('rejects duplicate goal allocation for same cycle', async () => {
      const res = await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/goal-allocations`)
        .set('Authorization', authHeader(userId))
        .send({
          goalAllocations: [
            { goalId: goalId1, plannedAmount: 300, prioritySnapshot: 1 }
          ]
        })
        .expect(409); // Unique constraint violation
    });

    it('rejects cross-user goal', async () => {
      const otherUser = await seedUser(conn, { income: 800, paymentDay: 10 });
      const otherGoal = await createGoal(conn, otherUser, { amount: 300, name: 'Other Goal' });

      const res = await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/goal-allocations`)
        .set('Authorization', authHeader(userId))
        .send({
          goalAllocations: [
            { goalId: otherGoal, plannedAmount: 100, prioritySnapshot: 1 }
          ]
        })
        .expect(404);

      expect(res.body.code).toBe('GOAL_NOT_FOUND_OR_INELIGIBLE');

      await teardownUser(conn, otherUser);
    });

    it('does not modify goal balance', async () => {
      const [before] = await conn.execute(
        `SELECT current_balance FROM goals WHERE id = ?`,
        [goalId2]
      );
      const beforeBalance = Number(before[0].current_balance);

      await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/goal-allocations`)
        .set('Authorization', authHeader(userId))
        .send({
          goalAllocations: [
            { goalId: goalId2, plannedAmount: 250, prioritySnapshot: 1 }
          ]
        })
        .expect(201);

      const [after] = await conn.execute(
        `SELECT current_balance FROM goals WHERE id = ?`,
        [goalId2]
      );
      const afterBalance = Number(after[0].current_balance);

      expect(afterBalance).toBe(beforeBalance);
    });

    it('does not create ledger movement', async () => {
      const [before] = await conn.execute(
        `SELECT COUNT(*) as count FROM goal_transactions WHERE goal_id = ?`,
        [goalId3]
      );
      const beforeCount = Number(before[0].count);

      await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/goal-allocations`)
        .set('Authorization', authHeader(userId))
        .send({
          goalAllocations: [
            { goalId: goalId3, plannedAmount: 150, prioritySnapshot: 1 }
          ]
        })
        .expect(201);

      const [after] = await conn.execute(
        `SELECT COUNT(*) as count FROM goal_transactions WHERE goal_id = ?`,
        [goalId3]
      );
      const afterCount = Number(after[0].count);

      expect(afterCount).toBe(beforeCount);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 5-6. Cycle Savings Allocation
  // ────────────────────────────────────────────────────────────────────── //
  describe('POST /financial-cycles/:cycleId/savings-allocation', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycleForUser(userId);
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('enforces savings invariant', async () => {
      const savingsAmount = 200;
      const emergencyFundAmount = 50;
      const totalGoalAllocations = 0;
      const unallocatedSavingsAmount = 150;
      // 50 + 0 + 150 = 200 ✓

      const res = await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/savings-allocation`)
        .set('Authorization', authHeader(userId))
        .send({
          savingsAmount,
          emergencyFundAmount,
          emergencyFundRate: 10.0,
          totalGoalAllocations,
          unallocatedSavingsAmount
        })
        .expect(201);

      expect(res.body.success).toBe(true);
    });

    it('rejects invariant violation with complete rollback', async () => {
      // Clean up any existing allocation from previous test
      await conn.execute('DELETE FROM cycle_savings_allocations WHERE cycle_id = ?', [cycleId]);

      const savingsAmount = 200;
      const emergencyFundAmount = 50;
      const totalGoalAllocations = 0;
      // 50 + 0 + 100 = 150 !== 200 (violates invariant)

      const res = await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/savings-allocation`)
        .set('Authorization', authHeader(userId))
        .send({
          savingsAmount,
          emergencyFundAmount,
          emergencyFundRate: 10.0,
          totalGoalAllocations,
          unallocatedSavingsAmount: 100 // Deliberate mismatch
        })
        .expect(422);

      expect(res.body.code).toBe('SAVINGS_INVARIANT_VIOLATION');

      // Verify no allocation was created
      const [rows] = await conn.execute(
        `SELECT * FROM cycle_savings_allocations WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(rows.length).toBe(0);
    });

    it('rejects allocation when totalGoalAllocations mismatches actual planned allocations', async () => {
      // 1. Create a goal and a goal_cycle_allocation for this cycle
      const tempGoalId = await createGoal(conn, userId, { amount: 500, name: 'Temp Goal' });
      await conn.execute(
        `INSERT INTO goal_cycle_allocations (cycle_id, goal_id, planned_amount, priority_snapshot)
         VALUES (?, ?, 100, 1)`,
        [cycleId, tempGoalId]
      );

      const savingsAmount = 300;
      const emergencyFundAmount = 50;
      const totalGoalAllocations = 0; // Deliberate mismatch with 100
      const unallocatedSavingsAmount = 150;

      const res = await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/savings-allocation`)
        .set('Authorization', authHeader(userId))
        .send({
          savingsAmount,
          emergencyFundAmount,
          emergencyFundRate: 10.0,
          totalGoalAllocations,
          unallocatedSavingsAmount
        })
        .expect(422);

      expect(res.body.code).toBe('GOAL_ALLOCATION_TOTAL_MISMATCH');
    });

    it('creates savings allocation successfully when all amounts match invariants', async () => {
      // Use existing cycleId (already has 100 planned_amount from previous test)
      // Add another 100, bringing actual total to 200
      const goalId = await createGoal(conn, userId, { amount: 1000, name: 'Valid Goal' });
      await conn.execute(
        `INSERT INTO goal_cycle_allocations (cycle_id, goal_id, planned_amount, priority_snapshot)
         VALUES (?, ?, 100, 1)`,
        [cycleId, goalId]
      );

      const savingsAmount = 400; // 50 (emergency) + 200 (goals) + 150 (unallocated)
      const emergencyFundAmount = 50;
      const totalGoalAllocations = 200; // Matches the actual allocation (100 + 100)
      const unallocatedSavingsAmount = 150;

      const res = await request(app)
        .post(`/api/v1/financial-cycles/${cycleId}/savings-allocation`)
        .set('Authorization', authHeader(userId))
        .send({
          savingsAmount,
          emergencyFundAmount,
          emergencyFundRate: 12.5, // 50 / 400
          totalGoalAllocations,
          unallocatedSavingsAmount
        })
        .expect(201);

      expect(res.body.success).toBe(true);
      
      const [rows] = await conn.execute(
        `SELECT * FROM cycle_savings_allocations WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(rows.length).toBe(1);
      expect(Number(rows[0].emergency_fund_amount)).toBe(50);
      expect(Number(rows[0].total_goal_allocations)).toBe(200);
      expect(Number(rows[0].unallocated_savings_amount)).toBe(150);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 7-10. Dashboard
  // ────────────────────────────────────────────────────────────────────── //
  describe('GET /dashboard/summary', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycleForUser(userId);
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('uses snapshot targets from cycle allocation', async () => {
      const res = await request(app)
        .get('/api/v1/dashboard/summary')
        .set('Authorization', authHeader(userId))
        .expect(200);

      expect(res.body.data.setupRequired).toBe(false);
      expect(res.body.data.cycle.id).toBe(cycleId);
      // Snapshot targets should be non-zero (5000, 3000, 2000 BPS of 1000 income)
      expect(res.body.data.buckets.needs.target).toBeGreaterThan(0);
      expect(res.body.data.buckets.wants.target).toBeGreaterThan(0);
      expect(res.body.data.buckets.savings.target).toBeGreaterThan(0);
    });

    it('uses confirmed transactions only', async () => {
      // Create pending expense
      await conn.execute(
        `INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, category, status, occurred_at, confirmed_at)
         VALUES (?, ?, 100, 'outflow', 'expense', 'needs', 'rent', 'pending', NOW(), NULL)`,
        [userId, cycleId]
      );

      const res = await request(app)
        .get('/api/v1/dashboard/summary')
        .set('Authorization', authHeader(userId))
        .expect(200);

      // Pending expense should not be counted
      expect(res.body.data.buckets.needs.actual).toBe(0);
    });

    it('includes commitment reserves', async () => {
      // Create a commitment and occurrence
      const [commitment] = await conn.execute(
        `INSERT INTO financial_commitments (user_id, name, amount, frequency, status, budget_bucket)
         VALUES (?, 'Rent', 500, 'monthly', 'active', 'needs')`,
        [userId]
      );

      await conn.execute(
        `INSERT INTO commitment_occurrences (commitment_id, cycle_id, due_date, amount, status)
         VALUES (?, ?, CURDATE() + INTERVAL 7 DAY, 500, 'upcoming')`,
        [commitment.insertId, cycleId]
      );

      const res = await request(app)
        .get('/api/v1/dashboard/summary')
        .set('Authorization', authHeader(userId))
        .expect(200);

      expect(res.body.data.commitments.totalReserved).toBe(500);
    });

    it('returns setup state when no open cycle', async () => {
      await conn.execute(
        `UPDATE financial_cycles SET status = 'closed' WHERE id = ?`,
        [cycleId]
      );

      const res = await request(app)
        .get('/api/v1/dashboard/summary')
        .set('Authorization', authHeader(userId))
        .expect(200);

      expect(res.body.data.setupRequired).toBe(true);
      expect(res.body.data.reliability).toBe('unavailable');
      expect(res.body.data.warnings).toContain('NO_ACTIVE_FINANCIAL_CYCLE');
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 11-12. Regression Tests
  // ────────────────────────────────────────────────────────────────────── //
  describe('Phase 3A.1 regression – cycle creation', () => {
    let userId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('creates cycle with snapshot', async () => {
      const res = await request(app)
        .post('/api/v1/financial-cycles')
        .set('Authorization', authHeader(userId))
        .send({})
        .expect(201);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBeDefined();

      const [rows] = await conn.execute(
        `SELECT * FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
        [res.body.data.id]
      );
      expect(rows.length).toBe(1);
    });

    it('one open cycle per user', async () => {
      const res = await request(app)
        .post('/api/v1/financial-cycles')
        .set('Authorization', authHeader(userId))
        .send({})
        .expect(409);

      expect(res.body.code).toBe('CYCLE_ALREADY_OPEN');
    });
  });

  describe('Phase 3A.2 regression – transaction auto-linking', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycleForUser(userId);
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('auto-links expense to open cycle', async () => {
      const res = await request(app)
        .post('/api/v1/expenses')
        .set('Authorization', authHeader(userId))
        .send({
          amount: 50,
          bucket: 'needs',
          category: 'rent'
        })
        .expect(201);

      const [rows] = await conn.execute(
        `SELECT cycle_id FROM transactions WHERE id = ?`,
        [res.body.data.id]
      );
      expect(Number(rows[0].cycle_id)).toBe(cycleId);
    });

    it('returns NO_ACTIVE_FINANCIAL_CYCLE when no open cycle', async () => {
      await conn.execute(
        `UPDATE financial_cycles SET status = 'closed' WHERE id = ?`,
        [cycleId]
      );

      const res = await request(app)
        .post('/api/v1/expenses')
        .set('Authorization', authHeader(userId))
        .send({
          amount: 50,
          bucket: 'needs',
          category: 'rent'
        })
        .expect(422);

      expect(res.body.code).toBe('NO_ACTIVE_FINANCIAL_CYCLE');
    });
  });
});
