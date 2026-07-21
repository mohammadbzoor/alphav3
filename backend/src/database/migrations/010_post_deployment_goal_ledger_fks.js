const { db } = require('../../config/database');

const up = async () => {
  console.log('Running migration 010: Post-deployment Goal Ledger Foreign Keys');

  // Verify necessary tables exist
  const [tables] = await db.execute(`
    SELECT TABLE_NAME, ENGINE
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME IN ('goals', 'users', 'goal_transactions')
  `);

  const foundTables = tables.map(t => t.TABLE_NAME);
  const requiredTables = ['goals', 'users', 'goal_transactions'];

  for (const table of requiredTables) {
    if (!foundTables.includes(table)) {
      console.log(`Table ${table} does not exist. Skipping migration.`);
      return;
    }
  }

  // Verify InnoDB
  for (const table of tables) {
    if (table.ENGINE !== 'InnoDB') {
      console.warn(`[WARNING] Table ${table.TABLE_NAME} is not using InnoDB. Foreign keys require InnoDB.`);
      return;
    }
  }

  // Detect orphan references for goals
  const [orphanGoals] = await db.execute(`
    SELECT gt.id
    FROM goal_transactions gt
    LEFT JOIN goals g ON gt.goal_id = g.id
    WHERE g.id IS NULL
  `);

  if (orphanGoals.length > 0) {
    console.error(`[FATAL] Found ${orphanGoals.length} orphan goal_transactions pointing to missing goals. Migration aborted.`);
    return;
  }

  // Detect orphan references for users
  const [orphanUsers] = await db.execute(`
    SELECT gt.id
    FROM goal_transactions gt
    LEFT JOIN users u ON gt.user_id = u.id
    WHERE u.id IS NULL
  `);

  if (orphanUsers.length > 0) {
    console.error(`[FATAL] Found ${orphanUsers.length} orphan goal_transactions pointing to missing users. Migration aborted.`);
    return;
  }

  // Detect ownership mismatches
  const [mismatches] = await db.execute(`
    SELECT gt.id
    FROM goal_transactions gt
    JOIN goals g ON gt.goal_id = g.id
    WHERE gt.user_id != g.user_id
  `);

  if (mismatches.length > 0) {
    console.error(`[FATAL] Found ${mismatches.length} goal_transactions where user_id does not match the goal owner. Migration aborted.`);
    return;
  }

  // Check existing constraints
  const [existingFks] = await db.execute(`
    SELECT CONSTRAINT_NAME
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'goal_transactions'
      AND REFERENCED_TABLE_NAME IS NOT NULL
  `);

  const fkNames = existingFks.map(fk => fk.CONSTRAINT_NAME);

  try {
    if (!fkNames.includes('fk_goal_transactions_goal')) {
      console.log('Adding fk_goal_transactions_goal constraint...');
      await db.execute(`
        ALTER TABLE goal_transactions
        ADD CONSTRAINT fk_goal_transactions_goal
        FOREIGN KEY (goal_id) REFERENCES goals(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
      `);
    } else {
      console.log('fk_goal_transactions_goal already exists.');
    }

    if (!fkNames.includes('fk_goal_transactions_user')) {
      console.log('Adding fk_goal_transactions_user constraint...');
      await db.execute(`
        ALTER TABLE goal_transactions
        ADD CONSTRAINT fk_goal_transactions_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
      `);
    } else {
      console.log('fk_goal_transactions_user already exists.');
    }

    console.log('Migration 010 applied successfully.');
  } catch (error) {
    console.error('Error applying migration 010. Please ensure the database user has the REFERENCES privilege.');
    console.error('To grant the privilege, an admin should run: GRANT REFERENCES ON alpha.* TO \'<application-user>\'@\'<application-host>\';');
    console.error('You can find the exact current user with: SELECT CURRENT_USER(), USER();');
    console.error('Original error:', error.message);
    throw error; // Re-throw to halt process
  }
};

const down = async () => {
  console.log('Reverting migration 010: Post-deployment Goal Ledger Foreign Keys');

  const [existingFks] = await db.execute(`
    SELECT CONSTRAINT_NAME
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'goal_transactions'
      AND REFERENCED_TABLE_NAME IS NOT NULL
  `);

  const fkNames = existingFks.map(fk => fk.CONSTRAINT_NAME);

  if (fkNames.includes('fk_goal_transactions_goal')) {
    await db.execute(`ALTER TABLE goal_transactions DROP FOREIGN KEY fk_goal_transactions_goal`);
  }

  if (fkNames.includes('fk_goal_transactions_user')) {
    await db.execute(`ALTER TABLE goal_transactions DROP FOREIGN KEY fk_goal_transactions_user`);
  }

  console.log('Migration 010 reverted successfully.');
};

module.exports = { up, down };
