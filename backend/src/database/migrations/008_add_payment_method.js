const { db } = require('../../config/database');

async function up() {
  console.log('Running migration 008: Add payment_method to transactions');
  try {
    // Add payment_method to transactions if it doesn't exist
    await db.execute(`
      ALTER TABLE transactions
      ADD COLUMN payment_method ENUM('cash', 'card', 'wallet', 'bank_transfer', 'other') DEFAULT 'cash' AFTER source_type
    `);
    console.log('payment_method column added successfully.');
  } catch (error) {
    if (error.code === 'ER_DUP_FIELDNAME') {
      console.log('payment_method column already exists, skipping.');
    } else {
      console.error('Migration failed:', error);
      throw error;
    }
  }
}

async function down() {
  console.log('Rolling back migration 008');
  try {
    await db.execute(`ALTER TABLE transactions DROP COLUMN payment_method`);
  } catch (error) {
    console.error('Rollback failed:', error);
  }
}

module.exports = { up, down };
