const { db } = require('../../config/database');

const up = async () => {
  console.log('Running migration 011: Phase 2 Goal Planning');

  const [columns] = await db.execute(`
    SELECT COLUMN_NAME
    FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'goals'
  `);

  const colNames = columns.map(c => c.COLUMN_NAME);

  if (!colNames.includes('custom_name')) {
    console.log('Adding custom_name column to goals...');
    await db.execute('ALTER TABLE goals ADD COLUMN custom_name VARCHAR(150) NULL AFTER name');
  }

  if (!colNames.includes('planned_contribution')) {
    console.log('Adding planned_contribution column to goals...');
    await db.execute('ALTER TABLE goals ADD COLUMN planned_contribution BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER current_balance');
  }

  // Backfill goal_type for existing goals if they don't match the new enums
  // The predefined codes are: emergency_fund, laptop, travel, religious_travel, holiday_expenses, tuition, car_down_payment, home_down_payment, business_startup, electrical_appliances, furniture, clothing_accessories, custom
  await db.execute(`
    UPDATE goals
    SET goal_type = 'custom', custom_name = name
    WHERE goal_type NOT IN (
      'emergency_fund', 'laptop', 'travel', 'religious_travel',
      'holiday_expenses', 'tuition', 'car_down_payment',
      'home_down_payment', 'business_startup',
      'electrical_appliances', 'furniture',
      'clothing_accessories', 'custom'
    )
  `);

  console.log('Migration 011 applied successfully.');
};

const down = async () => {
  console.log('Reverting migration 011: Phase 2 Goal Planning');

  const [columns] = await db.execute(`
    SELECT COLUMN_NAME
    FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'goals'
  `);

  const colNames = columns.map(c => c.COLUMN_NAME);

  if (colNames.includes('custom_name')) {
    await db.execute('ALTER TABLE goals DROP COLUMN custom_name');
  }

  if (colNames.includes('planned_contribution')) {
    await db.execute('ALTER TABLE goals DROP COLUMN planned_contribution');
  }

  console.log('Migration 011 reverted successfully.');
};

module.exports = { up, down };
