const mysql = require('mysql2/promise');
require('dotenv').config();

async function runSchemaUpdate() {
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST || '127.0.0.1',
      user: process.env.DB_USER || 'alpha_app',
      password: process.env.DB_PASSWORD || '123456',
      database: process.env.DB_NAME || 'alpha',
      port: process.env.DB_PORT || 3306,
      multipleStatements: true
    });

    console.log('Connected to MySQL...');

    // 1. Add columns to users if they don't exist
    // MySQL 8+ doesn't natively support IF NOT EXISTS in ALTER TABLE cleanly without stored procs
    // So we'll try/catch this specific part
    try {
      await connection.query(`
        ALTER TABLE users 
        ADD COLUMN otp_code VARCHAR(10) NULL AFTER is_verified,
        ADD COLUMN otp_expires_at DATETIME NULL AFTER otp_code,
        ADD COLUMN is_onboarded BOOLEAN DEFAULT FALSE AFTER otp_expires_at;
      `);
      console.log('Added missing columns to users table.');
    } catch (err) {
      if (err.code === 'ER_DUP_FIELDNAME') {
        console.log('Columns already exist in users table. Skipping ALTER.');
      } else {
        throw err;
      }
    }

    // 2. Create user_profiles table
    const createUserProfilesQuery = `
      CREATE TABLE IF NOT EXISTS \`user_profiles\` (
        \`user_id\` bigint unsigned NOT NULL,
        \`employment_status\` varchar(50) DEFAULT NULL,
        \`monthly_income\` decimal(15,2) DEFAULT NULL,
        \`basic_expenses\` decimal(15,2) DEFAULT NULL,
        \`has_dependents\` boolean DEFAULT FALSE,
        \`financial_knowledge\` varchar(50) DEFAULT NULL,
        \`primary_financial_goal\` varchar(100) DEFAULT NULL,
        \`primary_spending_category\` varchar(100) DEFAULT NULL,
        \`relationship_with_money\` varchar(100) DEFAULT NULL,
        \`monthly_extra_savings_goal\` decimal(15,2) DEFAULT NULL,
        \`main_financial_goal_12m\` varchar(100) DEFAULT NULL,
        \`income_sources\` JSON DEFAULT NULL,
        \`fixed_expenses\` JSON DEFAULT NULL,
        \`variable_expenses\` JSON DEFAULT NULL,
        \`pinned_months\` INT DEFAULT NULL,
        \`created_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        \`updated_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (\`user_id\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `;
    await connection.query(createUserProfilesQuery);
    console.log('Created or verified user_profiles table.');

    // 3. Create goals table
    const createGoalsQuery = `
      CREATE TABLE IF NOT EXISTS \`goals\` (
        \`id\` bigint unsigned NOT NULL AUTO_INCREMENT,
        \`user_id\` bigint unsigned NOT NULL,
        \`icon\` varchar(50) DEFAULT NULL,
        \`name\` varchar(100) NOT NULL,
        \`target_amount\` decimal(15,2) NOT NULL,
        \`target_date\` datetime NOT NULL,
        \`flexibility\` varchar(50) DEFAULT NULL,
        \`created_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        \`updated_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (\`id\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `;
    await connection.query(createGoalsQuery);
    console.log('Created or verified goals table.');

    console.log('Schema update completed successfully!');
    await connection.end();
  } catch (err) {
    console.error('Schema update failed:', err.message);
    process.exit(1);
  }
}

runSchemaUpdate();
