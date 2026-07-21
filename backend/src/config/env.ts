import dotenv from 'dotenv';

dotenv.config();

function requiredEnv(name: string): string {
  const value = process.env[name];

  if (!value || value.trim() === '') {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value.trim();
}

function numberEnv(name: string, defaultValue: number): number {
  const value = process.env[name];

  if (!value) {
    return defaultValue;
  }

  const parsedValue = Number(value);

  if (!Number.isFinite(parsedValue)) {
    throw new Error(
      `Environment variable ${name} must be a valid number`,
    );
  }

  return parsedValue;
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: numberEnv('PORT', 3000),
  apiPrefix: process.env.API_PREFIX ?? '/api/v1',

  dbHost: requiredEnv('DB_HOST'),
  dbPort: numberEnv('DB_PORT', 3306),
  dbUser: requiredEnv('DB_USER'),
  dbPass: requiredEnv('DB_PASSWORD'),
  dbName: requiredEnv('DB_NAME'),
  dbConnectionLimit: numberEnv('DB_CONNECTION_LIMIT', 10),

  bcryptSaltRounds: numberEnv('BCRYPT_SALT_ROUNDS', 10),
};