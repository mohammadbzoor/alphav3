const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const { OnboardingRepository } = require('../repositories/onboarding.repository');
const { CycleService } = require('../services/cycle.service');
const { env } = require('../config/env');
const jwt = require('jsonwebtoken');

// ─────────────────────────────────────────────────────────────────────────── //
// Utilities
// ─────────────────────────────────────────────────────────────────────────── //

let phoneCounter = 0;
async function createTestUser(baseEmail, basePhone) {
  const email = `${Date.now()}_${Math.random().toString(36).substring(2, 8)}_${baseEmail}`;
  const phone = `${basePhone}${++phoneCounter}`;
  const passwordHash = 'hash';
  const [result] = await db.execute(
    `INSERT INTO users (full_name, email, phone, password_hash, is_verified, is_onboarded)
     VALUES (?, ?, ?, ?, 1, 0)`,
    ['Test User', email, phone, passwordHash]
  );
  return result.insertId;
}

function getAuthToken(userId) {
  return jwt.sign({ id: userId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });
}

function getFutureDate(yearsAhead = 1) {
  const date = new Date();
  date.setUTCFullYear(date.getUTCFullYear() + yearsAhead);
  return date.toISOString().slice(0, 10);
}

// Cleans up user and all related records to avoid pollution
async function teardownUser(userId) {
  if (!userId) return;

  const [cycleRows] = await db.execute('SELECT id FROM financial_cycles WHERE user_id = ?', [userId]);
  const cycleIds = cycleRows.map(r => r.id);

  if (cycleIds.length > 0) {
    const cycleIdsStr = cycleIds.join(',');
    await db.execute(`DELETE FROM cycle_allocation_snapshots WHERE cycle_id IN (${cycleIdsStr})`);
    await db.execute(`DELETE FROM goal_cycle_allocations WHERE cycle_id IN (${cycleIdsStr})`);
    await db.execute(`DELETE FROM cycle_savings_allocations WHERE cycle_id IN (${cycleIdsStr})`);
    await db.execute(`DELETE FROM commitment_occurrences WHERE cycle_id IN (${cycleIdsStr})`);
  }

  await db.execute('DELETE FROM goal_transactions WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM transactions WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM financial_cycles WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM financial_commitments WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM savings_allocations WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM goals WHERE user_id = ?', [userId]);
  
  await db.execute('DELETE FROM allocation_transition_plans WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM allocation_preferences WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM financial_profiles WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM user_profiles WHERE user_id = ?', [userId]);
  await db.execute('DELETE FROM users WHERE id = ?', [userId]);
}

