module.exports = {
  up: async (conn) => {
    console.log('--- Applying 025_fix_challenge_constraints ---');

    // 1. Remove the flawed unique constraint
    try {
      // Create index on user_id so the foreign key doesn't block dropping the unique key
      await conn.query('CREATE INDEX idx_user_challenges_user_id ON user_challenges(user_id)');
    } catch (e) {
      if (e.code !== 'ER_DUP_KEYNAME') throw e;
    }

    try {
      await conn.query('ALTER TABLE user_challenges DROP INDEX unique_active_challenge');
      console.log('  Dropped unique_active_challenge from user_challenges');
    } catch (e) {
      if (e.code === 'ER_CANT_DROP_FIELD_OR_KEY') {
        console.log('  unique_active_challenge does not exist, skipping drop.');
      } else {
        throw e;
      }
    }

    // 2. Add UNIQUE constraint to challenge_progress
    try {
      await conn.query('ALTER TABLE challenge_progress ADD CONSTRAINT unique_user_challenge_id UNIQUE (user_challenge_id)');
      console.log('  Added unique_user_challenge_id to challenge_progress');
    } catch (e) {
      if (e.code === 'ER_DUP_KEYNAME') {
        console.log('  unique_user_challenge_id already exists, skipping add.');
      } else {
        throw e;
      }
    }

    // 3. Fix the no_spend_category seeded template condition ('Coffee' -> 'coffee')
    await conn.query(`
      UPDATE challenge_templates 
      SET conditions = JSON_SET(conditions, '$.category', 'coffee') 
      WHERE id = 5 AND JSON_EXTRACT(conditions, '$.category') = 'Coffee'
    `);
    console.log('  Fixed template 5 category condition');
  },

  down: async (conn) => {
    console.log('--- Reverting 025_fix_challenge_constraints ---');

    try {
      await conn.query('ALTER TABLE challenge_progress DROP INDEX unique_user_challenge_id');
    } catch (e) {
      console.log('  Skipped dropping unique_user_challenge_id');
    }

    try {
      await conn.query('ALTER TABLE user_challenges ADD CONSTRAINT unique_active_challenge UNIQUE (user_id, template_id, status)');
    } catch (e) {
      console.log('  Skipped adding unique_active_challenge');
    }

    await conn.query(`
      UPDATE challenge_templates 
      SET conditions = JSON_SET(conditions, '$.category', 'Coffee') 
      WHERE id = 5 AND JSON_EXTRACT(conditions, '$.category') = 'coffee'
    `);
  }
};
