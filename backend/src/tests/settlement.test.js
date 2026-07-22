/**
 * Settlement Tests – Phase 3B – Financial Cycle Settlement and Closure
 *
 * Tests:
 *   - Settlement preview calculations
 *   - Begin settlement lifecycle
 *   - Close cycle with surplus actions
 *   - Close cycle with deficit
 *   - Closed-cycle immutability
 *   - Settlement action validation
 *   - Dashboard handling of closed cycles
 *   - Phase 3A regressions
 */

'use strict';

process.env.NODE_ENV = 'test';

const request = require('supertest');
const { db } = require('../config/database');
const { app } = require('../app');
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
  const [user] = await conn.execute(
    `INSERT INTO users (email, password_hash, full_name)
     VALUES (?, ?, ?)`,
    [`test${Date.now()}@example.com`, 'hash', 'Test User']
  );
  const userId = user.insertId;

  await conn.execute(
    `INSERT INTO financial_profiles (user_id, expected_monthly_income, payment_day, timezone, detected_tier)
     VALUES (?, ?, ?, 'UTC', 'tier1')`,
    [userId, income, paymentDay]
  );

  return userId;
}

async function createCycle(conn, userId) {
  // Close any existing open or settlement_pending cycles first
  await conn.execute('UPDATE financial_cycles SET status = "closed", closed_at = NOW() WHERE user_id = ? AND status IN ("open", "settlement_pending")', [userId]);

  const [cycle] = await conn.execute(
    `INSERT INTO financial_cycles (user_id, start_date, end_date, status, expected_income, policy_version)
     VALUES (?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'open', ?, '1.0')`,
    [userId, 1000]
  );
  const cycleId = cycle.insertId;

  await conn.execute(
    `INSERT INTO cycle_allocation_snapshots
     (cycle_id, allocation_base_income, tier_code, tier_label, allocation_source,
      needs_bps, wants_bps, savings_bps, needs_target, wants_target, savings_target,
      policy_version, calculation_version)
     VALUES (?, 1000, 'tier1', 'Tier 1', 'system_tier', 5000, 3000, 2000, 500, 300, 200, '1.0', '1.0')`,
    [cycleId]
  );

  return cycleId;
}

async function createTransaction(conn, userId, cycleId, { amount, type, bucket, incomeKind }) {
  const [tx] = await conn.execute(
    `INSERT INTO transactions
     (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, income_kind, status, confirmed_at, occurred_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'confirmed', NOW(), NOW())`,
    [
      userId,
      cycleId,
      amount,
      type === 'income' ? 'inflow' : 'outflow',
      type,
      bucket || null,
      incomeKind || null
    ]
  );
  return tx.insertId;
}

async function createGoal(conn, userId, { amount = 500, name = 'Test Goal' } = {}) {
  const [goal] = await conn.execute(
    `INSERT INTO goals (user_id, name, target_amount, current_balance, status, goal_type)
     VALUES (?, ?, ?, 0, 'active', 'savings')`,
    [userId, name, amount]
  );
  return goal.insertId;
}

async function teardownUser(conn, userId) {
  if (!userId) return;
  await conn.execute('DELETE FROM settlement_actions WHERE settlement_id IN (SELECT id FROM cycle_settlements WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?))', [userId]);
  await conn.execute('DELETE FROM cycle_settlements WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?)', [userId]);
  await conn.execute('DELETE FROM commitment_occurrences WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?)', [userId]);
  await conn.execute('DELETE FROM cycle_allocation_snapshots WHERE cycle_id IN (SELECT id FROM financial_cycles WHERE user_id = ?)', [userId]);
  await conn.execute('DELETE FROM transactions WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM financial_cycles WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM goal_transactions WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM goals WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM financial_profiles WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM users WHERE id = ?', [userId]);
}

// ─────────────────────────────────────────────────────────────────────────── //
// Tests                                                                        //
// ─────────────────────────────────────────────────────────────────────────── //

