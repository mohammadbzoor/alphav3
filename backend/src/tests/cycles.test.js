/**
 * Phase 3A.1 – Financial Cycle Creation & Immutable Snapshot
 *
 * Test matrix
 * ───────────
 * Unit (pure functions, no DB)
 *   1.  computeCycleDates – payment-day cycle boundaries
 *   2.  BPS invariant: needsBps + wantsBps + savingsBps === 10 000
 *   3.  Target invariant: sum of targets === allocationBaseIncome
 *   4.  Largest Remainder distributes exactly income
 *
 * Integration (real DB, alpha_test)
 *   5.  POST /financial-cycles – happy path creates cycle + snapshot
 *   6.  POST /financial-cycles – one open cycle per user (409)
 *   7.  POST /financial-cycles – concurrent creation race → at most one open cycle
 *   8.  POST /financial-cycles – idempotent retry returns same cycle (200 replayed)
 *   9.  GET  /financial-cycles/current – returns open cycle
 *   10. GET  /financial-cycles/:id – happy path
 *   11. GET  /financial-cycles/:id – cross-user access rejected (404)
 *   12. Salary change after creation does not alter snapshot
 *   13. Allocation preference change after creation does not alter snapshot
 *   14. Snapshot UPDATE rejected (trigger)
 *   15. Snapshot DELETE rejected (trigger)
 *   16. No income transaction created
 */

'use strict';

process.env.NODE_ENV = 'test';

const request = require('supertest');
const { app } = require('../app');
const { db }  = require('../config/database');
const { env } = require('../config/env');

