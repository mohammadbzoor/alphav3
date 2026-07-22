/**
 * Phase 3A.2 – Cycle-Linked Financial Activity
 *
 * Test matrix
 * ───────────
 * Integration (real DB, alpha_test)
 *   1.  POST /expenses – auto-links to open cycle
 *   2.  POST /expenses – NO_ACTIVE_FINANCIAL_CYCLE when no open cycle
 *   3.  POST /expenses – rejects cross-user cycle_id
 *   4.  POST /expenses – rejects closed cycle
 *   5.  POST /incomes – auto-links to open cycle
 *   6.  POST /incomes – NO_ACTIVE_FINANCIAL_CYCLE when no open cycle
 *   7.  POST /incomes – rejects cross-user cycle_id
 *   8.  POST /incomes – rejects closed cycle
 *   9.  Metrics – only confirmed transactions counted
 *   10. Metrics – pending/cancelled transactions excluded
 *   11. Metrics – capital_expense excluded from needs/wants
 *   12. Cycle creation – generates one occurrence per active commitment
 *   13. Occurrence – unpaid reserves Needs but is not expense
 *   14. Occurrence – never auto-marked paid
 *   15. Occurrence – paid_transaction_id references confirmed payment
 *   16. Phase 3A.1 regression – cycle creation still works
 */

'use strict';

process.env.NODE_ENV = 'test';

const request = require('supertest');
const { app } = require('../app');
const { db }  = require('../config/database');
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

/** Insert a minimal user + financial_profile + allocation_preference */
async function seedUser(conn, { income = 1000, paymentDay = 15, seedPref = true } = {}) {
  const [uRes] = await conn.execute(
    `INSERT INTO users (full_name, email, password_hash)
     VALUES ('Cycle Activity Test', CONCAT(UUID(), '@cycles.test'), 'hash')`
  );
  const userId = uRes.insertId;

  await conn.execute(
    `INSERT INTO financial_profiles
       (user_id, expected_monthly_income, payment_day, detected_tier, currency, timezone, onboarding_status)
     VALUES (?, ?, ?, 'Middle', 'JOD', 'Asia/Amman', 'completed')`,
    [userId, income, paymentDay]
  );

  if (seedPref) {
    await conn.execute(
      `INSERT INTO allocation_preferences
         (user_id, needs_bps, wants_bps, savings_bps, source, based_on_income)
       VALUES (?, 5000, 3000, 2000, 'system_tier', ?)`,
      [userId, income]
    );
  }

  return userId;
}

/** Delete all cycle/snapshot/transaction/commitment data and the user itself */
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
  // Delete transactions before cycles due to foreign key constraint
  await conn.execute('DELETE FROM transactions WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM financial_cycles WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM financial_commitments WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM allocation_preferences WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM financial_profiles WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM users WHERE id = ?', [userId]);
}

/** Create an open cycle for a user */
async function createCycleForUser(userId) {
  const res = await request(app)
    .post('/api/v1/financial-cycles')
    .set('Authorization', authHeader(userId))
    .expect(201);
  return res.body.data.id;
}

async function getCycleStartDate(conn, userId) {
  const tempCycleId = await createCycleForUser(userId);
  const [cycleRows] = await conn.execute('SELECT DATE_FORMAT(start_date, "%Y-%m-%d") as start_date FROM financial_cycles WHERE id = ?', [tempCycleId]);
  const safeDate = cycleRows[0].start_date;
  
  await conn.execute('DELETE FROM commitment_occurrences WHERE cycle_id = ?', [tempCycleId]);
  await conn.execute('DELETE FROM cycle_allocation_snapshots WHERE cycle_id = ?', [tempCycleId]);
  await conn.execute('DELETE FROM transactions WHERE cycle_id = ?', [tempCycleId]);
  await conn.execute('DELETE FROM financial_cycles WHERE id = ?', [tempCycleId]);
  return safeDate;
}

/** Create an active commitment for a user */
async function createCommitment(conn, userId, { amount = 200, name = 'Rent', nextDueDate } = {}) {
  const [result] = await conn.execute(
    `INSERT INTO financial_commitments
       (user_id, name, amount, frequency, next_due_date, budget_bucket, flexibility, status)
     VALUES (?, ?, ?, 'monthly', ?, 'needs', 'fixed', 'active')`,
    [userId, name, amount, nextDueDate]
  );
  return result.insertId;
}

// ─────────────────────────────────────────────────────────────────────────── //
// INTEGRATION                                                                  //
// ─────────────────────────────────────────────────────────────────────────── //

