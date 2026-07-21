const { db } = require('../../config/database');

async function up() {
  console.log('Adding detected_tier to financial_profiles table...');
  try {
    // Check if column exists first
    const [columns] = await db.execute(`SHOW COLUMNS FROM financial_profiles LIKE 'detected_tier'`);
    if (columns.length === 0) {
      await db.execute(`
        ALTER TABLE financial_profiles
        ADD COLUMN detected_tier VARCHAR(50) NULL AFTER expected_monthly_income
      `);
      console.log('Successfully added detected_tier column.');
    } else {
      console.log('detected_tier column already exists. Skipping.');
    }
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

async function down() {
  console.log('Removing detected_tier from financial_profiles table...');
  try {
    const [columns] = await db.execute(`SHOW COLUMNS FROM financial_profiles LIKE 'detected_tier'`);
    if (columns.length > 0) {
      await db.execute(`
        ALTER TABLE financial_profiles
        DROP COLUMN detected_tier
      `);
      console.log('Successfully removed detected_tier column.');
    }
  } catch (error) {
    console.error('Rollback failed:', error);
    throw error;
  }
}

module.exports = { up, down };
