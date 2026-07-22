const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const { env } = require('../config/env');

describe('Phase 2B: Ready Goal Actions API', () => {
  let userToken;
  let userId;
  let authHeader;
  let otherUserToken;
  let otherUserId;
  let otherAuthHeader;
  let dbConnection;

  beforeAll(async () => {
    if (!env.dbName.endsWith('_test')) {
      throw new Error('Tests must run against a test database');
    }

    dbConnection = await db.getConnection();

    // Create main user
    const [userRes] = await dbConnection.execute(
      `INSERT INTO users (full_name, email, password_hash) VALUES ('Action User', CONCAT(UUID(), '@example.com'), 'hash')`
    );
    userId = userRes.insertId;

    await dbConnection.execute(
      `INSERT INTO financial_cycles (user_id, start_date, end_date, status, expected_income, policy_version) VALUES (?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'open', 1000, '1.0')`,
      [userId]
    );

    // Create other user
    const [otherUserRes] = await dbConnection.execute(
      `INSERT INTO users (full_name, email, password_hash) VALUES ('Other User', CONCAT(UUID(), '@example.com'), 'hash')`
    );
    otherUserId = otherUserRes.insertId;

    await dbConnection.execute(
      `INSERT INTO financial_cycles (user_id, start_date, end_date, status, expected_income, policy_version) VALUES (?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'open', 1000, '1.0')`,
      [otherUserId]
    );

    // Login (mocked via JWT generation since auth.test.js uses actual routes, we can just generate a token)
    const jwt = require('jsonwebtoken');
    userToken = jwt.sign({ id: userId, email: 'action@example.com' }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });
    authHeader = `Bearer ${userToken}`;

    otherUserToken = jwt.sign({ id: otherUserId, email: 'other@example.com' }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });
    otherAuthHeader = `Bearer ${otherUserToken}`;
  });

  afterAll(async () => {
    if (env.dbName.endsWith('_test') && userId && otherUserId) {
      await dbConnection.execute('DELETE FROM transactions WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await dbConnection.execute('DELETE FROM goal_transactions WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await dbConnection.execute('DELETE FROM goals WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await dbConnection.execute('DELETE FROM financial_cycles WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await dbConnection.execute('DELETE FROM users WHERE id IN (?, ?)', [userId, otherUserId]);
    }
    dbConnection.release();
    await db.end();
  });

  afterEach(async () => {
    // Clear out goals and transactions after each test for these users
    if (userId && otherUserId) {
      await dbConnection.execute('DELETE FROM transactions WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await dbConnection.execute('DELETE FROM goal_transactions WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await dbConnection.execute('DELETE FROM goals WHERE user_id IN (?, ?)', [userId, otherUserId]);
    }
  });

  const createGoal = async (uid, status, targetAmount, currentBalance) => {
    const [res] = await dbConnection.execute(
      `INSERT INTO goals (user_id, name, goal_type, target_amount, current_balance, planning_mode, status, ready_at)
       VALUES (?, 'Test Goal', 'custom', ?, ?, 'contribution_based', ?, NOW())`,
      [uid, targetAmount, currentBalance, status]
    );
    const goalId = res.insertId;

    if (currentBalance > 0) {
       await dbConnection.execute(
         `INSERT INTO goal_transactions (user_id, goal_id, amount, transaction_type) VALUES (?, ?, ?, 'contribution')`,
         [uid, goalId, currentBalance]
       );
    }

    return goalId;
  };

  describe('1. Execute Goal', () => {
    it('1.1 should execute a ready goal successfully, creating one ledger debit and one capital expense, updating status atomically', async () => {
      const goalId = await createGoal(userId, 'ready', 1000, 1000);
      const idempotencyKey = 'execute_1.1';

      const res = await request(app)
        .post(`/api/v1/goals/${goalId}/execute`)
        .set('Authorization', authHeader)
        .send({ idempotencyKey });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Verify status updated
      const [goals] = await dbConnection.execute('SELECT status, executed_at, current_balance FROM goals WHERE id = ?', [goalId]);
      expect(goals[0].status).toBe('executed');
      expect(goals[0].executed_at).not.toBeNull();
      expect(Number(goals[0].current_balance)).toBe(0);

      // Verify ledger transaction
      const [goalTx] = await dbConnection.execute('SELECT * FROM goal_transactions WHERE goal_id = ? AND transaction_type = "execution"', [goalId]);
      expect(goalTx.length).toBe(1);
      expect(Number(goalTx[0].amount)).toBe(1000);
      expect(goalTx[0].idempotency_key).toBe(idempotencyKey);

      // Verify general transaction (capital expense)
      const [txs] = await dbConnection.execute('SELECT * FROM transactions WHERE user_id = ? AND transaction_type = "capital_expense"', [userId]);
      expect(txs.length).toBe(1);
      expect(Number(txs[0].amount)).toBe(1000);
      expect(txs[0].direction).toBe('outflow');
      expect(txs[0].budget_bucket).toBe('capital_expense');
    });

    it('1.2 execution replay creates no duplicate', async () => {
      const goalId = await createGoal(userId, 'ready', 500, 500);
      const idempotencyKey = 'execute_1.2';

      // First run
      const res1 = await request(app)
        .post(`/api/v1/goals/${goalId}/execute`)
        .set('Authorization', authHeader)
        .send({ idempotencyKey });
      expect(res1.status).toBe(200);

      // Second run (replay)
      const res2 = await request(app)
        .post(`/api/v1/goals/${goalId}/execute`)
        .set('Authorization', authHeader)
        .send({ idempotencyKey });
      expect(res2.status).toBe(200);
      expect(res2.body.message).toMatch(/idempotent/i);

      // Still only one execution ledger entry
      const [goalTx] = await dbConnection.execute('SELECT * FROM goal_transactions WHERE goal_id = ? AND transaction_type = "execution"', [goalId]);
      expect(goalTx.length).toBe(1);
    });

    it('1.3 non-ready execution rejected and rollback leaves goal unchanged', async () => {
      const goalId = await createGoal(userId, 'active', 500, 500); // Not ready

      const res = await request(app)
        .post(`/api/v1/goals/${goalId}/execute`)
        .set('Authorization', authHeader)
        .send({ idempotencyKey: 'execute_1.3' });

      expect(res.status).toBe(400); // Bad request or not ready
      expect(res.body.message).toMatch(/ready status/i);

      // Verify unchanged
      const [goals] = await dbConnection.execute('SELECT status FROM goals WHERE id = ?', [goalId]);
      expect(goals[0].status).toBe('active');
    });

    it('1.4 ownership rejection', async () => {
      const goalId = await createGoal(otherUserId, 'ready', 500, 500);

      const res = await request(app)
        .post(`/api/v1/goals/${goalId}/execute`)
        .set('Authorization', authHeader) // user1 trying to execute user2's goal
        .send({ idempotencyKey: 'execute_1.4' });

      expect(res.status).toBe(404); // Unauthorized/Not Found
    });
  });

  describe('2. Defer Goal', () => {
    it('2.1 defer creates no financial movement', async () => {
      const goalId = await createGoal(userId, 'ready', 1000, 1000);

      const res = await request(app)
        .post(`/api/v1/goals/${goalId}/defer`)
        .set('Authorization', authHeader);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Verify no execution tx created
      const [goalTx] = await dbConnection.execute('SELECT * FROM goal_transactions WHERE goal_id = ? AND transaction_type = "execution"', [goalId]);
      expect(goalTx.length).toBe(0);

      // Verify status changed to active
      const [goals] = await dbConnection.execute('SELECT status FROM goals WHERE id = ?', [goalId]);
      expect(goals[0].status).toBe('active');
    });
  });

  describe('3. Reallocate Goal', () => {
    it('3.1 successful goal-to-goal reallocation, entries reconcile, dest becomes ready if exactly target', async () => {
      const srcId = await createGoal(userId, 'ready', 1000, 1000);
      const destId = await createGoal(userId, 'active', 500, 0);

      const res = await request(app)
        .post(`/api/v1/goals/${srcId}/reallocate`)
        .set('Authorization', authHeader)
        .send({ destinationGoalId: destId, amount: 500, idempotencyKey: 'reallocate_3.1' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Verify source changed to active, balance is 500
      const [src] = await dbConnection.execute('SELECT status, current_balance FROM goals WHERE id = ?', [srcId]);
      expect(src[0].status).toBe('active');
      expect(Number(src[0].current_balance)).toBe(500);

      // Verify dest changed to ready, balance is 500
      const [dest] = await dbConnection.execute('SELECT status, current_balance FROM goals WHERE id = ?', [destId]);
      expect(dest[0].status).toBe('ready');
      expect(Number(dest[0].current_balance)).toBe(500);

      // Verify ledger reconciliation
      const [srcTx] = await dbConnection.execute('SELECT * FROM goal_transactions WHERE goal_id = ? AND transaction_type = "reallocation_out"', [srcId]);
      expect(srcTx.length).toBe(1);
      expect(Number(srcTx[0].amount)).toBe(500);
      expect(srcTx[0].related_goal_id.toString()).toBe(destId.toString());

      const [destTx] = await dbConnection.execute('SELECT * FROM goal_transactions WHERE goal_id = ? AND transaction_type = "reallocation_in"', [destId]);
      expect(destTx.length).toBe(1);
      expect(Number(destTx[0].amount)).toBe(500);
      expect(destTx[0].related_goal_id.toString()).toBe(srcId.toString());
    });

    it('3.2 source equals destination rejected', async () => {
      const srcId = await createGoal(userId, 'ready', 1000, 1000);

      const res = await request(app)
        .post(`/api/v1/goals/${srcId}/reallocate`)
        .set('Authorization', authHeader)
        .send({ destinationGoalId: srcId, amount: 100, idempotencyKey: 'reallocate_3.2' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/differ/i);
    });

    it('3.3 insufficient balance rejected', async () => {
      const srcId = await createGoal(userId, 'ready', 1000, 1000);
      const destId = await createGoal(userId, 'active', 2000, 0);

      const res = await request(app)
        .post(`/api/v1/goals/${srcId}/reallocate`)
        .set('Authorization', authHeader)
        .send({ destinationGoalId: destId, amount: 1500, idempotencyKey: 'reallocate_3.3' }); // More than source has

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/exceeds/i);
    });

    it('3.4 destination overfunding rejected', async () => {
      const srcId = await createGoal(userId, 'ready', 1000, 1000);
      const destId = await createGoal(userId, 'active', 500, 400); // Needs 100

      const res = await request(app)
        .post(`/api/v1/goals/${srcId}/reallocate`)
        .set('Authorization', authHeader)
        .send({ destinationGoalId: destId, amount: 200, idempotencyKey: 'reallocate_3.4' }); // Too much

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/overfunding/i);
    });

    it('3.5 deterministic lock ordering and concurrent safety', async () => {
      // Simulate concurrent requests by running two reallocations at the same time
      const srcId = await createGoal(userId, 'ready', 2000, 2000);
      const destId = await createGoal(userId, 'active', 3000, 0);

      const p1 = request(app)
        .post(`/api/v1/goals/${srcId}/reallocate`)
        .set('Authorization', authHeader)
        .send({ destinationGoalId: destId, amount: 500, idempotencyKey: 'reallocate_3.5a' });

      const p2 = request(app)
        .post(`/api/v1/goals/${srcId}/reallocate`)
        .set('Authorization', authHeader)
        .send({ destinationGoalId: destId, amount: 500, idempotencyKey: 'reallocate_3.5b' });

      const [res1, res2] = await Promise.all([p1, p2]);

      // One should succeed, one should fail due to 'Source goal must be in ready status'
      const statuses = [res1.status, res2.status].sort();
      expect(statuses).toEqual([200, 400]);

      // Final dest balance should be exactly 500
      const [dest] = await dbConnection.execute('SELECT current_balance FROM goals WHERE id = ?', [destId]);
      expect(Number(dest[0].current_balance)).toBe(500);
    });
  });
});
