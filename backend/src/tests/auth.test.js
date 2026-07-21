
const request = require('supertest');
const { app } = require('../app');
const { UserRepository } = require('../repositories/user.repository');
const bcrypt = require('bcrypt');

// vi.mock('../repositories/user.repository');

describe('Auth Registration API', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(bcrypt, 'hash').mockResolvedValue('hashed_password');
  });

  const validPayload = {
    fullName: 'Mohammad Aqaba',
    phone: '0791234567',
    email: 'user@example.com',
    birthDate: '2002-05-15',
    password: 'StrongPassword1'
  };

  it('1. should create an account with valid data and return 201', async () => {
    vi.spyOn(UserRepository, 'findByEmailOrPhone').mockResolvedValue(null);
    vi.spyOn(UserRepository, 'createUser').mockResolvedValue(1);
    vi.spyOn(UserRepository, 'findById').mockResolvedValue({
      id: 1, full_name: 'Mohammad Aqaba', phone: '+962791234567', email: 'user@example.com', birth_date: '2002-05-15', is_verified: 0
    });

    const res = await request(app).post('/api/v1/auth/register').send(validPayload);

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.id).toBe(1);
    expect(res.body.data.user).not.toHaveProperty('passwordHash');
    expect(res.body.data.user).not.toHaveProperty('password_hash');
  });

  it('4. should return 409 if email is already registered', async () => {
    vi.spyOn(UserRepository, 'findByEmailOrPhone').mockResolvedValue({
      id: 2, email: 'user@example.com', phone: '+962790000000'
    });

    const res = await request(app).post('/api/v1/auth/register').send(validPayload);
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('EMAIL_ALREADY_EXISTS');
  });

  it('5. should return 409 if phone is already registered', async () => {
    vi.spyOn(UserRepository, 'findByEmailOrPhone').mockResolvedValue({
      id: 2, email: 'other@example.com', phone: '+962791234567'
    });

    const res = await request(app).post('/api/v1/auth/register').send(validPayload);
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('PHONE_ALREADY_EXISTS');
  });

  it('7. should normalize 079 to +96279', async () => {
    vi.spyOn(UserRepository, 'findByEmailOrPhone').mockResolvedValue(null);
    vi.spyOn(UserRepository, 'createUser').mockResolvedValue(1);
    vi.spyOn(UserRepository, 'findById').mockResolvedValue({
      id: 1, full_name: 'Mohammad Aqaba', phone: '+962791234567', email: 'user@example.com', birth_date: '2002-05-15', is_verified: 0
    });

    await request(app).post('/api/v1/auth/register').send(validPayload);

    expect(UserRepository.findByEmailOrPhone).toHaveBeenCalledWith('user@example.com', '+962791234567');
    expect(UserRepository.createUser).toHaveBeenCalledWith(expect.objectContaining({
      phone: '+962791234567'
    }));
  });

  it('8. should reject password shorter than 8 chars', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({ ...validPayload, password: 'Short1a' });
    expect(res.status).toBe(422);
  });

  it('9. should reject password without uppercase', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({ ...validPayload, password: 'nouppercase1' });
    expect(res.status).toBe(422);
  });

  it('10. should reject password without lowercase', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({ ...validPayload, password: 'NOLOWERCASE1' });
    expect(res.status).toBe(422);
  });

  it('11. should reject password without number', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({ ...validPayload, password: 'NoNumberHere' });
    expect(res.status).toBe(422);
  });

  it('12. should reject future birth date', async () => {
    const futureDate = new Date();
    futureDate.setFullYear(futureDate.getFullYear() + 1);
    const res = await request(app).post('/api/v1/auth/register').send({ ...validPayload, birthDate: futureDate.toISOString().split('T')[0] });
    expect(res.status).toBe(422);
  });

  it('13. should reject invalid email', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({ ...validPayload, email: 'not-an-email' });
    expect(res.status).toBe(422);
  });

  it('14. should reject empty full name', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({ ...validPayload, fullName: '' });
    expect(res.status).toBe(422);
  });
});
