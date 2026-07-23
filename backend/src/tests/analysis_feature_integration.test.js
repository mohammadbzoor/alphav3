const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const { env } = require('../config/env');
const axios = require('axios');
const jwt = require('jsonwebtoken');

describe('Financial Analysis Feature MVP Integration', () => {
  let userId;
  let token;
  let cycleId;
  const testEmail = `analysis_test_${Date.now()}@test.com`;

  beforeAll(async () => {
    // 1. Set up inert env
    process.env.N8N_ANALYSIS_WEBHOOK_URL = 'http://localhost:9999/webhook/analysis';
    process.env.N8N_ANALYSIS_TIMEOUT_MS = '15000';

    // 2. Create User
    const [result] = await db.execute('INSERT INTO users (full_name, email, phone, password_hash) VALUES (?, ?, ?, ?)', ['Analysis User', testEmail, `+96279111${Date.now().toString().slice(-4)}`, 'hash']);
    userId = result.insertId;

    // 3. Create active cycle
    const [cycleResult] = await db.execute('INSERT INTO financial_cycles (user_id, start_date, end_date) VALUES (?, ?, ?)', [userId, '2026-07-01', '2026-07-31']);
    cycleId = cycleResult.insertId;

    const secret = env.jwtAccessSecret || 'secret';
    token = jwt.sign({ id: userId, role: 'user' }, secret, { expiresIn: '1h' });
  });

  afterAll(async () => {
    await db.execute('DELETE FROM financial_cycles WHERE user_id = ?', [userId]);
    await db.execute('DELETE FROM users WHERE id = ?', [userId]);
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('verifies exact endpoint and request validation', async () => {
    // Unauthenticated request
    let res = await request(app).post('/api/v1/financial-analysis').send({});
    expect(res.status).toBe(401);

    // Invalid fields
    res = await request(app)
      .post('/api/v1/financial-analysis')
      .set('Authorization', `Bearer ${token}`)
      .send({ mode: 'financial_snapshot', unknownField: true });
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Only mode, language, includeSpeechText, maxInsights, maxRecommendations are allowed');

    // Reject mutated fields
    res = await request(app)
      .post('/api/v1/financial-analysis')
      .set('Authorization', `Bearer ${token}`)
      .send({ userId: 999 });
    expect(res.status).toBe(400);
  });

  it('verifies read-only behavior on successful request', async () => {
    // Before counts
    const [beforeUsers] = await db.execute('SELECT COUNT(*) as c FROM users');
    const [beforeCycles] = await db.execute('SELECT COUNT(*) as c FROM financial_cycles');

    vi.spyOn(axios, 'post').mockImplementation(async (url, data, config) => {
      const requestId = config.headers['X-Request-ID'];
      return {
        status: 200,
        data: {
          success: true,
          requestId: requestId,
          analysis: { summary: 'test', insights: [], recommendations: [] },
          metadata: { generatedAt: new Date().toISOString(), requestId: requestId }
        }
      };
    });

    const res = await request(app)
      .post('/api/v1/financial-analysis')
      .set('Authorization', `Bearer ${token}`)
      .send({ mode: 'financial_snapshot' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    // After counts
    const [afterUsers] = await db.execute('SELECT COUNT(*) as c FROM users');
    const [afterCycles] = await db.execute('SELECT COUNT(*) as c FROM financial_cycles');
    
    expect(afterUsers[0].c).toBe(beforeUsers[0].c);
    expect(afterCycles[0].c).toBe(beforeCycles[0].c);
  });

  it('verifies no-current-cycle behavior', async () => {
    // Create user without cycle
    const noCycleEmail = `nocycle_${Date.now()}@test.com`;
    const noCyclePhone = `+96279222${Date.now().toString().slice(-4)}`;
    const [result] = await db.execute('INSERT INTO users (full_name, email, phone, password_hash) VALUES (?, ?, ?, ?)', ['No Cycle User', noCycleEmail, noCyclePhone, 'hash']);
    const noCycleUserId = result.insertId;
    const secret = env.jwtAccessSecret || 'secret';
    const nocycleToken = jwt.sign({ id: noCycleUserId, role: 'user' }, secret, { expiresIn: '1h' });

    vi.spyOn(axios, 'post').mockImplementation(async (url, data, config) => {
      const requestId = config.headers['X-Request-ID'];
      return {
        status: 200,
        data: {
          success: true,
          requestId: requestId,
          analysis: { summary: 'setup guide', insights: [], recommendations: [] },
          metadata: { generatedAt: new Date().toISOString(), requestId: requestId }
        }
      };
    });

    const res = await request(app)
      .post('/api/v1/financial-analysis')
      .set('Authorization', `Bearer ${nocycleToken}`)
      .send({ mode: 'financial_snapshot' });

    expect(res.status).toBe(200);
    expect(res.body.scope).toBe('no_active_cycle');
    expect(res.body.dataQuality.hasCurrentCycle).toBe(false);

    await db.execute('DELETE FROM users WHERE id = ?', [noCycleUserId]);
  });
});
