const { db } = require('../../config/database');

async function up() {
  console.log('Adding multi-input support columns to transactions and financial_commitments...');
  try {
    // We assume the tables exist.
    // ADD columns to transactions
    await db.execute(`
      ALTER TABLE transactions
      ADD COLUMN source_type ENUM('manual', 'image', 'voice') DEFAULT 'manual',
      ADD COLUMN original_image_url VARCHAR(255) NULL,
      ADD COLUMN original_transcript TEXT NULL
    `);

    // ADD columns to financial_commitments
    await db.execute(`
      ALTER TABLE financial_commitments
      ADD COLUMN source_type ENUM('manual', 'image', 'voice') DEFAULT 'manual',
      ADD COLUMN original_image_url VARCHAR(255) NULL,
      ADD COLUMN original_transcript TEXT NULL
    `);

    console.log('Successfully added multi-input columns.');
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

async function down() {
  console.log('Removing multi-input support columns...');
  try {
    await db.execute(`
      ALTER TABLE transactions
      DROP COLUMN IF EXISTS source_type,
      DROP COLUMN IF EXISTS original_image_url,
      DROP COLUMN IF EXISTS original_transcript
    `);

    await db.execute(`
      ALTER TABLE financial_commitments
      DROP COLUMN IF EXISTS source_type,
      DROP COLUMN IF EXISTS original_image_url,
      DROP COLUMN IF EXISTS original_transcript
    `);

    console.log('Successfully reverted multi-input columns.');
  } catch (error) {
    console.error('Rollback failed:', error);
    throw error;
  }
}

module.exports = { up, down };
