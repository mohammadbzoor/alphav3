require('dotenv').config();
const mysql = require('mysql2/promise');

async function dumpSchema() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'alpha'
  });

  const tables = [
    'users', 'financial_profiles', 'allocation_tiers', 'allocation_preferences',
    'financial_cycles', 'cycle_allocation_snapshots', 'transactions',
    'financial_commitments', 'commitment_occurrences', 'goals',
    'goal_transactions', 'savings_allocations', 'goal_cycle_allocations',
    'allocation_transition_plans', 'cycle_settlements', 'settlement_actions'
  ];

  for (const table of tables) {
    try {
      const [rows] = await connection.query(`SHOW CREATE TABLE ${table}`);
      console.log(`\n--- ${table} ---`);
      console.log(rows[0]['Create Table']);
    } catch (e) {
      console.error(`Error with table ${table}:`, e.message);
    }
  }

  await connection.end();
}

dumpSchema().catch(console.error);