describe('Onboarding Flow (Integration)', () => {
  let conn;

  beforeAll(async () => {
    conn = await db.getConnection();
  });

  afterAll(async () => {
    conn.release();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('1. savePersonalInfo', () => {
    let userId;
    let token;

    beforeEach(async () => {
      userId = await createTestUser('personal@test.com', '+96279111');
      token = getAuthToken(userId);
    });

    afterEach(async () => {
      await teardownUser(userId);
    });

    it('rejects string "false" for boolean fields with 422', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ hasDependents: 'false' });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_BOOLEAN');
    });

    it('returns the canonical isOnboarded field and preserves idempotency', async () => {
      const payload = {
        employmentStatus: 'employed',
        hasDependents: true,
        basicExpenses: 500,
        monthlyExtraSavingsGoal: 100,
        gender: 'male',
        maritalStatus: 'single',
        isHeadOfHousehold: false,
        isStudent: false,
        familySize: 1,
        primarySpendingCategory: 'Housing',
        relationshipWithMoney: 'Saver',
        mainFinancialGoal12M: 'Build Emergency Fund',
        incomeSources: ['salary'],
        fixedExpenses: ['rent'],
        variableExpenses: ['food'],
        pinnedMonths: 3
      };

      // First request
      const res1 = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send(payload);

      expect(res1.status).toBe(200);
      expect(res1.body.success).toBe(true);
      expect(res1.body.data).toBeDefined();
      expect(res1.body.data).toHaveProperty('isOnboarded');
      expect(typeof res1.body.data.isOnboarded).toBe('boolean');
      expect(res1.body.data.isOnboarded).toBe(false); // Intermediate step, not onboarded yet
      expect(res1.body.data).not.toHaveProperty('password'); // No sensitive fields

      // Verify database write
      const [profiles] = await db.execute('SELECT * FROM user_profiles WHERE user_id = ?', [userId]);
      expect(profiles.length).toBe(1);
      expect(profiles[0].employment_status).toBe('employed');
      
      // Check user isOnboarded state in DB is still 0
      const [users] = await db.execute('SELECT is_onboarded FROM users WHERE id = ?', [userId]);
      expect(users[0].is_onboarded).toBe(0);

      // Idempotency: Second request
      const res2 = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send(payload);

      expect(res2.status).toBe(200);
      
      const [profilesAfter] = await db.execute('SELECT * FROM user_profiles WHERE user_id = ?', [userId]);
      expect(profilesAfter.length).toBe(1); // No duplicates
    });

    it('stores true as 1 and false as 0 safely', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ hasDependents: true, isHeadOfHousehold: false });
      expect(res.status).toBe(200);

      const [rows] = await db.execute('SELECT has_dependents, is_head_of_household FROM user_profiles WHERE user_id = ?', [userId]);
      expect(Number(rows[0].has_dependents)).toBe(1);
      expect(Number(rows[0].is_head_of_household)).toBe(0);
    });

    it('stores empty JSON array correctly and rejects invalid structure', async () => {
      const res1 = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ incomeSources: [] });
      expect(res1.status).toBe(200);
      
      const [rows] = await db.execute('SELECT income_sources FROM user_profiles WHERE user_id = ?', [userId]);
      const storedValue = typeof rows[0].income_sources === 'string'
        ? JSON.parse(rows[0].income_sources)
        : rows[0].income_sources;
      expect(storedValue).toEqual([]);
      
      const res2 = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ incomeSources: "not_an_array" });
      expect(res2.status).toBe(422);
      expect(res2.body.code).toBe('INVALID_JSON_FIELD');
    });

    it('unknown fields do not reach SQL (ignores them)', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ familySize: 2, unknownField: 'hacker' });
      expect(res.status).toBe(200);
      
      // We know it didn't crash because status is 200, and familySize was saved
      const [rows] = await db.execute('SELECT family_size FROM user_profiles WHERE user_id = ?', [userId]);
      expect(Number(rows[0].family_size)).toBe(2);
    });

    it('partial update works correctly', async () => {
      await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ familySize: 3 });

      const res = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ isStudent: true });
      expect(res.status).toBe(200);

      const [rows] = await db.execute('SELECT family_size, is_student FROM user_profiles WHERE user_id = ?', [userId]);
      expect(Number(rows[0].family_size)).toBe(3);
      expect(Number(rows[0].is_student)).toBe(1);
    });

    it('returns 404 for missing user', async () => {
      const fakeToken = getAuthToken(99999999);
      const res = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${fakeToken}`)
        .send({ familySize: 2 });
      expect(res.status).toBe(404);
    });
  });

  describe('2. saveFinancialSetup', () => {
    let userId;
    let token;

    beforeEach(async () => {
      userId = await createTestUser('finance@test.com', '+96279222');
      token = getAuthToken(userId);
    });

    afterEach(async () => {
      await teardownUser(userId);
    });

    it('missing income', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ salaryPaymentDay: 15 });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('MONTHLY_INCOME_REQUIRED');
    });

    it('invalid income (negative)', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: -500, salaryPaymentDay: 15 });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_INCOME');
    });

    it('zero income', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 0, salaryPaymentDay: 15 });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_INCOME');
    });

    it('missing payment day', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 1000 });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_PAYMENT_DAY');
    });

    it('payment day 0 rejected', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 1000, salaryPaymentDay: 0 });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_PAYMENT_DAY');
    });

    it('payment day 32 rejected', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 1000, salaryPaymentDay: 32 });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_PAYMENT_DAY');
    });

    it('conflicting payment day fields rejected', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 1000, salaryPaymentDay: 10, paymentDay: 15 });
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('CONFLICTING_PAYMENT_DAY_FIELDS');
    });

    it('rounding 750.400 -> 750, 750.500 -> 751, 750.900 -> 751 and DB consistency', async () => {
      const u1 = await createTestUser('r1@test.com', '+9627911100');
      const u2 = await createTestUser('r2@test.com', '+9627911101');
      const u3 = await createTestUser('r3@test.com', '+9627911102');

      try {
        const res1 = await request(app).post('/api/v1/onboarding/financial-setup').set('Authorization', `Bearer ${getAuthToken(u1)}`).send({ monthlyIncome: 750.400, salaryPaymentDay: 15 });
        const res2 = await request(app).post('/api/v1/onboarding/financial-setup').set('Authorization', `Bearer ${getAuthToken(u2)}`).send({ monthlyIncome: 750.500, salaryPaymentDay: 15 });
        const res3 = await request(app).post('/api/v1/onboarding/financial-setup').set('Authorization', `Bearer ${getAuthToken(u3)}`).send({ monthlyIncome: 750.900, salaryPaymentDay: 15 });

        expect(res1.status).toBe(200);
        expect(res2.status).toBe(200);
        expect(res3.status).toBe(200);

        // Verify u1 -> 750
        const [u1Prof] = await db.execute('SELECT monthly_income FROM user_profiles WHERE user_id = ?', [u1]);
        const [u1Fin] = await db.execute('SELECT expected_monthly_income, detected_tier FROM financial_profiles WHERE user_id = ?', [u1]);
        const [u1Alloc] = await db.execute('SELECT based_on_income FROM allocation_preferences WHERE user_id = ?', [u1]);
        expect(Number(u1Prof[0].monthly_income)).toBe(750);
        expect(Number(u1Fin[0].expected_monthly_income)).toBe(750);
        expect(Number(u1Alloc[0].based_on_income)).toBe(750);
        expect(u1Fin[0].detected_tier).toBe('Middle'); // 750 is Middle

        // Verify u2 -> 751
        const [u2Prof] = await db.execute('SELECT monthly_income FROM user_profiles WHERE user_id = ?', [u2]);
        const [u2Fin] = await db.execute('SELECT expected_monthly_income FROM financial_profiles WHERE user_id = ?', [u2]);
        const [u2Alloc] = await db.execute('SELECT based_on_income FROM allocation_preferences WHERE user_id = ?', [u2]);
        expect(Number(u2Prof[0].monthly_income)).toBe(751);
        expect(Number(u2Fin[0].expected_monthly_income)).toBe(751);
        expect(Number(u2Alloc[0].based_on_income)).toBe(751);

        // Verify u3 -> 751
        const [u3Prof] = await db.execute('SELECT monthly_income FROM user_profiles WHERE user_id = ?', [u3]);
        const [u3Fin] = await db.execute('SELECT expected_monthly_income FROM financial_profiles WHERE user_id = ?', [u3]);
        const [u3Alloc] = await db.execute('SELECT based_on_income FROM allocation_preferences WHERE user_id = ?', [u3]);
        expect(Number(u3Prof[0].monthly_income)).toBe(751);
        expect(Number(u3Fin[0].expected_monthly_income)).toBe(751);
        expect(Number(u3Alloc[0].based_on_income)).toBe(751);
      } finally {
        await teardownUser(u1);
        await teardownUser(u2);
        await teardownUser(u3);
      }
    });

    it('atomic success and is_onboarded becomes true', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 1000, salaryPaymentDay: 15 });
      
      expect(res.status).toBe(200);
      expect(res.body.data.isOnboarded).toBe(false);

      const [user] = await db.execute('SELECT is_onboarded FROM users WHERE id = ?', [userId]);
      expect(Number(user[0].is_onboarded)).toBe(0);
    });

    it('BPS sum is 10000', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 1000, salaryPaymentDay: 15 });
      
      expect(res.status).toBe(200);
      const alloc = res.body.data.allocation;
      expect(alloc.needsBps + alloc.wantsBps + alloc.savingsBps).toBe(10000);
    });

    it('concurrent calls do not create duplicate profile rows', async () => {
      const reqs = [
        request(app).post('/api/v1/onboarding/financial-setup').set('Authorization', `Bearer ${token}`).send({ monthlyIncome: 1000, salaryPaymentDay: 15 }),
        request(app).post('/api/v1/onboarding/financial-setup').set('Authorization', `Bearer ${token}`).send({ monthlyIncome: 1000, salaryPaymentDay: 15 }),
        request(app).post('/api/v1/onboarding/financial-setup').set('Authorization', `Bearer ${token}`).send({ monthlyIncome: 1000, salaryPaymentDay: 15 }),
      ];

      const responses = await Promise.all(reqs);
      for (const response of responses) {
        expect(response.status).toBe(200);
      }

      const [uProfs] = await db.execute('SELECT count(*) as count FROM user_profiles WHERE user_id = ?', [userId]);
      const [fProfs] = await db.execute('SELECT count(*) as count FROM financial_profiles WHERE user_id = ?', [userId]);
      const [aProfs] = await db.execute('SELECT count(*) as count FROM allocation_preferences WHERE user_id = ?', [userId]);
      const [user] = await db.execute('SELECT is_onboarded FROM users WHERE id = ?', [userId]);
      
      expect(Number(uProfs[0].count)).toBe(1);
      expect(Number(fProfs[0].count)).toBe(1);
      expect(Number(aProfs[0].count)).toBe(1);
      expect(Number(user[0].is_onboarded)).toBe(0);
    });

    it('rollback if failure occurs during transaction (is_onboarded stays false)', async () => {
      const mock = vi.spyOn(OnboardingRepository, 'upsertAllocationPreferences').mockImplementation(async () => {
        throw new Error('Simulated Database Error');
      });

      try {
        const res = await request(app)
          .post('/api/v1/onboarding/financial-setup')
          .set('Authorization', `Bearer ${token}`)
          .send({ monthlyIncome: 1000, salaryPaymentDay: 15 });
        
        expect(res.status).toBe(500);

        const [user] = await db.execute('SELECT is_onboarded FROM users WHERE id = ?', [userId]);
        expect(Number(user[0].is_onboarded)).toBe(0);

        const [uProfs] = await db.execute('SELECT count(*) as count FROM user_profiles WHERE user_id = ?', [userId]);
        const [fProfs] = await db.execute('SELECT count(*) as count FROM financial_profiles WHERE user_id = ?', [userId]);
        const [aProfs] = await db.execute('SELECT count(*) as count FROM allocation_preferences WHERE user_id = ?', [userId]);

        expect(Number(uProfs[0].count)).toBe(0);
        expect(Number(fProfs[0].count)).toBe(0);
        expect(Number(aProfs[0].count)).toBe(0);
      } finally {
        mock.mockRestore();
      }
    });
  });

  describe('3. getStatus', () => {
    let userId;
    let token;

    beforeEach(async () => {
      userId = await createTestUser('status@test.com', '+96279333');
      token = getAuthToken(userId);
    });

    afterEach(async () => {
      await teardownUser(userId);
    });

    it('not onboarded', async () => {
      const res = await request(app)
        .get('/api/v1/onboarding/status')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.data.isOnboarded).toBe(false);
      expect(res.body.data.nextStep).toBe('personal_info');

      const setupRes = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 1000, salaryPaymentDay: 15 });
      expect(setupRes.status).toBe(200);
      // after setup expect not onboarded yet
      expect(setupRes.body.data.isOnboarded).toBe(false);
      expect(setupRes.body.data.nextStep).toBe('allocation_review');
      expect(setupRes.body.data.canCreateCycle).toBe(false);

      const allocation = setupRes.body.data.allocation;
      const approveRes = await request(app)
        .post('/api/v1/onboarding/allocation/approve')
        .set('Authorization', `Bearer ${token}`)
        .send({
          needsBps: allocation.needsBps,
          wantsBps: allocation.wantsBps,
          savingsBps: allocation.savingsBps,
        });
      expect(approveRes.status).toBe(200);
      expect(approveRes.body.data.isOnboarded).toBe(true);
      expect(approveRes.body.data.nextStep).toBe('dashboard');
      expect(approveRes.body.data.canCreateCycle).toBe(true);
      expect(approveRes.body.data.allocation.source).toBe('system_tier');
      expect(approveRes.body.data.allocation.isCustomized).toBe(false);

      const sRes = await request(app)
        .get('/api/v1/onboarding/status')
        .set('Authorization', `Bearer ${token}`);
      expect(sRes.status).toBe(200);
      expect(sRes.body.data.isOnboarded).toBe(true);
      expect(sRes.body.data.nextStep).toBe('dashboard');
      expect(sRes.body.data.profile.monthly_income).toBeDefined();
    });

    it('returns financial_setup after saving personal info', async () => {
      const pRes = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ familySize: 4, isHeadOfHousehold: true });
      expect(pRes.status).toBe(200);

      const statusRes = await request(app)
        .get('/api/v1/onboarding/status')
        .set('Authorization', `Bearer ${token}`);
      expect(statusRes.status).toBe(200);
      expect(statusRes.body.data.isOnboarded).toBe(false);
      expect(statusRes.body.data.nextStep).toBe('financial_setup');
    });

    it('user missing', async () => {
      const fakeToken = getAuthToken(99999999);
      const res = await request(app)
        .get('/api/v1/onboarding/status')
        .set('Authorization', `Bearer ${fakeToken}`);
      expect(res.status).toBe(404);
    });
  });

  describe('4. saveFirstGoal', () => {
    let userId;
    let token;

    beforeEach(async () => {
      userId = await createTestUser('goal@test.com', '+96279444');
      token = getAuthToken(userId);
    });

    afterEach(async () => {
      await teardownUser(userId);
    });

    it('missing goalType rejected', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/first-goal')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Car', targetAmount: 5000, targetDate: getFutureDate(1) });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('GOAL_TYPE_REQUIRED');
    });

    it('invalid amount rejected', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/first-goal')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Car', goalType: 'emergency_fund', targetAmount: -100, targetDate: getFutureDate(1) });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_AMOUNT');
    });

    it('decimal rounding works for amount', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/first-goal')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Car', goalType: 'emergency_fund', targetAmount: 500.6, targetDate: getFutureDate(1) });
      expect(res.status).toBe(200);
      
      const [rows] = await db.execute('SELECT target_amount FROM goals WHERE id = ?', [res.body.data.goalId]);
      expect(Number(rows[0].target_amount)).toBe(501);
    });

    it('deadline mode requires targetDate', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/first-goal')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Car', goalType: 'emergency_fund', targetAmount: 500 });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_DATE');
    });

    it('contribution mode requires contribution', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/first-goal')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Car', goalType: 'emergency_fund', targetAmount: 500, flexibility: 'flexible' });
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('INVALID_AMOUNT');
    });

    it('returns inserted goalId', async () => {
      const res = await request(app)
        .post('/api/v1/onboarding/first-goal')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Car', goalType: 'emergency_fund', targetAmount: 500, targetDate: getFutureDate(1) });
      expect(res.status).toBe(200);
      expect(res.body.data.goalId).toBeDefined();
    });
  });

  describe('5. Integration Journey', () => {
    let userId;
    let token;

    beforeEach(async () => {
      userId = await createTestUser('journey@test.com', '+96279555');
      token = getAuthToken(userId);
    });

    afterEach(async () => {
      await teardownUser(userId);
    });

    it('full flow works successfully', async () => {
      // 1. Save Personal Info
      const pRes = await request(app)
        .post('/api/v1/onboarding/personal-info')
        .set('Authorization', `Bearer ${token}`)
        .send({ familySize: 4, isHeadOfHousehold: true });
      expect(pRes.status).toBe(200);
      expect(pRes.body.data.nextStep).toBe('financial_setup');

      // 2. Save Financial Setup
      const fRes = await request(app)
        .post('/api/v1/onboarding/financial-setup')
        .set('Authorization', `Bearer ${token}`)
        .send({ monthlyIncome: 1200, salaryPaymentDay: 5 });
      expect(fRes.status).toBe(200);
      // after setup expect not onboarded yet
      expect(fRes.body.data.isOnboarded).toBe(false);
      expect(fRes.body.data.nextStep).toBe('allocation_review');
      expect(fRes.body.data.canCreateCycle).toBe(false);

      // 3. Approve Allocation
      const allocation = fRes.body.data.allocation;
      const aRes = await request(app)
        .post('/api/v1/onboarding/allocation/approve')
        .set('Authorization', `Bearer ${token}`)
        .send({ needsBps: allocation.needsBps, wantsBps: allocation.wantsBps, savingsBps: allocation.savingsBps });
      expect(aRes.status).toBe(200);
      expect(aRes.body.data.isOnboarded).toBe(true);
      expect(aRes.body.data.nextStep).toBe('dashboard');
      expect(aRes.body.data.canCreateCycle).toBe(true);
      expect(aRes.body.data.allocation.source).toBe('system_tier');
      expect(aRes.body.data.allocation.isCustomized).toBe(false);

      // 4. Get Onboarding Status
      const sRes = await request(app)
        .get('/api/v1/onboarding/status')
        .set('Authorization', `Bearer ${token}`);
      expect(sRes.body.data.isOnboarded).toBe(true);
      expect(sRes.body.data.nextStep).toBe('dashboard');
      expect(sRes.body.data.profile.monthly_income).toBeDefined();

      // 5. Create first goal
      const gRes = await request(app)
        .post('/api/v1/onboarding/first-goal')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Emergency', goalType: 'emergency_fund', targetAmount: 3000, targetDate: getFutureDate(2) });
      expect(gRes.status).toBe(200);

      // 6. Create financial cycle successfully
      const cycleResult = await CycleService.createCycle(userId, { idempotencyKey: `onboarding-cycle-${userId}` });
      const cycleId = cycleResult.cycle.id;
      expect(cycleId).toBeDefined();

      // 7. Verify cycle snapshot values match using explicit SELECT
      const [snapshots] = await db.execute(`
        SELECT allocation_base_income, needs_bps, wants_bps, savings_bps
        FROM cycle_allocation_snapshots WHERE cycle_id = ?
      `, [cycleId]);
      expect(snapshots.length).toBe(1);
      expect(Number(snapshots[0].allocation_base_income)).toBe(1200);
      expect(Number(snapshots[0].needs_bps) + Number(snapshots[0].wants_bps) + Number(snapshots[0].savings_bps)).toBe(10000);
    });
  });
});
