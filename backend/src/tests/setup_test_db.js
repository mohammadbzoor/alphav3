const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

process.env.NODE_ENV = 'test';
require('../config/env');
const { db } = require('../config/database');

async function setupTestDb() {
  const dbName = process.env.DB_NAME;
  if (!dbName || !dbName.endsWith('_test')) {
    console.error('Safety abort: DB_NAME must end with _test');
    process.exit(1);
  }

  // Connect as root to drop/create because app user might not have DROP privileges,
  // or use the app credentials if they do.
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    multipleStatements: true,
  });

  console.log(`Setting up ${dbName}...`);
  try {
    await connection.query(`DROP DATABASE IF EXISTS \`${dbName}\``);
    await connection.query(`CREATE DATABASE \`${dbName}\``);
    await connection.query(`USE \`${dbName}\``);
  } catch (e) {
    console.error('Error creating database. Test user must have DROP/CREATE privileges.', e.message);
    process.exit(1);
  }

  const migrationsDir = path.resolve(__dirname, '../database/migrations');
  const files = fs.readdirSync(migrationsDir).sort();

  for (const file of files) {
    if (file.endsWith('.sql')) {
      console.log(`Running SQL migration: ${file}`);
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      await connection.query(sql);
    } else if (file.endsWith('.js') && file !== 'run_migrations.js') {
      console.log(`Running JS migration: ${file}`);
      const migration = require(path.join(migrationsDir, file));
      if (migration.up) await migration.up();
    }
  }
  await connection.end();

  console.log('Verifying goal_transactions foreign keys...');
  const [fkRes] = await db.query(`
    SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'goal_transactions' AND REFERENCED_TABLE_NAME IS NOT NULL
  `, [dbName]);
  console.log('Foreign keys:', fkRes);

  console.log('Seeding minimal test fixtures...');
  await db.execute('INSERT INTO users (full_name, email, password_hash, is_verified) VALUES ("Test User", "test@example.com", "hash", 1)');

  await db.end();
}

setupTestDb().catch(e => {
  console.error(e);
  process.exit(1);
});
