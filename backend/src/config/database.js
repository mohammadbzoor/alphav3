const mysql = require('mysql2/promise');
const { env } = require('./env');

if (env.nodeEnv === 'test') {
  if (!env.dbName || !env.dbName.endsWith('_test') || env.dbName === 'alpha' || env.dbName === 'alpha_prod' || env.dbName === 'alpha_production') {
    console.error(`[FATAL] Unsafe database configuration for test environment: ${env.dbName}`);
    console.error('Tests must run against an isolated database (e.g. alpha_test). Aborting to protect data.');
    process.exit(1);
  }
}

const db = mysql.createPool({
  host: env.dbHost,
  port: env.dbPort,
  user: env.dbUser,
  password: env.dbPass,
  database: env.dbName,

  waitForConnections: true,
  connectionLimit: env.dbConnectionLimit,
  queueLimit: 0,

  charset: 'utf8mb4',
});

module.exports = { db };
