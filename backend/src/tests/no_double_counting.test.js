const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');

describe('G3B: No-Double-Counting Invariant', () => {
  let token;
  let userId;
  let cycleId;
  let ordinaryGoal1, ordinaryGoal2, systemGoalId;

  beforeAll(async () => {
    // 1. Cleanup
    await db.execute('DELETE FROM goal_savings_allocations WHERE allocation_id IN (SELECT id FROM savings_allocations WHERE user_id IN (SELECT id FROM users WHERE email = ?))', ['nodoublecount@test.com']).catch(() => {});
    await db.execute('DELETE FROM savings_allocations WHERE user_id IN (SELECT id FROM users WHERE email = ?)', ['nodoublecount@test.com']).catch(() => {});
    await db.execute('DELETE FROM financial_cycles WHERE user_id IN (SELECT id FROM users WHERE email = ?)', ['nodoublecount@test.com']).catch(() => {});
    await db.execute('DELETE FROM goals WHERE user_id IN (SELECT id FROM users WHERE email = ?)', ['nodoublecount@test.com']).catch(() => {});
    await db.execute('DELETE FROM users WHERE email = ?', ['nodoublecount@test.com']).catch(() => {});

    // 2. Create a clean user
    const [userRes] = await db.execute('INSERT INTO users (email, password_hash, full_name) VALUES (?, ?, ?)', ['nodoublecount@test.com', 'hash', 'Test User']);
    userId = userRes.insertId;
    token = jwt.sign({ id: userId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });

    // 3. Insert ordinary goals
    const [g1] = await db.execute('INSERT INTO goals (user_id, name, target_amount, current_balance, status, goal_type) VALUES (?, ?, ?, ?, ?, ?)', [userId, 'Ordinary 1', 1000, 0, 'active', 'gadget']);
    ordinaryGoal1 = g1.insertId;

    const [g2] = await db.execute('INSERT INTO goals (user_id, name, target_amount, current_balance, status, goal_type) VALUES (?, ?, ?, ?, ?, ?)', [userId, 'Ordinary 2', 500, 0, 'active', 'travel']);
    ordinaryGoal2 = g2.insertId;

    // 4. Insert system-managed goal manually
    const [g3] = await db.execute('INSERT INTO goals (user_id, name, target_amount, current_balance, status, goal_type, is_system_managed) VALUES (?, ?, ?, ?, ?, ?, ?)', [userId, 'Emergency', 10000, 0, 'active', 'emergency_fund', 1]);
    systemGoalId = g3.insertId;

    // 5. Create an open financial cycle
    const [cycleRes] = await db.execute('INSERT INTO financial_cycles (user_id, start_date, end_date, expected_income, status) VALUES (?, ?, ?, ?, ?)', [userId, '2026-08-01', '2026-08-31', 2000, 'open']);
    cycleId = cycleRes.insertId;
  });

  afterAll(async () => {
    await db.execute('DELETE FROM goal_cycle_allocations WHERE cycle_id = ?', [cycleId]).catch(() => {});
    await db.execute('DELETE FROM cycle_savings_allocations WHERE cycle_id = ?', [cycleId]).catch(() => {});
    await db.execute('DELETE FROM goal_savings_allocations WHERE allocation_id IN (SELECT id FROM savings_allocations WHERE user_id = ?)', [userId]).catch(() => {});
    await db.execute('DELETE FROM savings_allocations WHERE user_id = ?', [userId]).catch(() => {});
    await db.execute('DELETE FROM goals WHERE user_id = ?', [userId]).catch(() => {});
    await db.execute('DELETE FROM financial_cycles WHERE id = ?', [cycleId]).catch(() => {});
    await db.execute('DELETE FROM users WHERE id = ?', [userId]).catch(() => {});
  });

  it('proves system-managed Emergency Fund is excluded from ordinary totals and calculates unallocated savings correctly', async () => {
    const res = await request(app)
      .post(`/api/v1/savings/allocation-preview`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        savingsAmount: 1000,
        emergencyFundRate: 10,
        goalAllocations: [
          { goalId: ordinaryGoal1, amount: 200 },
          { goalId: ordinaryGoal2, amount: 200 }
        ]
      });

    expect(res.status).toBe(200);
    const data = res.body.data;
    expect(data.savingsAmount).toBe(1000);
    expect(data.emergencyFundAmount).toBe(100);
    expect(data.totalGoalAllocations).toBe(400);
    expect(data.unallocatedSavings).toBe(500);
    expect(data.savingsAmount).toBe(data.emergencyFundAmount + data.totalGoalAllocations + data.unallocatedSavings);
  });

  it('rejects over-allocation without counting system goals', async () => {
    const res = await request(app)
      .post(`/api/v1/savings/allocation-preview`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        savingsAmount: 1000,
        emergencyFundRate: 10,
        goalAllocations: [
          { goalId: ordinaryGoal1, amount: 500 },
          { goalId: ordinaryGoal2, amount: 500 }
        ]
      });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe('SAVINGS_ALLOCATION_EXCEEDED');
  });

  describe('Legacy manual Emergency Fund handling', () => {
    let legacyGoalId;

    beforeAll(async () => {
      const [gLegacy] = await db.execute('INSERT INTO goals (user_id, name, target_amount, current_balance, status, goal_type, is_system_managed) VALUES (?, ?, ?, ?, ?, ?, ?)', [userId, 'Legacy EF', 1000, 0, 'active', 'emergency_fund', 0]);
      legacyGoalId = gLegacy.insertId;
    });

    afterAll(async () => {
      await db.execute('DELETE FROM goals WHERE id = ?', [legacyGoalId]).catch(() => {});
    });

    it('rejects preview with LEGACY_EMERGENCY_FUND_RECONCILIATION_REQUIRED', async () => {
      const res = await request(app)
        .post(`/api/v1/savings/allocation-preview`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          savingsAmount: 1000,
          emergencyFundRate: 10
        });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('LEGACY_EMERGENCY_FUND_RECONCILIATION_REQUIRED');
    });

    it('rejects approval with LEGACY_EMERGENCY_FUND_RECONCILIATION_REQUIRED', async () => {
      const res = await request(app)
        .put(`/api/v1/savings/allocation`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          savingsAmount: 1000,
          emergencyFundRate: 10,
          goalAllocations: [],
          idempotencyKey: 'test-key-2'
        });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('LEGACY_EMERGENCY_FUND_RECONCILIATION_REQUIRED');
    });
  });
});
