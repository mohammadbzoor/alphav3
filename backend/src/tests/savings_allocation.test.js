const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const { env } = require('../config/env');

describe('Phase 2C: Savings Allocation API', () => {
  let userToken;
  let userId;
  let authHeader;
  let dbConnection;
  let goalId1;
  let goalId2;

  beforeAll(async () => {
    if (!env.dbName.endsWith('_test')) {
      throw new Error('Tests must run against a test database');
    }

    dbConnection = await db.getConnection();

    // Create main user
    const [userRes] = await dbConnection.execute(
      `INSERT INTO users (full_name, email, password_hash) VALUES ('Allocation User', CONCAT(UUID(), '@example.com'), 'hash')`
    );
    userId = userRes.insertId;

    // Login (mocking or real logic if app.js has it, here we assume jwt sign)
    const jwt = require('jsonwebtoken');
    userToken = jwt.sign({ id: userId, email: 'allocation@example.com' }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });
    authHeader = `Bearer ${userToken}`;

    // Create two active goals
    const [goal1] = await dbConnection.execute(
      `INSERT INTO goals (user_id, goal_type, name, target_amount, current_balance, planned_contribution, priority, status)
       VALUES (?, 'custom', 'Goal 1', 1000, 0, 50, 1, 'active')`,
      [userId]
    );
    goalId1 = goal1.insertId;

    const [goal2] = await dbConnection.execute(
      `INSERT INTO goals (user_id, goal_type, name, target_amount, current_balance, planned_contribution, priority, status)
       VALUES (?, 'custom', 'Goal 2', 500, 0, 0, 2, 'active')`,
      [userId]
    );
    goalId2 = goal2.insertId;
  });

  afterAll(async () => {
    const [allocs] = await dbConnection.execute('SELECT id FROM savings_allocations WHERE user_id = ?', [userId]);
    if (allocs.length > 0) {
      const allocIds = allocs.map(a => a.id).join(',');
      await dbConnection.execute(`DELETE FROM goal_savings_allocations WHERE allocation_id IN (${allocIds})`);
      await dbConnection.execute('DELETE FROM savings_allocations WHERE user_id = ?', [userId]);
    }
    await dbConnection.execute('DELETE FROM goals WHERE user_id = ?', [userId]);
    await dbConnection.execute('DELETE FROM users WHERE id = ?', [userId]);
    if (dbConnection) dbConnection.release();
  });

  describe('GET /api/v1/savings/allocation-preview', () => {
    it('calculates preview correctly with default rate and existing DB values', async () => {
      const res = await request(app)
        .post('/api/v1/savings/allocation-preview')
        .send({ savingsAmount: 1000 })
        .set('Authorization', authHeader)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.savingsAmount).toBe(1000);
      expect(res.body.data.emergencyFundAmount).toBe(100); // 10%
      expect(res.body.data.totalGoalAllocations).toBe(50); // From Goal 1
      expect(res.body.data.unallocatedSavings).toBe(850); // 1000 - 100 - 50
      expect(res.body.data.goals.length).toBe(2);
    });

    it('calculates preview with provided goalAllocations overriding DB values', async () => {
      const res = await request(app)
        .post('/api/v1/savings/allocation-preview')
        .send({
          savingsAmount: 1000,
          goalAllocations: [{ goalId: goalId1, amount: 200 }]
        })
        .set('Authorization', authHeader)
        .expect(200);

      expect(res.body.data.totalGoalAllocations).toBe(200);
      expect(res.body.data.unallocatedSavings).toBe(700); // 1000 - 100 - 200
    });

    it('calculates preview correctly with custom rate (20%)', async () => {
      const res = await request(app)
        .post('/api/v1/savings/allocation-preview')
        .send({ savingsAmount: 1000, emergencyFundRate: 20 })
        .set('Authorization', authHeader)
        .expect(200);

      expect(res.body.data.emergencyFundAmount).toBe(200); // 20%
    });

    it('rejects invalid rate', async () => {
      await request(app)
        .post('/api/v1/savings/allocation-preview')
        .send({ savingsAmount: 1000, emergencyFundRate: 150 })
        .set('Authorization', authHeader)
        .expect(400);
    });
  });

  describe('PUT /api/v1/savings/allocation', () => {
    let idempotencyKey;

    beforeEach(() => {
      idempotencyKey = `test-key-${Date.now()}`;
    });

    it('approves valid allocation and updates DB tables correctly', async () => {
      const res = await request(app)
        .put('/api/v1/savings/allocation')
        .set('Authorization', authHeader)
        .send({
          savingsAmount: 1000,
          emergencyFundRate: 10,
          idempotencyKey,
          goals: [
            { goalId: goalId1, allocationAmount: 100 },
            { goalId: goalId2, allocationAmount: 200 }
          ]
        })
        .expect(200);

      expect(res.body.success).toBe(true);

      const [rows] = await dbConnection.execute('SELECT * FROM savings_allocations WHERE user_id = ? AND status = "provisional" ORDER BY id DESC LIMIT 1', [userId]);
      expect(rows.length).toBe(1);
      const allocId = rows[0].id;
      expect(parseInt(rows[0].unallocated_savings_amount)).toBe(600);

      const [gRows] = await dbConnection.execute('SELECT * FROM goal_savings_allocations WHERE allocation_id = ? ORDER BY goal_id', [allocId]);
      expect(gRows.length).toBe(2);
      expect(parseInt(gRows[0].planned_amount)).toBe(100);
      expect(parseInt(gRows[1].planned_amount)).toBe(200);
    });

    it('handles idempotent replay', async () => {
      const payload = {
        savingsAmount: 1000,
        emergencyFundRate: 10,
        idempotencyKey,
        goals: [
          { goalId: goalId1, allocationAmount: 100 }
        ]
      };

      await request(app).put('/api/v1/savings/allocation').set('Authorization', authHeader).send(payload).expect(200);

      const res2 = await request(app).put('/api/v1/savings/allocation').set('Authorization', authHeader).send(payload).expect(200);
      expect(res2.body.replayed).toBe(true);
    });

    it('rejects allocation exceeding available savings', async () => {
      const res = await request(app)
        .put('/api/v1/savings/allocation')
        .set('Authorization', authHeader)
        .send({
          savingsAmount: 1000,
          emergencyFundRate: 10,
          goals: [
            { goalId: goalId1, allocationAmount: 800 },
            { goalId: goalId2, allocationAmount: 200 } // Total 1000 > 900 available
          ]
        })
        .expect(400);

      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/exceed/i);
    });
  });

  describe('GET /api/v1/savings/allocation', () => {
    it('fetches provisional allocation', async () => {
      const res = await request(app)
        .get('/api/v1/savings/allocation')
        .set('Authorization', authHeader)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data).toBeDefined();
    });
  });
});
