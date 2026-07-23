const { db } = require('../../config/database');

async function tableExists(conn, tableName) {
  const [rows] = await conn.execute(
    `SELECT TABLE_NAME
     FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?`,
    [tableName]
  );
  return rows.length > 0;
}

async function columnInfo(conn, tableName, columnName) {
  const [rows] = await conn.execute(
    `SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_TYPE
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = ?
       AND COLUMN_NAME = ?`,
    [tableName, columnName]
  );
  return rows[0] || null;
}

async function indexExists(conn, tableName, indexName) {
  const [rows] = await conn.execute(
    `SELECT INDEX_NAME
     FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = ?
       AND INDEX_NAME = ?`,
    [tableName, indexName]
  );
  return rows.length > 0;
}

async function foreignKeyExists(conn, tableName, constraintName) {
  const [rows] = await conn.execute(
    `SELECT CONSTRAINT_NAME
     FROM information_schema.TABLE_CONSTRAINTS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = ?
       AND CONSTRAINT_TYPE = 'FOREIGN KEY'
       AND CONSTRAINT_NAME = ?`,
    [tableName, constraintName]
  );
  return rows.length > 0;
}

async function checkExists(conn, tableName, constraintName) {
  const [rows] = await conn.execute(
    `SELECT CONSTRAINT_NAME
     FROM information_schema.TABLE_CONSTRAINTS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = ?
       AND CONSTRAINT_TYPE = 'CHECK'
       AND CONSTRAINT_NAME = ?`,
    [tableName, constraintName]
  );
  return rows.length > 0;
}

async function assertCompatibleColumn(conn, tableName, columnName, allowedTypes) {
  const info = await columnInfo(conn, tableName, columnName);
  if (!info) {
    throw new Error(`financial_analyses is missing required column ${columnName}`);
  }
  if (!allowedTypes.includes(info.DATA_TYPE)) {
    throw new Error(`financial_analyses.${columnName} has incompatible type ${info.DATA_TYPE}`);
  }
}

async function up(externalConn = null) {
  const conn = externalConn || db;

  if (!(await tableExists(conn, 'financial_analyses'))) {
    await conn.execute(`
      CREATE TABLE financial_analyses (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        request_identifier CHAR(36) NOT NULL,
        user_id BIGINT UNSIGNED NOT NULL,
        mode VARCHAR(40) NOT NULL,
        scope VARCHAR(60) NOT NULL,
        language VARCHAR(10) NOT NULL,
        status VARCHAR(20) NOT NULL,
        summary TEXT NULL,
        insights_json JSON NULL,
        recommendations_json JSON NULL,
        speech_text TEXT NULL,
        ui_metrics_json JSON NULL,
        data_quality_json JSON NULL,
        audio_url VARCHAR(2048) NULL,
        audio_duration DECIMAL(10,3) NULL,
        analysis_as_of_date DATE NULL,
        generated_at DATETIME(3) NULL,
        error_code VARCHAR(80) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_financial_analyses_request_identifier (request_identifier),
        KEY idx_financial_analyses_user_generated (user_id, generated_at DESC, id DESC),
        KEY idx_financial_analyses_user_status (user_id, status),
        CONSTRAINT fk_financial_analyses_user
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        CONSTRAINT chk_financial_analyses_status
          CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    return;
  }

  await assertCompatibleColumn(conn, 'financial_analyses', 'id', ['bigint', 'int']);
  await assertCompatibleColumn(conn, 'financial_analyses', 'request_identifier', ['char', 'varchar']);
  await assertCompatibleColumn(conn, 'financial_analyses', 'user_id', ['int', 'bigint']);
  await assertCompatibleColumn(conn, 'financial_analyses', 'status', ['varchar', 'enum']);

  const columns = [
    ['mode', `ALTER TABLE financial_analyses ADD COLUMN mode VARCHAR(40) NOT NULL DEFAULT 'financial_snapshot' AFTER user_id`],
    ['scope', `ALTER TABLE financial_analyses ADD COLUMN scope VARCHAR(60) NOT NULL DEFAULT 'current_cycle_to_date' AFTER mode`],
    ['language', `ALTER TABLE financial_analyses ADD COLUMN language VARCHAR(10) NOT NULL DEFAULT 'ar' AFTER scope`],
    ['summary', `ALTER TABLE financial_analyses ADD COLUMN summary TEXT NULL AFTER status`],
    ['insights_json', `ALTER TABLE financial_analyses ADD COLUMN insights_json JSON NULL AFTER summary`],
    ['recommendations_json', `ALTER TABLE financial_analyses ADD COLUMN recommendations_json JSON NULL AFTER insights_json`],
    ['speech_text', `ALTER TABLE financial_analyses ADD COLUMN speech_text TEXT NULL AFTER recommendations_json`],
    ['ui_metrics_json', `ALTER TABLE financial_analyses ADD COLUMN ui_metrics_json JSON NULL AFTER speech_text`],
    ['data_quality_json', `ALTER TABLE financial_analyses ADD COLUMN data_quality_json JSON NULL AFTER ui_metrics_json`],
    ['audio_url', `ALTER TABLE financial_analyses ADD COLUMN audio_url VARCHAR(2048) NULL AFTER data_quality_json`],
    ['audio_duration', `ALTER TABLE financial_analyses ADD COLUMN audio_duration DECIMAL(10,3) NULL AFTER audio_url`],
    ['analysis_as_of_date', `ALTER TABLE financial_analyses ADD COLUMN analysis_as_of_date DATE NULL AFTER audio_duration`],
    ['generated_at', `ALTER TABLE financial_analyses ADD COLUMN generated_at DATETIME(3) NULL AFTER analysis_as_of_date`],
    ['error_code', `ALTER TABLE financial_analyses ADD COLUMN error_code VARCHAR(80) NULL AFTER generated_at`],
    ['created_at', `ALTER TABLE financial_analyses ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER error_code`],
    ['updated_at', `ALTER TABLE financial_analyses ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at`],
  ];

  for (const [columnName, sql] of columns) {
    if (!(await columnInfo(conn, 'financial_analyses', columnName))) {
      await conn.execute(sql);
    }
  }

  if (!(await indexExists(conn, 'financial_analyses', 'uq_financial_analyses_request_identifier'))) {
    await conn.execute(`ALTER TABLE financial_analyses ADD UNIQUE KEY uq_financial_analyses_request_identifier (request_identifier)`);
  }
  if (!(await indexExists(conn, 'financial_analyses', 'idx_financial_analyses_user_generated'))) {
    await conn.execute(`ALTER TABLE financial_analyses ADD KEY idx_financial_analyses_user_generated (user_id, generated_at DESC, id DESC)`);
  }
  if (!(await indexExists(conn, 'financial_analyses', 'idx_financial_analyses_user_status'))) {
    await conn.execute(`ALTER TABLE financial_analyses ADD KEY idx_financial_analyses_user_status (user_id, status)`);
  }
  if (!(await foreignKeyExists(conn, 'financial_analyses', 'fk_financial_analyses_user'))) {
    await conn.execute(`
      ALTER TABLE financial_analyses
      ADD CONSTRAINT fk_financial_analyses_user
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    `);
  }
  if (!(await checkExists(conn, 'financial_analyses', 'chk_financial_analyses_status'))) {
    await conn.execute(`
      ALTER TABLE financial_analyses
      ADD CONSTRAINT chk_financial_analyses_status
      CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
    `);
  }
}

async function down(externalConn = null) {
  const conn = externalConn || db;
  if (await tableExists(conn, 'financial_analyses')) {
    await conn.execute('DROP TABLE financial_analyses');
  }
}

module.exports = { up, down };