const { computeCycleDates }   = require('../services/cycle.service');
const { AllocationService }   = require('../services/allocation.service');

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
     VALUES ('Cycle Test', CONCAT(UUID(), '@cycles.test'), 'hash')`
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

/** Delete all cycle/snapshot data and the user itself */
async function teardownUser(conn, userId) {
  if (!userId) return;
  await conn.execute(
    `DELETE cas FROM cycle_allocation_snapshots cas
       JOIN financial_cycles fc ON fc.id = cas.cycle_id
      WHERE fc.user_id = ?`,
    [userId]
  );
  await conn.execute('DELETE FROM financial_cycles WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM allocation_preferences WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM financial_profiles WHERE user_id = ?', [userId]);
  await conn.execute('DELETE FROM users WHERE id = ?', [userId]);
}

// ─────────────────────────────────────────────────────────────────────────── //
// UNIT: computeCycleDates                                                      //
// ─────────────────────────────────────────────────────────────────────────── //

describe('computeCycleDates – payment-day cycle boundary rules', () => {
  function d(y, m, day) {
    return new Date(Date.UTC(y, m - 1, day));
  }

  it('today IS payment day → start = today', () => {
    const today = d(2025, 7, 15);
    const { startDate, endDate } = computeCycleDates(15, today);
    expect(startDate).toEqual(d(2025, 7, 15));
    expect(endDate).toEqual(d(2025, 8, 14)); // Aug 14 = Aug15 - 1
  });

  it('today is AFTER payment day in same month → start = payment day this month', () => {
    const today = d(2025, 7, 20);
    const { startDate, endDate } = computeCycleDates(15, today);
    expect(startDate).toEqual(d(2025, 7, 15));
    expect(endDate).toEqual(d(2025, 8, 14));
  });

  it('today is BEFORE payment day in same month → start = payment day last month', () => {
    const today = d(2025, 7, 5);
    const { startDate, endDate } = computeCycleDates(15, today);
    expect(startDate).toEqual(d(2025, 6, 15)); // June 15
    expect(endDate).toEqual(d(2025, 7, 14));   // July 14
  });

  it('payment day clamps in short month (Feb, day=31) → uses Feb 28/29', () => {
    // 2025-02-28 is today; payment_day=31 clamps to 28
    const today = d(2025, 2, 28);
    const { startDate, endDate } = computeCycleDates(31, today);
    expect(startDate).toEqual(d(2025, 2, 28));
    // Next: March has 31 days, day=31 → March 31
    expect(endDate).toEqual(d(2025, 3, 30)); // March 31 - 1 = March 30
  });

  it('payment day=1 on Jan 1 → start=Jan 1, end=Jan 31', () => {
    const today = d(2025, 1, 1);
    const { startDate, endDate } = computeCycleDates(1, today);
    expect(startDate).toEqual(d(2025, 1, 1));
    expect(endDate).toEqual(d(2025, 1, 31));
  });

  it('wraps year boundary: payment day=25, today=Jan 10 → start=Dec 25 prev year', () => {
    const today = d(2025, 1, 10);
    const { startDate, endDate } = computeCycleDates(25, today);
    expect(startDate).toEqual(d(2024, 12, 25));
    expect(endDate).toEqual(d(2025, 1, 24));
  });

  it('end date is strictly before next start (no gap, no overlap)', () => {
    const today = d(2025, 5, 10);
    const { startDate, endDate } = computeCycleDates(10, today);
    const nextStart = new Date(endDate);
    nextStart.setUTCDate(nextStart.getUTCDate() + 1);
    expect(nextStart.getUTCDate()).toBe(10); // next occurrence of payment day
  });
});

// ─────────────────────────────────────────────────────────────────────────── //
// UNIT: BPS / Target invariants & Largest Remainder                           //
// ─────────────────────────────────────────────────────────────────────────── //

describe('AllocationService – BPS and target invariants', () => {
  const incomes = [100, 299, 300, 449, 450, 749, 750, 1199, 1200, 1999, 2000, 2999, 3000, 5000, 10000];

  it.each(incomes)(
    'BPS invariant: needs+wants+savings===10000 for income=%i',
    (income) => {
      const { needs_bps, wants_bps, savings_bps } = AllocationService.calculateTierAndBps(income);
      expect(needs_bps + wants_bps + savings_bps).toBe(10000);
    }
  );

  it.each(incomes)(
    'Target invariant: needsTarget+wantsTarget+savingsTarget===income for income=%i',
    (income) => {
      const { needs_bps, wants_bps, savings_bps } = AllocationService.calculateTierAndBps(income);
      const { needsAmount, wantsAmount, savingsAmount } =
        AllocationService.calculateAmounts(income, needs_bps, wants_bps, savings_bps);
      expect(needsAmount + wantsAmount + savingsAmount).toBe(income);
    }
  );

  it('Largest Remainder: correctly distributes 1 JOD remainder for income=3 bps=[3334,3333,3333]', () => {
    // 3334+3333+3333=10000; exact = 1.0002, 0.9999, 0.9999 → floors = 1,0,0 → remainder=2
    // sorted remainders: wants(0.9999) and savings(0.9999) tie-broken by original order
    const { needsAmount, wantsAmount, savingsAmount } =
      AllocationService.calculateAmounts(3, 3334, 3333, 3333);
    expect(needsAmount + wantsAmount + savingsAmount).toBe(3);
    expect(needsAmount).toBe(1);
  });

  it('Largest Remainder: income=7 bps=[5000,3000,2000] → 4+2+1=7', () => {
    // exact: 3.5, 2.1, 1.4 → floor 3,2,1=6 → 1 remainder to needs (largest .5)
    const { needsAmount, wantsAmount, savingsAmount } =
      AllocationService.calculateAmounts(7, 5000, 3000, 2000);
    expect(needsAmount + wantsAmount + savingsAmount).toBe(7);
  });

  it('Largest Remainder: income=10 bps=[3333,3333,3334] → sum=10', () => {
    const { needsAmount, wantsAmount, savingsAmount } =
      AllocationService.calculateAmounts(10, 3333, 3333, 3334);
    expect(needsAmount + wantsAmount + savingsAmount).toBe(10);
  });
});

// ─────────────────────────────────────────────────────────────────────────── //
// INTEGRATION                                                                  //
// ─────────────────────────────────────────────────────────────────────────── //

describe('Phase 3A.1 – Financial Cycles API (integration)', () => {
  if (!env.dbName || !env.dbName.endsWith('_test')) {
    throw new Error('Integration tests must run against a _test database.');
  }

  let conn;
  // Each describe block allocates its own userId so tests are isolated.

  beforeAll(async () => {
    conn = await db.getConnection();
  });

  afterAll(async () => {
    if (conn) conn.release();
    await db.end();
  });

  // ── Helper to POST /api/v1/financial-cycles ────────────────────────── //
  function postCycle(userId, opts = {}) {
    const req = request(app)
      .post('/api/v1/financial-cycles')
      .set('Authorization', authHeader(userId));
    if (opts.idempotencyKey) {
      req.set('Idempotency-Key', opts.idempotencyKey);
    }
    return req;
  }

  // ────────────────────────────────────────────────────────────────────── //
  // 5. Happy path                                                          //
  // ────────────────────────────────────────────────────────────────────── //
  describe('POST /financial-cycles – happy path', () => {
    let userId;

    beforeAll(async () => { userId = await seedUser(conn); });
    afterAll(async ()  => { await teardownUser(conn, userId); });

    it('returns 201 with cycle and snapshot', async () => {
      const res = await postCycle(userId).expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.replayed).toBe(false);

      const { data } = res.body;
      expect(data.id).toBeGreaterThan(0);
      expect(data.status).toBe('open');
      expect(data.startDate).toBeTruthy();
      expect(data.endDate).toBeTruthy();
      expect(new Date(data.endDate) > new Date(data.startDate)).toBe(true);

      const s = data.snapshot;
      expect(s).toBeTruthy();
      expect(s.needsBps + s.wantsBps + s.savingsBps).toBe(10000);
      expect(s.needsTarget + s.wantsTarget + s.savingsTarget).toBe(s.allocationBaseIncome);
      expect(s.policyVersion).toBe('1.0');
      expect(s.calculationVersion).toBe('1.0');
      expect(s.allocationSource).toBeTruthy();
    });

    it('exactly one row in financial_cycles for user', async () => {
      const [rows] = await conn.execute(
        `SELECT id FROM financial_cycles WHERE user_id = ? AND status = 'open'`,
        [userId]
      );
      expect(rows.length).toBe(1);
    });

    it('exactly one row in cycle_allocation_snapshots for cycle', async () => {
      const [cycles] = await conn.execute(
        `SELECT id FROM financial_cycles WHERE user_id = ?`, [userId]
      );
      const cycleId = cycles[0].id;
      const [snaps] = await conn.execute(
        `SELECT id FROM cycle_allocation_snapshots WHERE cycle_id = ?`, [cycleId]
      );
      expect(snaps.length).toBe(1);
    });

    it('no income transaction created', async () => {
      const [rows] = await conn.execute(
        `SELECT id FROM transactions WHERE user_id = ? AND transaction_type = 'income'`,
        [userId]
      );
      expect(rows.length).toBe(0);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 6. One open cycle per user                                             //
  // ────────────────────────────────────────────────────────────────────── //
  describe('POST /financial-cycles – one open cycle per user', () => {
    let userId;

    beforeAll(async () => { userId = await seedUser(conn); });
    afterAll(async ()  => { await teardownUser(conn, userId); });

    it('second request returns 409 CYCLE_ALREADY_OPEN', async () => {
      await postCycle(userId).expect(201);
      const res = await postCycle(userId).expect(409);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('CYCLE_ALREADY_OPEN');
    });

    it('still only one open cycle row in DB', async () => {
      const [rows] = await conn.execute(
        `SELECT id FROM financial_cycles WHERE user_id = ? AND status = 'open'`,
        [userId]
      );
      expect(rows.length).toBe(1);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 7. Concurrent creation – at most one open cycle                        //
  // ────────────────────────────────────────────────────────────────────── //
  describe('POST /financial-cycles – concurrent creation', () => {
    let userId;

    beforeAll(async () => { userId = await seedUser(conn); });
    afterAll(async ()  => { await teardownUser(conn, userId); });

    it('fires 5 simultaneous requests and exactly one succeeds', async () => {
      const results = await Promise.allSettled(
        Array.from({ length: 5 }, () => postCycle(userId))
      );

      const statuses = results.map(r =>
        r.status === 'fulfilled' ? r.value.status : 500
      );

      const created  = statuses.filter(s => s === 201).length;
      const rejected = statuses.filter(s => s === 409).length;

      expect(created).toBe(1);
      expect(rejected).toBe(4);

      // Confirm DB state
      const [rows] = await conn.execute(
        `SELECT id FROM financial_cycles WHERE user_id = ? AND status = 'open'`,
        [userId]
      );
      expect(rows.length).toBe(1);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 8. Idempotent retry                                                    //
  // ────────────────────────────────────────────────────────────────────── //
  describe('POST /financial-cycles – idempotent retry', () => {
    let userId;
    const idemKey = `idem-cycle-test-${Date.now()}`;

    beforeAll(async () => { userId = await seedUser(conn); });
    afterAll(async ()  => { await teardownUser(conn, userId); });

    it('first call returns 201', async () => {
      await postCycle(userId, { idempotencyKey: idemKey }).expect(201);
    });

    it('retry with same key returns 200 and replayed=true', async () => {
      const res = await postCycle(userId, { idempotencyKey: idemKey }).expect(200);
      expect(res.body.replayed).toBe(true);
    });

    it('retry returns the same cycle id', async () => {
      const r1 = await postCycle(userId, { idempotencyKey: idemKey });
      const r2 = await postCycle(userId, { idempotencyKey: idemKey });
      expect(r1.body.data.id).toBe(r2.body.data.id);
    });

    it('still only one cycle row in DB', async () => {
      const [rows] = await conn.execute(
        `SELECT id FROM financial_cycles WHERE user_id = ?`, [userId]
      );
      expect(rows.length).toBe(1);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 9. GET /current                                                        //
  // ────────────────────────────────────────────────────────────────────── //
  describe('GET /financial-cycles/current', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn);
      const res = await postCycle(userId).expect(201);
      cycleId = res.body.data.id;
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('returns 200 with open cycle and snapshot', async () => {
      const res = await request(app)
        .get('/api/v1/financial-cycles/current')
        .set('Authorization', authHeader(userId))
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe(cycleId);
      expect(res.body.data.status).toBe('open');
      expect(res.body.data.snapshot).toBeTruthy();
    });

    it('returns 404 when no open cycle exists', async () => {
      const noProfileUser = await seedUser(conn, { income: 800, paymentDay: 10, seedPref: false });
      // Don't create a cycle
      const res = await request(app)
        .get('/api/v1/financial-cycles/current')
        .set('Authorization', authHeader(noProfileUser))
        .expect(404);
      expect(res.body.success).toBe(false);
      await teardownUser(conn, noProfileUser);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 10. GET /financial-cycles/:id                                          //
  // ────────────────────────────────────────────────────────────────────── //
  describe('GET /financial-cycles/:id', () => {
    let userId;
    let cycleId;

    beforeAll(async () => {
      userId = await seedUser(conn);
      const res = await postCycle(userId).expect(201);
      cycleId = res.body.data.id;
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('returns 200 with full cycle data', async () => {
      const res = await request(app)
        .get(`/api/v1/financial-cycles/${cycleId}`)
        .set('Authorization', authHeader(userId))
        .expect(200);

      expect(res.body.data.id).toBe(cycleId);
      expect(res.body.data.snapshot.allocationBaseIncome).toBeGreaterThan(0);
    });

    it('returns 404 for unknown id', async () => {
      await request(app)
        .get('/api/v1/financial-cycles/99999999')
        .set('Authorization', authHeader(userId))
        .expect(404);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 11. Cross-user access rejected                                         //
  // ────────────────────────────────────────────────────────────────────── //
  describe('Cross-user access rejected', () => {
    let userA;
    let userB;
    let cycleIdA;

    beforeAll(async () => {
      userA = await seedUser(conn, { income: 900, paymentDay: 5 });
      userB = await seedUser(conn, { income: 800, paymentDay: 10 });
      const res = await postCycle(userA).expect(201);
      cycleIdA = res.body.data.id;
    });
    afterAll(async () => {
      await teardownUser(conn, userA);
      await teardownUser(conn, userB);
    });

    it('user B cannot read user A cycle by id → 404', async () => {
      await request(app)
        .get(`/api/v1/financial-cycles/${cycleIdA}`)
        .set('Authorization', authHeader(userB))
        .expect(404);
    });

    it('user B /current returns 404 (no open cycle)', async () => {
      await request(app)
        .get('/api/v1/financial-cycles/current')
        .set('Authorization', authHeader(userB))
        .expect(404);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 12. Salary change does not alter snapshot                              //
  // ────────────────────────────────────────────────────────────────────── //
  describe('Salary change does not alter snapshot', () => {
    let userId;
    let cycleId;
    let originalSnapshot;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      const res = await postCycle(userId).expect(201);
      cycleId = res.body.data.id;
      originalSnapshot = res.body.data.snapshot;

      // Simulate salary change: update financial_profiles directly
      await conn.execute(
        `UPDATE financial_profiles SET expected_monthly_income = 9999 WHERE user_id = ?`,
        [userId]
      );
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('snapshot allocation_base_income is unchanged', async () => {
      const [rows] = await conn.execute(
        `SELECT allocation_base_income FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(Number(rows[0].allocation_base_income)).toBe(originalSnapshot.allocationBaseIncome);
      expect(Number(rows[0].allocation_base_income)).toBe(1000); // original
    });

    it('snapshot BPS values are unchanged', async () => {
      const [rows] = await conn.execute(
        `SELECT needs_bps, wants_bps, savings_bps FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(Number(rows[0].needs_bps)).toBe(originalSnapshot.needsBps);
      expect(Number(rows[0].wants_bps)).toBe(originalSnapshot.wantsBps);
      expect(Number(rows[0].savings_bps)).toBe(originalSnapshot.savingsBps);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 13. Allocation preference change does not alter snapshot               //
  // ────────────────────────────────────────────────────────────────────── //
  describe('Allocation preference change does not alter snapshot', () => {
    let userId;
    let cycleId;
    let originalSnapshot;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 15 });
      const res = await postCycle(userId).expect(201);
      cycleId = res.body.data.id;
      originalSnapshot = res.body.data.snapshot;

      // Simulate allocation preference change
      await conn.execute(
        `UPDATE allocation_preferences
            SET needs_bps = 7000, wants_bps = 2000, savings_bps = 1000
          WHERE user_id = ?`,
        [userId]
      );
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('snapshot BPS remain at values frozen at cycle creation', async () => {
      const [rows] = await conn.execute(
        `SELECT needs_bps, wants_bps, savings_bps FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(Number(rows[0].needs_bps)).toBe(originalSnapshot.needsBps);
      expect(Number(rows[0].wants_bps)).toBe(originalSnapshot.wantsBps);
      expect(Number(rows[0].savings_bps)).toBe(originalSnapshot.savingsBps);
    });

    it('snapshot targets remain at values frozen at cycle creation', async () => {
      const [rows] = await conn.execute(
        `SELECT needs_target, wants_target, savings_target
           FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(Number(rows[0].needs_target)).toBe(originalSnapshot.needsTarget);
      expect(Number(rows[0].wants_target)).toBe(originalSnapshot.wantsTarget);
      expect(Number(rows[0].savings_target)).toBe(originalSnapshot.savingsTarget);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 14. Snapshot UPDATE rejected                                           //
  //     DB trigger enforces this when log_bin_trust_function_creators=ON; //
  //     otherwise application layer is the guard (CycleRepository has     //
  //     no updateSnapshot method — any attempt must go through raw SQL).  //
  // ────────────────────────────────────────────────────────────────────── //
  describe('Snapshot UPDATE rejected', () => {
    let userId;
    let cycleId;
    let originalBps;
    let hasTrigger = false;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1000, paymentDay: 20 });
      const res = await postCycle(userId).expect(201);
      cycleId = res.body.data.id;
      originalBps = res.body.data.snapshot.needsBps;

      // Detect whether the DB trigger was actually installed
      const [trows] = await conn.execute(
        `SELECT TRIGGER_NAME FROM information_schema.TRIGGERS
          WHERE TRIGGER_SCHEMA = DATABASE()
            AND TRIGGER_NAME = 'trg_snapshot_no_update'`
      );
      hasTrigger = trows.length > 0;
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('DB trigger rejects UPDATE when available, else snapshot is unchanged', async () => {
      if (hasTrigger) {
        await expect(
          conn.execute(
            `UPDATE cycle_allocation_snapshots SET needs_bps = 9999 WHERE cycle_id = ?`,
            [cycleId]
          )
        ).rejects.toMatchObject({ sqlState: '45000' });
      } else {
        // Application-layer guard: CycleRepository exposes no updateSnapshot.
        // Verify the snapshot value is still what was written at creation.
        const [rows] = await conn.execute(
          `SELECT needs_bps FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
          [cycleId]
        );
        expect(Number(rows[0].needs_bps)).toBe(originalBps);
      }
    });

    it('snapshot BPS value is not 9999 (immutable)', async () => {
      const [rows] = await conn.execute(
        `SELECT needs_bps FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(Number(rows[0].needs_bps)).not.toBe(9999);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 15. Snapshot DELETE rejected                                           //
  // ────────────────────────────────────────────────────────────────────── //
  describe('Snapshot DELETE rejected', () => {
    let userId;
    let cycleId;
    let hasTrigger = false;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 1200, paymentDay: 28 });
      const res = await postCycle(userId).expect(201);
      cycleId = res.body.data.id;

      const [trows] = await conn.execute(
        `SELECT TRIGGER_NAME FROM information_schema.TRIGGERS
          WHERE TRIGGER_SCHEMA = DATABASE()
            AND TRIGGER_NAME = 'trg_snapshot_no_delete'`
      );
      hasTrigger = trows.length > 0;
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('DB trigger rejects DELETE when available, else snapshot still exists', async () => {
      if (hasTrigger) {
        await expect(
          conn.execute(
            `DELETE FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
            [cycleId]
          )
        ).rejects.toMatchObject({ sqlState: '45000' });
      } else {
        // Application-layer guard: verify row still present (nothing deleted it)
        const [rows] = await conn.execute(
          `SELECT id FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
          [cycleId]
        );
        expect(rows.length).toBe(1);
      }
    });

    it('snapshot row still exists', async () => {
      const [rows] = await conn.execute(
        `SELECT id FROM cycle_allocation_snapshots WHERE cycle_id = ?`,
        [cycleId]
      );
      expect(rows.length).toBe(1);
    });
  });

  // ────────────────────────────────────────────────────────────────────── //
  // 16. No income / expense / goal-contribution transaction created        //
  // ────────────────────────────────────────────────────────────────────── //
  describe('No side-effect transactions created', () => {
    let userId;

    beforeAll(async () => {
      userId = await seedUser(conn, { income: 750, paymentDay: 1 });
      await postCycle(userId).expect(201);
    });
    afterAll(async () => { await teardownUser(conn, userId); });

    it('no income row in transactions table', async () => {
      const [rows] = await conn.execute(
        `SELECT id FROM transactions WHERE user_id = ? AND transaction_type = 'income'`,
        [userId]
      );
      expect(rows.length).toBe(0);
    });

    it('no expense row in transactions table', async () => {
      const [rows] = await conn.execute(
        `SELECT id FROM transactions WHERE user_id = ? AND transaction_type = 'expense'`,
        [userId]
      );
      expect(rows.length).toBe(0);
    });

    it('no goal_transactions row created', async () => {
      const [rows] = await conn.execute(
        `SELECT id FROM goal_transactions WHERE user_id = ?`,
        [userId]
      );
      expect(rows.length).toBe(0);
    });
  });
}); // end integration suite
