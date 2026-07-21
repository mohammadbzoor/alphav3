const request = require('supertest');
const { app } = require('../app');
const { db } = require('../config/database');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');

describe('Finance Routes Validation', () => {
  let token = '';

  beforeAll(async () => {
    // Generate valid token
    token = jwt.sign({ id: 1 }, env.jwtAccessSecret || 'secret', { expiresIn: '1h' });

    // We don't need a real user if we just mock the controller or see if it reaches the DB and throws a generic DB error or empty array.
    // If we have a user 1, it returns an empty array.
  });

  afterAll(async () => {
    await db.end();
  });

  test('GET /api/v1/goals/ready routes correctly', async () => {
    const res = await request(app)
      .get('/api/v1/goals/ready')
      .set('Authorization', `Bearer ${token}`);

    // It should hit getReadyGoals and return 200 with an array
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
  });
});
