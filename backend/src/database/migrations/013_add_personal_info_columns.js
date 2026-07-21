const { db } = require('../../config/database');

async function up() {
  console.log('Running migration 013: Add personal info columns to user_profiles');
  const columnsToAdd = [
    { name: 'gender', definition: "VARCHAR(20) NULL" },
    { name: 'marital_status', definition: "VARCHAR(30) NULL" },
    { name: 'is_head_of_household', definition: "TINYINT(1) DEFAULT 0" },
    { name: 'is_student', definition: "TINYINT(1) DEFAULT 0" },
    { name: 'family_size', definition: "INT UNSIGNED DEFAULT 1" },
    { name: 'primary_spending_category', definition: "VARCHAR(100) NULL" },
    { name: 'relationship_with_money', definition: "VARCHAR(100) NULL" },
    { name: 'monthly_extra_savings_goal', definition: "DECIMAL(15,2) NULL" },
    { name: 'main_financial_goal_12m', definition: "VARCHAR(255) NULL" },
    { name: 'income_sources', definition: "JSON NULL" },
    { name: 'fixed_expenses', definition: "JSON NULL" },
    { name: 'variable_expenses', definition: "JSON NULL" },
    { name: 'pinned_months', definition: "INT NULL" },
    { name: 'basic_expenses', definition: "DECIMAL(15,2) NULL" },
  ];

  for (const col of columnsToAdd) {
    try {
      const [existing] = await db.execute(
        `SHOW COLUMNS FROM user_profiles LIKE '${col.name}'`
      );
      if (existing.length === 0) {
        await db.execute(
          `ALTER TABLE user_profiles ADD COLUMN ${col.name} ${col.definition}`
        );
        console.log(`  Added column: ${col.name}`);
      } else {
        console.log(`  Column ${col.name} already exists, skipping.`);
      }
    } catch (error) {
      if (error.code === 'ER_DUP_FIELDNAME') {
        console.log(`  Column ${col.name} already exists (dup), skipping.`);
      } else {
        throw error;
      }
    }
  }

  console.log('Migration 013 applied successfully.');
}

async function down() {
  console.log('Reverting migration 013: Remove personal info columns from user_profiles');
  const columns = [
    'gender', 'marital_status', 'is_head_of_household', 'is_student',
    'family_size', 'primary_spending_category', 'relationship_with_money',
    'monthly_extra_savings_goal', 'main_financial_goal_12m', 'income_sources',
    'fixed_expenses', 'variable_expenses', 'pinned_months', 'basic_expenses'
  ];

  for (const col of columns) {
    try {
      await db.execute(`ALTER TABLE user_profiles DROP COLUMN IF EXISTS ${col}`);
    } catch (error) {
      console.log(`  Could not drop ${col}: ${error.message}`);
    }
  }

  console.log('Migration 013 reverted.');
}

module.exports = { up, down };
