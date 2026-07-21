const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { AllocationService } = require('../services/allocation.service');

describe('Financial Profile API', () => {
  let authHeader;
  let userId;

  beforeAll(async () => {
    // Clean up specific test data if exists
    await db.execute('DELETE FROM users WHERE email = ?', ['financial_profile_test@example.com']);

    const [result] = await db.execute(
      'INSERT INTO users (full_name, email, password_hash) VALUES (?, ?, ?)',
      ['Test User', 'financial_profile_test@example.com', 'hashed_pass']
    );
    userId = result.insertId;
    const token = jwt.sign({ id: userId }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });
    authHeader = `Bearer ${token}`;
  });

  afterAll(async () => {
    if (userId) {
      await db.execute('DELETE FROM allocation_preferences WHERE user_id = ?', [userId]);
      await db.execute('DELETE FROM financial_profiles WHERE user_id = ?', [userId]);
      await db.execute('DELETE FROM financial_commitments WHERE user_id = ?', [userId]);
      await db.execute('DELETE FROM users WHERE id = ?', [userId]);
    }
  });

  describe('PATCH /api/v1/financial-profile', () => {
    it('stores salary as expected income only and rejects invalid payment day', async () => {
      const res = await request(app)
        .patch('/api/v1/financial-profile')
        .set('Authorization', authHeader)
        .send({
          expectedIncome: 600,
          salaryPaymentDay: 32 // invalid
        })
        .expect(400);

      expect(res.body.message).toMatch(/Salary payment day must be between 1 and 31/);

      const res2 = await request(app)
        .patch('/api/v1/financial-profile')
        .set('Authorization', authHeader)
        .send({
          expectedIncome: 600,
          salaryPaymentDay: 1,
          additionalIncomeSources: [
            { type: 'freelance', amount: 100 }
          ]
        })
        .expect(200);

      const [profiles] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
      expect(profiles.length).toBe(1);
      expect(Number(profiles[0].expected_monthly_income)).toBe(600);
      expect(profiles[0].payment_day).toBe(1);
      
      // Ensure no transactions were created (salary does not create an income transaction)
      const [transactions] = await db.execute('SELECT * FROM transactions WHERE user_id = ?', [userId]);
      expect(transactions.length).toBe(0);
    });
  });

  describe('POST /api/v1/commitments', () => {
    it('creates a commitment with valid data and rejects invalid', async () => {
      const res = await request(app)
        .post('/api/v1/commitments')
        .set('Authorization', authHeader)
        .send({
          type: 'house_rent',
          amount: 200,
          frequency: 'monthly',
          dueDay: 1
        })
        .expect(201);
        
      expect(res.body.success).toBe(true);
      
      // Reject missing/invalid amount
      await request(app)
        .post('/api/v1/commitments')
        .set('Authorization', authHeader)
        .send({
          type: 'house_rent',
          amount: -50,
          frequency: 'monthly',
          dueDay: 1
        })
        .expect(400);
    });
  });

  describe('POST /api/v1/financial-profile/allocation-preview', () => {
    it('calculates allocation correctly based on expected income and commitments', async () => {
      const res = await request(app)
        .post('/api/v1/financial-profile/allocation-preview')
        .set('Authorization', authHeader)
        .send({
          expectedIncome: 600
        })
        .expect(200);

      const data = res.body.data;
      expect(data.expectedIncome).toBe(600);
      expect(data.tier).toBe('Lower Middle');
      
      // 600 -> lower_middle -> 60/25/15
      expect(data.allocation.needsBps).toBe(6000);
      expect(data.allocation.needsAmount).toBe(360);
      expect(data.allocation.wantsBps).toBe(2500);
      expect(data.allocation.wantsAmount).toBe(150);
      expect(data.allocation.savingsBps).toBe(1500);
      expect(data.allocation.savingsAmount).toBe(90);
      
      // We added a 200 commitment earlier
      expect(data.commitments.reservedAmount).toBe(200);
      expect(data.commitments.availableVariableNeeds).toBe(160); // 360 - 200
    });
  });

  describe('PUT /api/v1/financial-profile/allocation', () => {
    it('saves approved allocation and rejects invalid totals', async () => {
      const res = await request(app)
        .put('/api/v1/financial-profile/allocation')
        .set('Authorization', authHeader)
        .send({
          expectedIncome: 600,
          needsBps: 6000,
          wantsBps: 2000,
          savingsBps: 1500 // Total 9500 != 10000
        })
        .expect(400);

      expect(res.body.message).toMatch(/total exactly 100%/);

      const res2 = await request(app)
        .put('/api/v1/financial-profile/allocation')
        .set('Authorization', authHeader)
        .send({
          expectedIncome: 600,
          needsBps: 6000,
          wantsBps: 2500,
          savingsBps: 1500
        })
        .expect(200);

      const [prefs] = await db.execute('SELECT * FROM allocation_preferences WHERE user_id = ?', [userId]);
      expect(prefs.length).toBe(1);
      expect(prefs[0].needs_bps).toBe(6000);
      expect(prefs[0].wants_bps).toBe(2500);
      expect(prefs[0].savings_bps).toBe(1500);
    });
  });
});
