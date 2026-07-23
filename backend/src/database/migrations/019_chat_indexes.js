const { db } = require('../../config/database');

module.exports = {
  up: async () => {
    console.log('Running migration 019: Chat AI Pagination Indexes');
    const connection = await db.getConnection();
    
    try {
      await connection.query(`
        ALTER TABLE chat_conversations
        ADD INDEX idx_chat_conversations_user_lastmsg_id (user_id, last_message_at, id)
      `);
      console.log('  idx_chat_conversations_user_lastmsg_id: created');
    } catch (err) {
      if (err.code === 'ER_DUP_KEYNAME') {
        console.log('  idx_chat_conversations_user_lastmsg_id: already exists, skipped');
      } else {
        throw err;
      }
    } finally {
      connection.release();
    }
  },

  down: async () => {
    const connection = await db.getConnection();
    try {
      await connection.query(`
        ALTER TABLE chat_conversations
        DROP INDEX idx_chat_conversations_user_lastmsg_id
      `);
      console.log('  idx_chat_conversations_user_lastmsg_id: dropped');
    } catch (err) {
      if (err.code === 'ER_CANT_DROP_FIELD_OR_KEY') {
        console.log('  idx_chat_conversations_user_lastmsg_id: does not exist, skipped');
      } else {
        throw err;
      }
    } finally {
      connection.release();
    }
  }
};
