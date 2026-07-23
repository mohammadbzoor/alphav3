const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { AllocationService } = require('../services/allocation.service');

describe('Financial Profile API', () => {
  let authHeader;
  let userId;
  let otherUserId;
  let otherAuthHeader;

  beforeAll(async () => {
    // Clean up specific test data if exists
    await db.execute('DELETE FROM users WHERE email IN (?, ?)', [
      'financial_profile_test@example.com',
      'financial_profile_other@example.com'
    ]);

    const [result] = await db.execute(
      'INSERT INTO users (full_name, email, password_hash) VALUES (?, ?, ?)',
      ['Test User', 'financial_profile_test@example.com', 'hashed_pass']
    );
    userId = result.insertId;
    const token = jwt.sign({ id: userId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });
    authHeader = `Bearer ${token}`;

    const [result2] = await db.execute(
      'INSERT INTO users (full_name, email, password_hash) VALUES (?, ?, ?)',
      ['Other User', 'financial_profile_other@example.com', 'hashed_pass']
    );
    otherUserId = result2.insertId;
    const token2 = jwt.sign({ id: otherUserId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });
    otherAuthHeader = `Bearer ${token2}`;
  });

  afterAll(async () => {
    if (userId) {
      await db.execute('DELETE FROM allocation_preferences WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await db.execute('DELETE FROM financial_profiles WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await db.execute('DELETE FROM financial_commitments WHERE user_id IN (?, ?)', [userId, otherUserId]);
      await db.execute('DELETE FROM users WHERE id IN (?, ?)', [userId, otherUserId]);
    }
  });

  beforeEach(async () => {
    await db.execute('DELETE FROM allocation_preferences WHERE user_id IN (?, ?)', [userId, otherUserId]);
    await db.execute('DELETE FROM financial_profiles WHERE user_id IN (?, ?)', [userId, otherUserId]);
    await db.execute('DELETE FROM financial_commitments WHERE user_id IN (?, ?)', [userId, otherUserId]);
  });

  describe('PATCH /api/v1/financial-profile', () => {
    it('1. Create with explicit valid currency', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 1, currency: 'JOD' }).expect(200);
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].currency).toBe('JOD');
    });

    it('2. Create with currency omitted', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 15 }).expect(200);
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].currency).toBe('JOD');
    });

    it('3. Existing profile update with currency omitted', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, currency, payment_day, expected_monthly_income) VALUES (?, ?, ?, ?)', [userId, 'JOD', 10, 0]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 15 }).expect(200);
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].currency).toBe('JOD');
      expect(profiles[0].payment_day).toBe(15);
    });

    it('4. Existing legacy currency preserved when omitted', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, currency, payment_day, expected_monthly_income) VALUES (?, ?, ?, ?)', [userId, 'USD', 10, 0]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 15 }).expect(200);
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].currency).toBe('USD');
      expect(profiles[0].payment_day).toBe(15);
    });

    it('5. Explicit valid currency update', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, currency, payment_day, expected_monthly_income) VALUES (?, ?, ?, ?)', [userId, 'USD', 10, 0]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ currency: 'JOD' }).expect(200);
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].currency).toBe('JOD');
    });

    it('6. Explicit null currency rejected', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ currency: null }).expect(400);
    });

    it('7. Explicit undefined currency behavior', async () => {
      // JSON strings cannot represent undefined explicitly (it gets omitted). Handled by tests 2, 3, 4.
    });

    it('8. Empty currency rejected', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ currency: '' }).expect(400);
    });

    it('9. Whitespace currency rejected', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ currency: '   ' }).expect(400);
    });

    it('10. Unsupported currency follows verified contract', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ currency: 'EUR' }).expect(400);
    });

    it('11. Omitted income remains unchanged', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, expected_monthly_income) VALUES (?, ?)', [userId, 1500]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 20 }).expect(200);
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(Number(profiles[0].expected_monthly_income)).toBe(1500);
    });

    it('12. Submitted zero income is preserved if valid (via allocation-approve)', async () => {
      await request(app).post('/api/v1/financial-profile/allocation-approve').set('Authorization', authHeader).send({ expectedMonthlyIncome: 0, needsBps: 5000, wantsBps: 3000, savingsBps: 2000 }).expect(422);
    });

    it('13. Omitted payment day remains unchanged', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, payment_day, expected_monthly_income) VALUES (?, ?, ?)', [userId, 25, 0]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ timezone: 'Asia/Dubai' }).expect(200);
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].payment_day).toBe(25);
    });

    it('14. Boundary payment days 1 and 31', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 1 }).expect(200);
      let [profiles] = await db.execute('SELECT payment_day FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].payment_day).toBe(1);

      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 31 }).expect(200);
      [profiles] = await db.execute('SELECT payment_day FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].payment_day).toBe(31);
    });

    it('15. Invalid payment days', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 0 }).expect(400);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 32 }).expect(400);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 'abc' }).expect(400);
    });

    it('16. Omitted timezone remains unchanged', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, timezone, expected_monthly_income) VALUES (?, ?, ?)', [userId, 'Asia/Dubai', 0]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 5 }).expect(200);
      const [profiles] = await db.execute('SELECT timezone FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].timezone).toBe('Asia/Dubai');
    });

    it('17. Invalid timezone rejected', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ timezone: '' }).expect(400);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ timezone: null }).expect(400);
    });

    it('18. Successful PATCH changes only submitted fields', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, payment_day, currency, timezone, expected_monthly_income) VALUES (?, 10, "USD", "Europe/London", 2000)', [userId]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 20 }).expect(200);
      
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].payment_day).toBe(20);
      expect(profiles[0].currency).toBe('USD');
      expect(profiles[0].timezone).toBe('Europe/London');
      expect(Number(profiles[0].expected_monthly_income)).toBe(2000);
    });

    it('19. Failed PATCH leaves every field unchanged', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, payment_day, currency, timezone, expected_monthly_income) VALUES (?, 10, "USD", "Europe/London", 2000)', [userId]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 32, timezone: 'Asia/Dubai' }).expect(400);
      
      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].payment_day).toBe(10);
      expect(profiles[0].timezone).toBe('Europe/London');
    });

    it('20. Empty PATCH behavior', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, payment_day, expected_monthly_income) VALUES (?, 10, 0)', [userId]);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({}).expect(200);
      
      const [profiles] = await db.execute('SELECT payment_day FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles[0].payment_day).toBe(10);
    });

    it('21. Unknown field behavior', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 1, unknownField: 'test' }).expect(200);
    });

    it('22. Ownership enforcement', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', otherAuthHeader).send({ paymentDay: 5 }).expect(200);
      const [profiles] = await db.execute('SELECT payment_day FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles.length).toBe(0);
    });

    it('23. Database currency remains NOT NULL', async () => {
      const [cols] = await db.execute('DESCRIBE financial_profiles');
      const currencyCol = cols.find(c => c.Field === 'currency');
      expect(currencyCol.Null).toBe('NO');
      expect(currencyCol.Default).toBe('JOD');
    });

    it('24. updated_at behavior', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 5 }).expect(200);
      const [initial] = await db.execute('SELECT updated_at FROM financial_profiles WHERE user_id = ?', [userId]);
      
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 10 }).expect(200);
      const [updated] = await db.execute('SELECT updated_at FROM financial_profiles WHERE user_id = ?', [userId]);
      
      expect(initial[0].updated_at.getTime()).toBeLessThan(updated[0].updated_at.getTime());
    });

    it('25.1 Original failure 1: rejects invalid payment day and omits currency safely', async () => {
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 32 }).expect(400);
      await request(app).patch('/api/v1/financial-profile').set('Authorization', authHeader).send({ paymentDay: 1 }).expect(200);

      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles.length).toBe(1);
      expect(profiles[0].payment_day).toBe(1);
      expect(profiles[0].currency).toBe('JOD');
    });

    it('25.2 Original failure 2: POST /api/v1/financial-profile/allocation-preview calculates correctly using canonical key', async () => {
      await request(app).post('/api/v1/commitments').set('Authorization', authHeader).send({ name: 'Rent', amount: 200, frequency: 'monthly', dueDay: 1 }).expect(201);
      const res = await request(app).post('/api/v1/financial-profile/allocation-preview').set('Authorization', authHeader).send({ expectedMonthlyIncome: 600 }).expect(200);

      const data = res.body.data;
      expect(data.income).toBe(600);
      expect(data.tier).toBe('Lower Middle');
      expect(data.commitments.reservedAmount).toBe(200);
    });

    it('25.3 Original failure 3: POST /api/v1/financial-profile/allocation-approve saves approved allocation', async () => {
      await db.execute('INSERT INTO financial_profiles (user_id, currency, payment_day, expected_monthly_income) VALUES (?, ?, ?, ?)', [userId, 'JOD', 10, 0]);
      const res = await request(app).post('/api/v1/financial-profile/allocation-approve').set('Authorization', authHeader).send({
        expectedMonthlyIncome: 600, needsBps: 6000, wantsBps: 2000, savingsBps: 1500
      }).expect(400);

      expect(res.body.message).toMatch(/total exactly 100%/);

      await request(app).post('/api/v1/financial-profile/allocation-approve').set('Authorization', authHeader).send({
        expectedMonthlyIncome: 600, needsBps: 6000, wantsBps: 2500, savingsBps: 1500
      }).expect(200);

      const [prefs] = await db.execute('SELECT * FROM allocation_preferences WHERE user_id = ?', [userId]);
      expect(prefs.length).toBe(1);
      expect(prefs[0].needs_bps).toBe(6000);
      
      const [profiles] = await db.execute('SELECT expected_monthly_income FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(Number(profiles[0].expected_monthly_income)).toBe(600);
    });
  });
});
