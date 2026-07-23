'use strict';

const { db } = require('../../config/database');

async function tableExists(conn, tableName) {
  const [rows] = await conn.execute(
    `SELECT COUNT(*) as cnt FROM information_schema.tables
     WHERE table_schema = DATABASE() AND table_name = ?`,
    [tableName]
  );
  return rows[0].cnt > 0;
}

exports.up = async function() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    console.log('Running migration 018: Chat AI Tables');

    // ── 1. Create chat_conversations table ───────────────────────────── //
    if (!(await tableExists(conn, 'chat_conversations'))) {
      await conn.query(`
        CREATE TABLE chat_conversations (
          id                          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          user_id                     BIGINT UNSIGNED NOT NULL,
          title                       VARCHAR(255)    NULL,
          status                      ENUM('active','closed','archived') NOT NULL DEFAULT 'active',
          language                    VARCHAR(10)     NOT NULL DEFAULT 'ar',
          channel                     VARCHAR(50)     NOT NULL DEFAULT 'mobile',
          started_at                  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
          last_message_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
          created_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          KEY idx_chat_conversations_user_id (user_id),
          KEY idx_chat_conversations_user_status_lastmsg (user_id, status, last_message_at),
          CONSTRAINT fk_chat_conversations_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `);
      console.log('  chat_conversations: created');
    } else {
      console.log('  chat_conversations: already exists, skipped');
    }

    // ── 2. Create chat_messages table ────────────────────────────────── //
    if (!(await tableExists(conn, 'chat_messages'))) {
      await conn.query(`
        CREATE TABLE chat_messages (
          id                          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          conversation_id             BIGINT UNSIGNED NOT NULL,
          role                        ENUM('user','assistant','system','tool') NOT NULL,
          content                     TEXT            NOT NULL,
          intent                      VARCHAR(100)    NULL,
          status                      ENUM('pending','sent','completed','failed') NOT NULL DEFAULT 'completed',
          metadata                    JSON            NULL,
          created_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          KEY idx_chat_messages_conv_created (conversation_id, created_at),
          KEY idx_chat_messages_status (status),
          CONSTRAINT fk_chat_messages_conversation FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `);
      console.log('  chat_messages: created');
    } else {
      console.log('  chat_messages: already exists, skipped');
    }

    // ── 3. Create chat_requests table ────────────────────────────────── //
    if (!(await tableExists(conn, 'chat_requests'))) {
      await conn.query(`
        CREATE TABLE chat_requests (
          id                          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          conversation_id             BIGINT UNSIGNED NOT NULL,
          user_id                     BIGINT UNSIGNED NOT NULL,
          user_message_id             BIGINT UNSIGNED NULL,
          assistant_message_id        BIGINT UNSIGNED NULL,
          request_identifier          CHAR(36)        NOT NULL,
          provider                    VARCHAR(50)     NOT NULL DEFAULT 'n8n',
          provider_execution_id       VARCHAR(255)    NULL,
          status                      ENUM('pending','processing','completed','failed') NOT NULL DEFAULT 'pending',
          request_payload             JSON            NULL,
          response_payload            JSON            NULL,
          http_status                 SMALLINT UNSIGNED NULL,
          duration_ms                 INT UNSIGNED    NULL,
          retry_count                 TINYINT UNSIGNED NOT NULL DEFAULT 0,
          error_message               TEXT            NULL,
          sent_at                     DATETIME        NULL,
          completed_at                DATETIME        NULL,
          created_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          UNIQUE KEY uq_chat_requests_identifier (request_identifier),
          KEY idx_chat_requests_conversation (conversation_id),
          KEY idx_chat_requests_user_created (user_id, created_at),
          KEY idx_chat_requests_status_created (status, created_at),
          KEY idx_chat_requests_user_message (user_message_id),
          KEY idx_chat_requests_assistant_message (assistant_message_id),
          CONSTRAINT fk_chat_requests_conversation FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE,
          CONSTRAINT fk_chat_requests_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          CONSTRAINT fk_chat_requests_user_message FOREIGN KEY (user_message_id) REFERENCES chat_messages(id) ON DELETE SET NULL,
          CONSTRAINT fk_chat_requests_assistant_message FOREIGN KEY (assistant_message_id) REFERENCES chat_messages(id) ON DELETE SET NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `);
      console.log('  chat_requests: created');
    } else {
      console.log('  chat_requests: already exists, skipped');
    }

    await conn.commit();
    console.log('Migration 018 applied successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 018 failed, rolled back:', err.message);
    throw err;
  } finally {
    conn.release();
  }
};

exports.down = async function() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    console.log('Rolling back migration 018');

    // Due to FK constraints, drop tables in reverse order of creation
    await conn.query('DROP TABLE IF EXISTS chat_requests');
    console.log('  chat_requests: dropped');

    await conn.query('DROP TABLE IF EXISTS chat_messages');
    console.log('  chat_messages: dropped');

    await conn.query('DROP TABLE IF EXISTS chat_conversations');
    console.log('  chat_conversations: dropped');

    await conn.commit();
    console.log('Migration 018 rolled back successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration 018 rollback failed:', err.message);
    throw err;
  } finally {
    conn.release();
  }
};
