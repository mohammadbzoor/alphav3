require('dotenv').config();
const mysql = require('mysql2/promise');

async function run() {
  console.log('--- MIGRATION 005: Finance & Profile Setup ---');
  console.log('Checking database schema...');

  try {
    const db = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME
    });

    const [tables] = await db.execute('SHOW TABLES');
    const tableNames = tables.map(t => Object.values(t)[0]);

    if (tableNames.includes('transactions') && tableNames.includes('goals')) {
      console.log('✅ "transactions" and "goals" tables already exist.');
      console.log('✅ Reusing "transactions" for expenses and incomes.');
      console.log('✅ Reusing "goals" for goals management.');
      console.log('No new tables required. Migration skipped successfully.');
    } else {
      console.error('❌ "transactions" or "goals" table is missing! Cannot proceed.');
    }

    await db.end();
  } catch (err) {
    console.error('Migration error:', err);
  }
}

run();