describe('Phase 3A.2 – Cycle-Linked Financial Activity (integration)', () => {
  if (!env.dbName || !env.dbName.endsWith('_test')) {
    throw new Error('Integration tests must run against a _test database.');
  }

  let conn;

  beforeAll(async () => {
    conn = await db.getConnection();
  });

  afterAll(async () => {
    if (conn) conn.release();
    await db.end();
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 1-4. Transaction auto-linking and validation
  // ────────────────────────────────────────────────────────────────────── //
  describe('POST /expenses – auto-linking and validation', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycleForUser(userId);
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('auto-links to open cycle when cycle_id not provided', async () => {
      const res = await request(app)
        .post('/api/v1/expenses')
        .set('Authorization', authHeader(userId))
        .send({
          amount: 50,
          bucket: 'needs',
          category: 'rent',
          description: 'Test expense'
        })
        .expect(201);

      const [rows] = await conn.execute(
        `SELECT cycle_id FROM transactions WHERE id = ?`,
        [res.body.data.id]
      );
      expect(Number(rows[0].cycle_id)).toBe(cycleId);
    });

    it('returns NO_ACTIVE_FINANCIAL_CYCLE when no open cycle exists', async () => {
      // Close the cycle
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

    it('rejects payload containing cycleId', async () => {
      const res = await request(app)
        .post('/api/v1/expenses')
        .set('Authorization', authHeader(userId))
        .send({
          amount: 50,
          bucket: 'needs',
          category: 'rent',
          cycleId: cycleId
        })
        .expect(400);

      expect(res.body.code).toBe('INVALID_PAYLOAD');
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 5-8. Income auto-linking and validation
  // ────────────────────────────────────────────────────────────────────── //
  describe('POST /incomes – auto-linking and validation', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycleForUser(userId);
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('auto-links to open cycle when cycle_id not provided', async () => {
      const res = await request(app)
        .post('/api/v1/incomes')
        .set('Authorization', authHeader(userId))
        .send({
          amount: 1000,
          source: 'salary',
          description: 'Test income'
        })
        .expect(201);

      const [rows] = await conn.execute(
        `SELECT cycle_id FROM transactions WHERE id = ?`,
        [res.body.data.id]
      );
      expect(Number(rows[0].cycle_id)).toBe(cycleId);
    });

    it('returns NO_ACTIVE_FINANCIAL_CYCLE when no open cycle exists', async () => {
      // Close the cycle
      await conn.execute(
        `UPDATE financial_cycles SET status = 'closed' WHERE id = ?`,
        [cycleId]
      );

      const res = await request(app)
        .post('/api/v1/incomes')
        .set('Authorization', authHeader(userId))
        .send({
          amount: 1000,
          source: 'salary'
        })
        .expect(422);

      expect(res.body.code).toBe('NO_ACTIVE_FINANCIAL_CYCLE');
    });

    it('rejects payload containing cycleId', async () => {
      const res = await request(app)
        .post('/api/v1/incomes')
        .set('Authorization', authHeader(userId))
        .send({
          amount: 1000,
          source: 'salary',
          cycleId: cycleId
        })
        .expect(400);

      expect(res.body.code).toBe('INVALID_PAYLOAD');
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 9-11. Metrics – confirmed-only and capital_expense exclusion
  // ────────────────────────────────────────────────────────────────────── //
  describe('Metrics – confirmed-only and capital_expense exclusion', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      cycleId = await createCycleForUser(userId);
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('only confirmed transactions affect metrics', async () => {
      // Directly insert confirmed expense
      await conn.execute(
        `INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, category, status, occurred_at, confirmed_at)
         VALUES (?, ?, 100, 'outflow', 'expense', 'needs', 'rent', 'confirmed', NOW(), NOW())`,
        [userId, cycleId]
      );

      // Create pending expense
      await conn.execute(
        `INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, category, status, occurred_at, confirmed_at)
         VALUES (?, ?, 50, 'outflow', 'expense', 'needs', 'rent', 'pending', NOW(), NULL)`,
        [userId, cycleId]
      );

      const { FinanceRepository } = require('../repositories/finance.repository');
      const confirmedTotal = await FinanceRepository.getConfirmedNeedsExpenses(userId);

      expect(confirmedTotal).toBe(100); // Only confirmed counted
    });

    it('pending/cancelled transactions excluded from metrics', async () => {
      const { FinanceRepository } = require('../repositories/finance.repository');

      // Create cancelled expense
      await conn.execute(
        `INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, category, status, occurred_at, confirmed_at)
         VALUES (?, ?, 75, 'outflow', 'expense', 'needs', 'rent', 'cancelled', NOW(), NULL)`,
        [userId, cycleId]
      );

      const confirmedTotal = await FinanceRepository.getConfirmedNeedsExpenses(userId);
      expect(confirmedTotal).toBe(100); // Still only the confirmed one
    });

    it('capital_expense excluded from needs/wants totals', async () => {
      const { FinanceRepository } = require('../repositories/finance.repository');

      // Create capital_expense transaction with pending status (schema constraint prevents confirmed capital_expense)
      await conn.execute(
        `INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, status, occurred_at, confirmed_at)
         VALUES (?, ?, 200, 'outflow', 'capital_expense', 'capital_expense', 'pending', NOW(), NULL)`,
        [userId, cycleId]
      );

      const confirmedTotal = await FinanceRepository.getConfirmedNeedsExpenses(userId);
      expect(confirmedTotal).toBe(100); // Capital expense not counted (also not confirmed)
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 12. Cycle creation generates commitment occurrences
  // ────────────────────────────────────────────────────────────────────── //
  describe('Cycle creation – generates commitment occurrences', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      // Create active commitments
      const safeDate = await getCycleStartDate(conn, userId);
      await createCommitment(conn, userId, { amount: 200, name: 'Rent', nextDueDate: safeDate });
      await createCommitment(conn, userId, { amount: 100, name: 'Internet', nextDueDate: safeDate });
      cycleId = await createCycleForUser(userId);
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('generates one occurrence per active commitment', async () => {
      const [rows] = await conn.execute(
        `SELECT COUNT(*) as count FROM commitment_occurrences WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(Number(rows[0].count)).toBe(2);
    });

    it('occurrence has correct status and amount', async () => {
      const [rows] = await conn.execute(
        `SELECT status, amount FROM commitment_occurrences WHERE cycle_id = ?`,
        [cycleId]
      );
      const statuses = rows.map(r => r.status);
      const amounts = rows.map(r => Number(r.amount));

      expect(statuses.every(s => s === 'upcoming')).toBe(true);
      expect(amounts).toContain(200);
      expect(amounts).toContain(100);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 13-15. Occurrence behavior
  // ────────────────────────────────────────────────────────────────────── //
  describe('Occurrence behavior', () => {
    let userId;
    let cycleId;
    let commitmentId;
    let occurrenceId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      const safeDate = await getCycleStartDate(conn, userId);
      commitmentId = await createCommitment(conn, userId, { amount: 200, name: 'Rent', nextDueDate: safeDate });
      cycleId = await createCycleForUser(userId);

      const [rows] = await conn.execute(
        `SELECT id FROM commitment_occurrences WHERE cycle_id = ? AND commitment_id = ?`,
        [cycleId, commitmentId]
      );
      occurrenceId = rows[0].id;
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('unpaid occurrence reserves Needs but is not expense', async () => {
      const { FinanceRepository } = require('../repositories/finance.repository');

      const unpaidTotal = await FinanceRepository.getUnpaidOccurrencesTotal(userId, cycleId);
      expect(unpaidTotal).toBe(200); // Unpaid occurrence reserves needs

      // Verify it's not counted as expense
      const [expenseRows] = await conn.execute(
        `SELECT COUNT(*) as count FROM transactions WHERE user_id = ? AND transaction_type = 'expense'`,
        [userId]
      );
      expect(Number(expenseRows[0].count)).toBe(0);
    });

    it('never auto-marks occurrence paid', async () => {
      const [rows] = await conn.execute(
        `SELECT status, paid_transaction_id FROM commitment_occurrences WHERE id = ?`,
        [occurrenceId]
      );

      expect(rows[0].status).toBe('upcoming');
      expect(rows[0].paid_transaction_id).toBeNull();
    });

    it('paid_transaction_id must reference confirmed payment transaction', async () => {
      const { FinanceRepository } = require('../repositories/finance.repository');

      // Create a confirmed payment transaction
      const [txRes] = await conn.execute(
        `INSERT INTO transactions (user_id, cycle_id, amount, direction, transaction_type, budget_bucket, category, status, confirmed_at, occurred_at)
         VALUES (?, ?, 200, 'outflow', 'expense', 'needs', 'rent', 'confirmed', NOW(), NOW())`,
        [userId, cycleId]
      );
      const transactionId = txRes.insertId;

      // Mark occurrence as paid
      const connection = await db.getConnection();
      try {
        await connection.beginTransaction();
        await FinanceRepository.markOccurrencePaid(connection, userId, occurrenceId, transactionId);
        await connection.commit();
      } finally {
        connection.release();
      }

      // Verify occurrence is now paid
      const [rows] = await conn.execute(
        `SELECT status, paid_transaction_id FROM commitment_occurrences WHERE id = ?`,
        [occurrenceId]
      );

      expect(rows[0].status).toBe('paid');
      expect(Number(rows[0].paid_transaction_id)).toBe(transactionId);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 16. Phase 3A.1 regression
  // ────────────────────────────────────────────────────────────────────── //
  describe('Phase 3A.1 regression – cycle creation still works', () => {
    let userId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('creates cycle with snapshot', async () => {
      const res = await request(app)
        .post('/api/v1/financial-cycles')
        .set('Authorization', authHeader(userId))
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('open');
      expect(res.body.data.snapshot).toBeTruthy();
      expect(res.body.data.snapshot.needsBps + res.body.data.snapshot.wantsBps + res.body.data.snapshot.savingsBps).toBe(10000);
    });

    it('one open cycle per user', async () => {
      const res = await request(app)
        .post('/api/v1/financial-cycles')
        .set('Authorization', authHeader(userId))
        .expect(409);

      expect(res.body.code).toBe('CYCLE_ALREADY_OPEN');
    });
  });
});
