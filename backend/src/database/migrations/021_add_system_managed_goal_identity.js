const { db } = require('../../config/database');

async function up() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // 1. Add is_system_managed column if missing
    const [cols] = await conn.execute(`
      SELECT COLUMN_NAME 
      FROM information_schema.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'goals' 
        AND COLUMN_NAME = 'is_system_managed'
    `);

    if (cols.length === 0) {
      await conn.execute(`
        ALTER TABLE goals 
        ADD COLUMN is_system_managed BOOLEAN NOT NULL DEFAULT FALSE
      `);
      console.log('Added is_system_managed column to goals.');
    } else {
      console.log('is_system_managed column already exists, skipping.');
    }

    // 2. Add domain check for ordinary goal types
    const [checks] = await conn.execute(`
      SELECT CONSTRAINT_NAME
      FROM information_schema.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'goals'
        AND CONSTRAINT_TYPE = 'CHECK'
        AND CONSTRAINT_NAME = 'chk_goals_system_type'
    `);

    if (checks.length === 0) {
      await conn.execute(`
        ALTER TABLE goals 
        ADD CONSTRAINT chk_goals_system_type 
        CHECK (is_system_managed = FALSE OR goal_type = 'emergency_fund')
      `);
      console.log('Added chk_goals_system_type constraint.');
    } else {
      console.log('chk_goals_system_type constraint already exists, skipping.');
    }

    // 3. Add generated conditional identity column if missing
    const [markerCols] = await conn.execute(`
      SELECT COLUMN_NAME, GENERATION_EXPRESSION
      FROM information_schema.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'goals' 
        AND COLUMN_NAME = 'sys_ef_marker'
    `);

    if (markerCols.length === 0) {
      await conn.execute(`
        ALTER TABLE goals
        ADD COLUMN sys_ef_marker TINYINT GENERATED ALWAYS AS (
          CASE 
            WHEN is_system_managed = TRUE AND goal_type = 'emergency_fund' THEN 1 
            ELSE NULL 
          END
        ) VIRTUAL
      `);
      console.log('Added sys_ef_marker generated column.');
    } else {
      console.log('sys_ef_marker column already exists, skipping.');
    }

    // 4. Add unique index for (user_id, sys_ef_marker) if missing
    const [indexes] = await conn.execute(`
      SELECT INDEX_NAME 
      FROM information_schema.STATISTICS 
      WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'goals' 
        AND INDEX_NAME = 'uq_goals_user_system_emergency'
    `);

    if (indexes.length === 0) {
      await conn.execute(`
        ALTER TABLE goals
        ADD UNIQUE INDEX uq_goals_user_system_emergency (user_id, sys_ef_marker)
      `);
      console.log('Added uq_goals_user_system_emergency unique index.');
    } else {
      console.log('uq_goals_user_system_emergency index already exists, skipping.');
    }

    await conn.commit();
    console.log('Migration 021 applied successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration failed:', err);
    throw err;
  } finally {
    conn.release();
  }
}

async function down() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [indexes] = await conn.execute(`
      SELECT INDEX_NAME 
      FROM information_schema.STATISTICS 
      WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'goals' 
        AND INDEX_NAME = 'uq_goals_user_system_emergency'
    `);
    if (indexes.length > 0) {
      await conn.execute('ALTER TABLE goals DROP INDEX uq_goals_user_system_emergency');
      console.log('Dropped index uq_goals_user_system_emergency.');
    }

    const [markerCols] = await conn.execute(`
      SELECT COLUMN_NAME 
      FROM information_schema.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'goals' 
        AND COLUMN_NAME = 'sys_ef_marker'
    `);
    if (markerCols.length > 0) {
      await conn.execute('ALTER TABLE goals DROP COLUMN sys_ef_marker');
      console.log('Dropped column sys_ef_marker.');
    }

    const [checks] = await conn.execute(`
      SELECT CONSTRAINT_NAME
      FROM information_schema.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'goals'
        AND CONSTRAINT_TYPE = 'CHECK'
        AND CONSTRAINT_NAME = 'chk_goals_system_type'
    `);
    if (checks.length > 0) {
      await conn.execute('ALTER TABLE goals DROP CONSTRAINT chk_goals_system_type');
      console.log('Dropped constraint chk_goals_system_type.');
    }

    const [cols] = await conn.execute(`
      SELECT COLUMN_NAME 
      FROM information_schema.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'goals' 
        AND COLUMN_NAME = 'is_system_managed'
    `);
    if (cols.length > 0) {
      await conn.execute('ALTER TABLE goals DROP COLUMN is_system_managed');
      console.log('Dropped column is_system_managed.');
    }

    await conn.commit();
    console.log('Migration 021 rolled back successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration rollback failed:', err);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { up, down };