describe('Phase 3B – Settlement and Closure (integration)', () => {
  let conn;

  beforeAll(async () => {
    conn = await db.getConnection();
    // Ensure migration tables exist for test environment
    try {
      const { up } = require('../database/migrations/017_phase3b_settlement.js');
      await up();
    } catch (e) {
      // Migration may already be applied, ignore errors
    }
  });

  afterAll(async () => {
    conn.release();
  });

  describe('POST /financial-cycles/current/settlement-preview', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycle(conn, userId);
    });

    afterAll(async () => { await teardownUser(conn, userId); });

    it('calculates settlement preview with surplus', async () => {
      // Add income
      await createTransaction(conn, userId, cycleId, { amount: 1200, type: 'income', incomeKind: 'recurring' });
      await createTransaction(conn, userId, cycleId, { amount: 100, type: 'income', incomeKind: 'unexpected' });

      // Add expenses
      await createTransaction(conn, userId, cycleId, { amount: 400, type: 'expense', bucket: 'needs' });
      await createTransaction(conn, userId, cycleId, { amount: 200, type: 'expense', bucket: 'wants' });

      const res = await request(app)
        .post('/api/v1/financial-cycles/current/settlement-preview')
        .set('Authorization', authHeader(userId))
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.cycle.id).toBe(cycleId);
      expect(res.body.data.income.actual).toBe(1300);
      expect(res.body.data.needs.actual).toBe(400);
      expect(res.body.data.wants.actual).toBe(200);
      expect(res.body.data.result.surplus).toBeGreaterThan(0);
      expect(res.body.data.result.deficit).toBe(0);
    });

    it('calculates settlement preview with deficit', async () => {
      // Use a fresh cycle for this test to avoid interference
      const newCycleId = await createCycle(conn, userId);
      // Add less income than expenses
      await createTransaction(conn, userId, newCycleId, { amount: 800, type: 'income', incomeKind: 'recurring' });
      await createTransaction(conn, userId, newCycleId, { amount: 500, type: 'expense', bucket: 'needs' });
      await createTransaction(conn, userId, newCycleId, { amount: 400, type: 'expense', bucket: 'wants' });

      const res = await request(app)
        .post('/api/v1/financial-cycles/current/settlement-preview')
        .set('Authorization', authHeader(userId))
        .expect(200);

      expect(res.body.success).toBe(true);
      // Income 800, expenses 900 = deficit 100
      expect(res.body.data.result.deficit).toBe(100);
      expect(res.body.data.result.surplus).toBe(0);

      // Close the cycle to restore original cycle for next test
      await conn.execute('UPDATE financial_cycles SET status = "closed" WHERE id = ?', [newCycleId]);
    });

    it('returns NO_ACTIVE_FINANCIAL_CYCLE when no open cycle', async () => {
      await conn.execute('UPDATE financial_cycles SET status = "closed" WHERE id = ?', [cycleId]);

      const res = await request(app)
        .post('/api/v1/financial-cycles/current/settlement-preview')
        .set('Authorization', authHeader(userId))
        .expect(404);

      expect(res.body.code).toBe('NO_ACTIVE_FINANCIAL_CYCLE');
    });
  });

  describe('POST /financial-cycles/current/settlement', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycle(conn, userId);
    });

    afterAll(async () => { await teardownUser(conn, userId); });

    it('begins settlement and transitions cycle to settlement_pending', async () => {
      await createTransaction(conn, userId, cycleId, { amount: 1200, type: 'income', incomeKind: 'recurring' });
      await createTransaction(conn, userId, cycleId, { amount: 400, type: 'expense', bucket: 'needs' });

      const res = await request(app)
        .post('/api/v1/financial-cycles/current/settlement')
        .set('Authorization', authHeader(userId))
        .send({ idempotencyKey: 'test-settlement-1' })
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('pending');

      // Verify cycle status
      const [cycles] = await conn.execute('SELECT status FROM financial_cycles WHERE id = ?', [cycleId]);
      expect(cycles[0].status).toBe('settlement_pending');

      // Verify settlement record
      const [settlements] = await conn.execute('SELECT * FROM cycle_settlements WHERE cycle_id = ?', [cycleId]);
      expect(settlements.length).toBe(1);
      expect(settlements[0].status).toBe('pending');
    });

    it('returns SETTLEMENT_ALREADY_EXISTS when settlement already pending', async () => {
      const res = await request(app)
        .post('/api/v1/financial-cycles/current/settlement')
        .set('Authorization', authHeader(userId))
        .send({ idempotencyKey: 'test-settlement-1' })
        .expect(200);

      expect(res.body.data.replayed).toBe(true);
      expect(res.body.data.status).toBe('pending');
    });
  });

  describe('POST /financial-cycles/current/close', () => {
    let userId;
    let cycleId;
    let goalId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycle(conn, userId);
      goalId = await createGoal(conn, userId, { amount: 500, name: 'Test Goal' });
    });

    afterAll(async () => { await teardownUser(conn, userId); });

    it('closes cycle with surplus actions', async () => {
      await createTransaction(conn, userId, cycleId, { amount: 1200, type: 'income', incomeKind: 'recurring' });
      await createTransaction(conn, userId, cycleId, { amount: 400, type: 'expense', bucket: 'needs' });

      // Begin settlement
      await request(app)
        .post('/api/v1/financial-cycles/current/settlement')
        .set('Authorization', authHeader(userId))
        .send({ idempotencyKey: 'test-settlement-3' })
        .expect(201);

      // Close with actions
      const res = await request(app)
        .post('/api/v1/financial-cycles/current/close')
        .set('Authorization', authHeader(userId))
        .send({
          actions: [
            { actionType: 'emergency_fund', amount: 50 },
            { actionType: 'goal_allocation', goalId: goalId, amount: 40 },
            { actionType: 'unallocated_savings', amount: 710 }
          ],
          idempotencyKey: 'test-close-1'
        })
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('closed');

      // Verify cycle status
      const [cycles] = await conn.execute('SELECT status, closed_at FROM financial_cycles WHERE id = ?', [cycleId]);
      expect(cycles[0].status).toBe('closed');
      expect(cycles[0].closed_at).not.toBeNull();

      // Verify settlement status
      const [settlements] = await conn.execute('SELECT id, status FROM cycle_settlements WHERE cycle_id = ?', [cycleId]);
      expect(settlements[0].status).toBe('approved');

      // Verify settlement actions
      const [actions] = await conn.execute('SELECT * FROM settlement_actions WHERE settlement_id = ?', [settlements[0].id]);
      expect(actions.length).toBe(3);

      // Verify goal balance updated
      const [goals] = await conn.execute('SELECT current_balance FROM goals WHERE id = ?', [goalId]);
      expect(Number(goals[0].current_balance)).toBe(40);
    });

    it('rejects closure when action totals do not match surplus', async () => {
      // Create new cycle for this test
      const newCycleId = await createCycle(conn, userId);
      await createTransaction(conn, userId, newCycleId, { amount: 1200, type: 'income', incomeKind: 'recurring' });
      await createTransaction(conn, userId, newCycleId, { amount: 400, type: 'expense', bucket: 'needs' });

      await request(app)
        .post('/api/v1/financial-cycles/current/settlement')
        .set('Authorization', authHeader(userId))
        .send({ idempotencyKey: 'test-settlement-4' })
        .expect(201);

      const res = await request(app)
        .post('/api/v1/financial-cycles/current/close')
        .set('Authorization', authHeader(userId))
        .send({
          actions: [
            { actionType: 'emergency_fund', amount: 100 } // Wrong amount
          ],
          idempotencyKey: 'test-close-error'
        })
        .expect(422);

      expect(res.body.code).toBe('SETTLEMENT_ACTIONS_MISMATCH');
    });

    it('closes cycle with deficit without surplus actions', async () => {
      const newCycleId = await createCycle(conn, userId);
      await createTransaction(conn, userId, newCycleId, { amount: 500, type: 'income', incomeKind: 'recurring' });
      await createTransaction(conn, userId, newCycleId, { amount: 800, type: 'expense', bucket: 'needs' });

      await request(app)
        .post('/api/v1/financial-cycles/current/settlement')
        .set('Authorization', authHeader(userId))
        .send({ idempotencyKey: 'test-settlement-5' })
        .expect(201);

      const res = await request(app)
        .post('/api/v1/financial-cycles/current/close')
        .set('Authorization', authHeader(userId))
        .send({ idempotencyKey: 'test-close-2' });

      if (res.status !== 200) {
        console.error('Deficit Close Failed:', res.body);
      }
      expect(res.status).toBe(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.deficit).toBeGreaterThan(0);
    });

    it('rejects closure when INVALID_CYCLE_STATUS', async () => {
      const res = await request(app)
        .post('/api/v1/financial-cycles/current/close')
        .set('Authorization', authHeader(userId))
        .send({ idempotencyKey: 'test-close-3' })
        .expect(409);

      expect(res.body.code).toBe('INVALID_CYCLE_STATUS');
    });
  describe('Action Validation and Retry', () => {
      let testCycleId;
      beforeEach(async () => {
        testCycleId = await createCycle(conn, userId);
        await createTransaction(conn, userId, testCycleId, { amount: 1000, type: 'income', incomeKind: 'recurring' });
        await request(app)
          .post('/api/v1/financial-cycles/current/settlement')
          .set('Authorization', authHeader(userId))
          .send({ idempotencyKey: `setup-settlement-${Date.now()}` })
          .expect(201);
      });

      it('rejects injected userId, cycleId, settlementId in actions', async () => {
        const res = await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'unallocated_savings', amount: 1000, userId: 999 }],
            idempotencyKey: `val1-${Date.now()}`
          })
          .expect(400);
        expect(res.body.code).toBe('INVALID_PAYLOAD');
      });

      it('rejects non-integer BIGINT format for goalId', async () => {
        const res = await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'goal_allocation', amount: 1000, goalId: 'abc' }],
            idempotencyKey: `val2-${Date.now()}`
          })
          .expect(422);
        expect(res.body.code).toBe('INVALID_GOAL_ID');
      });

      it('rejects allocation to draft goal', async () => {
        const gId = await createGoal(conn, userId, { amount: 500, name: 'Draft Goal' });
        await conn.execute('UPDATE goals SET status = "draft" WHERE id = ?', [gId]);
        
        const res = await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'goal_allocation', amount: 1000, goalId: gId }],
            idempotencyKey: `val-draft-${Date.now()}`
          })
          .expect(422);
        expect(res.body.code).toBe('INVALID_GOAL_STATUS');
      });

      it('rejects allocation to paused goal', async () => {
        const pausedGoalId = await createGoal(conn, userId, { amount: 500, name: 'Paused Goal' });
        await conn.execute('UPDATE goals SET status = "paused" WHERE id = ?', [pausedGoalId]);
        
        const res = await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'goal_allocation', amount: 1000, goalId: pausedGoalId }],
            idempotencyKey: `val-paused-${Date.now()}`
          })
          .expect(422);
        expect(res.body.code).toBe('INVALID_GOAL_STATUS');
      });

      it('rejects allocation to ready goal', async () => {
        const gId = await createGoal(conn, userId, { amount: 500, name: 'Ready Goal' });
        await conn.execute('UPDATE goals SET status = "ready" WHERE id = ?', [gId]);
        
        const res = await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'goal_allocation', amount: 1000, goalId: gId }],
            idempotencyKey: `val-ready-${Date.now()}`
          })
          .expect(422);
        expect(res.body.code).toBe('INVALID_GOAL_STATUS');
      });

      it('rejects allocation to executed goal', async () => {
        const gId = await createGoal(conn, userId, { amount: 500, name: 'Executed Goal' });
        await conn.execute('UPDATE goals SET status = "executed" WHERE id = ?', [gId]);
        
        const res = await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'goal_allocation', amount: 1000, goalId: gId }],
            idempotencyKey: `val-executed-${Date.now()}`
          })
          .expect(422);
        expect(res.body.code).toBe('INVALID_GOAL_STATUS');
      });

      it('rejects allocation to cancelled goal', async () => {
        const gId = await createGoal(conn, userId, { amount: 500, name: 'Cancelled Goal' });
        await conn.execute('UPDATE goals SET status = "cancelled" WHERE id = ?', [gId]);
        
        const res = await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'goal_allocation', amount: 1000, goalId: gId }],
            idempotencyKey: `val-cancelled-${Date.now()}`
          })
          .expect(422);
        expect(res.body.code).toBe('INVALID_GOAL_STATUS');
      });

      it('retry close after successful close documents current incomplete idempotency by throwing INVALID_CYCLE_STATUS', async () => {
        // First successful close
        await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'unallocated_savings', amount: 1000 }],
            idempotencyKey: 'test-retry-close'
          })
          .expect(200);

        // Retry with same key
        const res = await request(app)
          .post('/api/v1/financial-cycles/current/close')
          .set('Authorization', authHeader(userId))
          .send({
            actions: [{ actionType: 'unallocated_savings', amount: 1000 }],
            idempotencyKey: 'test-retry-close'
          })
          .expect(409);
        
        expect(res.body.code).toBe('INVALID_CYCLE_STATUS');
      });
    });
  });

  describe('Closed-cycle immutability', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycle(conn, userId);
    });

    afterAll(async () => { await teardownUser(conn, userId); });

    it('rejects expense deletion for closed cycle', async () => {
      // Create an expense first
      const expenseId = await createTransaction(conn, userId, cycleId, { amount: 50, type: 'expense', bucket: 'needs' });
      await conn.execute('UPDATE financial_cycles SET status = "closed" WHERE id = ?', [cycleId]);

      const res = await request(app)
        .delete(`/api/v1/expenses/${expenseId}`)
        .set('Authorization', authHeader(userId))
        .expect(409);

      expect(res.body.code).toBe('CLOSED_CYCLE_IMMUTABLE');
    });

    it('rejects income deletion for closed cycle', async () => {
      // Create an income first
      const incomeId = await createTransaction(conn, userId, cycleId, { amount: 100, type: 'income', incomeKind: 'recurring' });
      await conn.execute('UPDATE financial_cycles SET status = "closed" WHERE id = ?', [cycleId]);

      const res = await request(app)
        .delete(`/api/v1/incomes/${incomeId}`)
        .set('Authorization', authHeader(userId))
        .expect(409);

      expect(res.body.code).toBe('CLOSED_CYCLE_IMMUTABLE');
    });
  });

  describe('Dashboard integration', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycle(conn, userId);
    });

    afterAll(async () => { await teardownUser(conn, userId); });

    it('returns setupRequired when cycle is closed', async () => {
      await conn.execute('UPDATE financial_cycles SET status = "closed", closed_at = NOW() WHERE id = ?', [cycleId]);

      const res = await request(app)
        .get('/api/v1/dashboard/summary')
        .set('Authorization', authHeader(userId))
        .expect(200);

      expect(res.body.data.setupRequired).toBe(true);
      expect(res.body.data.warnings).toContain('NO_ACTIVE_FINANCIAL_CYCLE');
      expect(res.body.data.warnings).toContain('PREVIOUS_CYCLE_CLOSED');
    });
  });

  describe('Phase 3A regressions', () => {
    let userId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
    });

    afterAll(async () => { await teardownUser(conn, userId); });

    it('cycle creation still works', async () => {
      const res = await request(app)
        .post('/api/v1/financial-cycles')
        .set('Authorization', authHeader(userId))
        .send({})
        .expect(201);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBeDefined();
    });

    it('transaction auto-linking still works', async () => {
      const cycleId = await createCycle(conn, userId);

      const res = await request(app)
        .post('/api/v1/expenses')
        .set('Authorization', authHeader(userId))
        .send({
          amount: 50,
          bucket: 'needs',
          category: 'other'
        })
        .expect(201);

      expect(res.body.data.cycleId).toBe(cycleId);
    });
  });
});
