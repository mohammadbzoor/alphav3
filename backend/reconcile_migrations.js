const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const crypto = require('crypto');
require('dotenv').config();

function getChecksum(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

async function verifyTableSchema(conn, dbName, tableName, expectedColumns, expectedIndexes, expectedFks) {
  // Check Columns
  const [columns] = await conn.query(`
    SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
    FROM information_schema.COLUMNS 
    WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
  `, [dbName, tableName]);

  if (columns.length === 0) return { valid: false, error: `Table ${tableName} does not exist.` };

  const colMap = new Map(columns.map(c => [c.COLUMN_NAME, c]));
  for (const exp of expectedColumns) {
    const act = colMap.get(exp.name);
    if (!act) return { valid: false, error: `Missing column ${tableName}.${exp.name}` };
    
    // Normalize types (MySQL might return 'bigint unsigned' or 'bigint(20) unsigned')
    const typeExp = exp.type.toLowerCase().replace(/\(\d+\)/, '');
    const typeAct = act.COLUMN_TYPE.toLowerCase().replace(/\(\d+\)/, '');
    if (typeExp !== typeAct) return { valid: false, error: `Type mismatch on ${tableName}.${exp.name}: expected ${typeExp}, got ${typeAct}` };
    
    if (act.IS_NULLABLE !== (exp.nullable ? 'YES' : 'NO')) {
      return { valid: false, error: `Nullability mismatch on ${tableName}.${exp.name}` };
    }
    
    const defExp = exp.default === null ? null : exp.default;
    let defAct = act.COLUMN_DEFAULT;
    if (defAct === 'CURRENT_TIMESTAMP') defAct = defAct;
    else if (defAct && defAct.startsWith("'") && defAct.endsWith("'")) defAct = defAct.slice(1, -1);
    
    // CURRENT_TIMESTAMP matching might be tricky, skip exact if both have it
    const expIsTs = (defExp === 'CURRENT_TIMESTAMP');
    const actIsTs = (act.COLUMN_DEFAULT === 'CURRENT_TIMESTAMP');
    
    if (defExp !== undefined && !expIsTs && defExp !== defAct) {
      if (defExp === null && defAct === null) {} // OK
      else return { valid: false, error: `Default mismatch on ${tableName}.${exp.name}: expected ${defExp}, got ${defAct}` };
    }

    if (exp.extra && !act.EXTRA.includes(exp.extra)) {
       return { valid: false, error: `Extra mismatch on ${tableName}.${exp.name}: expected ${exp.extra}, got ${act.EXTRA}` };
    }
  }

  // Check Indexes
  const [indexes] = await conn.query(`
    SELECT INDEX_NAME, COLUMN_NAME, SEQ_IN_INDEX, NON_UNIQUE
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
    ORDER BY INDEX_NAME, SEQ_IN_INDEX
  `, [dbName, tableName]);

  const idxMap = {};
  for (const row of indexes) {
    if (!idxMap[row.INDEX_NAME]) idxMap[row.INDEX_NAME] = { cols: [], unique: row.NON_UNIQUE === 0 };
    idxMap[row.INDEX_NAME].cols.push(row.COLUMN_NAME);
  }

  for (const exp of expectedIndexes) {
    const act = idxMap[exp.name];
    if (!act) return { valid: false, error: `Missing index ${tableName}.${exp.name}` };
    if (act.unique !== exp.unique) return { valid: false, error: `Uniqueness mismatch on index ${tableName}.${exp.name}` };
    if (act.cols.join(',') !== exp.cols.join(',')) return { valid: false, error: `Column mismatch on index ${tableName}.${exp.name}: expected ${exp.cols.join(',')}, got ${act.cols.join(',')}` };
  }

  // Check Foreign Keys
  const [fks] = await conn.query(`
    SELECT k.CONSTRAINT_NAME, k.COLUMN_NAME, k.REFERENCED_TABLE_NAME, k.REFERENCED_COLUMN_NAME, rc.DELETE_RULE
    FROM information_schema.KEY_COLUMN_USAGE k
    JOIN information_schema.REFERENTIAL_CONSTRAINTS rc ON k.CONSTRAINT_NAME = rc.CONSTRAINT_NAME
    WHERE k.TABLE_SCHEMA = ? AND k.TABLE_NAME = ? AND k.REFERENCED_TABLE_NAME IS NOT NULL
  `, [dbName, tableName]);

  const fkMap = new Map(fks.map(f => [f.COLUMN_NAME, f]));
  for (const exp of expectedFks) {
    const act = fkMap.get(exp.column);
    if (!act) return { valid: false, error: `Missing FK on ${tableName}.${exp.column}` };
    if (act.REFERENCED_TABLE_NAME !== exp.refTable) return { valid: false, error: `FK ref table mismatch on ${tableName}.${exp.column}` };
    if (act.DELETE_RULE !== exp.onDelete) return { valid: false, error: `FK ON DELETE mismatch on ${tableName}.${exp.column}: expected ${exp.onDelete}, got ${act.DELETE_RULE}` };
  }

  return { valid: true };
}

async function reconcile() {
  let connection;
  try {
    console.log('==================================================');
    console.log('  MANUAL MIGRATION RECONCILIATION SCRIPT');
    console.log('==================================================');
    const dbName = process.env.DB_NAME || 'alpha';
    console.log(`Target Database: ${dbName}`);
    
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: dbName,
      port: process.env.DB_PORT || 3306
    });

    await connection.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        checksum VARCHAR(64) NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB
    `);

    // ==========================================
    // Verify 018
    // ==========================================
    let ok018 = true;
    const tConv = await verifyTableSchema(connection, dbName, 'chat_conversations', [
      { name: 'id', type: 'bigint unsigned', nullable: false, extra: 'auto_increment' },
      { name: 'user_id', type: 'bigint unsigned', nullable: false },
      { name: 'title', type: 'varchar', nullable: true, default: null },
      { name: 'status', type: "enum('active','closed')", nullable: false, default: 'active' },
      { name: 'language', type: 'varchar', nullable: false, default: 'ar' },
      { name: 'channel', type: 'varchar', nullable: false, default: 'mobile' },
      { name: 'started_at', type: 'datetime', nullable: false, default: 'CURRENT_TIMESTAMP' },
      { name: 'last_message_at', type: 'datetime', nullable: false, default: 'CURRENT_TIMESTAMP' },
    ], [
      { name: 'PRIMARY', unique: true, cols: ['id'] },
      { name: 'idx_chat_conversations_user_status', unique: false, cols: ['user_id','status'] }
    ], [
      { column: 'user_id', refTable: 'users', onDelete: 'CASCADE' }
    ]);
    if (!tConv.valid) { console.log('[018 Reconcile Failed]', tConv.error); ok018 = false; }

    const tMsg = await verifyTableSchema(connection, dbName, 'chat_messages', [
      { name: 'id', type: 'bigint unsigned', nullable: false, extra: 'auto_increment' },
      { name: 'conversation_id', type: 'bigint unsigned', nullable: false },
      { name: 'role', type: "enum('user','assistant','system')", nullable: false },
      { name: 'content', type: 'text', nullable: false },
      { name: 'intent', type: 'varchar', nullable: true, default: null },
      { name: 'status', type: "enum('pending','completed','failed')", nullable: false, default: 'completed' },
      { name: 'metadata', type: 'json', nullable: true, default: null },
    ], [
      { name: 'PRIMARY', unique: true, cols: ['id'] },
      { name: 'idx_chat_messages_conv_created', unique: false, cols: ['conversation_id','created_at'] }
    ], [
      { column: 'conversation_id', refTable: 'chat_conversations', onDelete: 'CASCADE' }
    ]);
    if (!tMsg.valid) { console.log('[018 Reconcile Failed]', tMsg.error); ok018 = false; }

    const tReq = await verifyTableSchema(connection, dbName, 'chat_requests', [
      { name: 'id', type: 'bigint unsigned', nullable: false, extra: 'auto_increment' },
      { name: 'conversation_id', type: 'bigint unsigned', nullable: false },
      { name: 'user_id', type: 'bigint unsigned', nullable: false },
      { name: 'user_message_id', type: 'bigint unsigned', nullable: true, default: null },
      { name: 'assistant_message_id', type: 'bigint unsigned', nullable: true, default: null },
      { name: 'request_identifier', type: 'varchar', nullable: false },
      { name: 'provider', type: 'varchar', nullable: false, default: 'n8n' },
      { name: 'status', type: "enum('pending','processing','completed','failed')", nullable: false, default: 'pending' },
      { name: 'http_status', type: 'smallint unsigned', nullable: true, default: null },
      { name: 'duration_ms', type: 'int unsigned', nullable: true, default: null },
      { name: 'retry_count', type: 'tinyint unsigned', nullable: false, default: '0' },
    ], [
      { name: 'PRIMARY', unique: true, cols: ['id'] },
      { name: 'request_identifier', unique: true, cols: ['request_identifier'] }
    ], [
      { column: 'conversation_id', refTable: 'chat_conversations', onDelete: 'CASCADE' },
      { column: 'user_id', refTable: 'users', onDelete: 'CASCADE' },
      { column: 'user_message_id', refTable: 'chat_messages', onDelete: 'SET NULL' },
      { column: 'assistant_message_id', refTable: 'chat_messages', onDelete: 'SET NULL' }
    ]);
    if (!tReq.valid) { console.log('[018 Reconcile Failed]', tReq.error); ok018 = false; }

    if (ok018) {
      const filePath = path.join(__dirname, 'src', 'database', 'migrations', '018_chat_ai_tables.js');
      const content = fs.readFileSync(filePath, 'utf8');
      const checksum = getChecksum(content);
      await connection.query(`INSERT IGNORE INTO schema_migrations (filename, checksum) VALUES (?, ?)`, ['018_chat_ai_tables.js', checksum]);
      console.log('[Reconcile] ✓ 018_chat_ai_tables.js safely reconciled.');
    } else {
      console.log('[Reconcile] 018 schemas do not match. Not reconciled.');
    }

    // ==========================================
    // Verify 019
    // ==========================================
    let ok019 = true;
    const t019 = await verifyTableSchema(connection, dbName, 'chat_conversations', [], [
      { name: 'idx_chat_conversations_user_lastmsg_id', unique: false, cols: ['user_id', 'last_message_at', 'id'] }
    ], []);
    if (!t019.valid) { console.log('[019 Reconcile Failed]', t019.error); ok019 = false; }

    if (ok019) {
      const filePath = path.join(__dirname, 'src', 'database', 'migrations', '019_chat_indexes.js');
      const content = fs.readFileSync(filePath, 'utf8');
      const checksum = getChecksum(content);
      await connection.query(`INSERT IGNORE INTO schema_migrations (filename, checksum) VALUES (?, ?)`, ['019_chat_indexes.js', checksum]);
      console.log('[Reconcile] ✓ 019_chat_indexes.js safely reconciled.');
    } else {
      console.log('[Reconcile] 019 schemas do not match. Not reconciled.');
    }

    console.log('Reconciliation complete.');
  } catch (err) {
    console.error('Reconciliation failed:', err.message);
  } finally {
    if (connection) await connection.end();
  }
}

// Do not run automatically on app startup. Explicit execution required.
if (require.main === module) {
  reconcile();
}
