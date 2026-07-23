const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const crypto = require('crypto');
require('dotenv').config();

function getChecksum(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

async function runMigrations() {
  let connection;
  try {
    // Migration user should ideally have CREATE, ALTER, DROP, INDEX, REFERENCES, etc.
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'alpha',
      port: process.env.DB_PORT || 3306,
      multipleStatements: true
    });

    console.log(`\n[Migrations] Connected to database: ${process.env.DB_NAME}`);

    // 1. Acquire advisory lock
    const [lockResult] = await connection.query(`SELECT GET_LOCK('alpha_migrations_lock', 10) AS lock_acquired`);
    if (!lockResult[0].lock_acquired) {
      throw new Error('Could not acquire migration lock. Another migration might be running.');
    }
    console.log(`[Migrations] Acquired advisory lock.`);

    // 2. Ensure ledger exists
    await connection.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        checksum VARCHAR(64) NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB
    `);

    // 3. Discover files
    const migrationsDir = path.join(__dirname, 'src', 'database', 'migrations');
    const files = fs.readdirSync(migrationsDir).sort().filter(f => f.endsWith('.sql') || f.endsWith('.js'));

    // 4. Load applied migrations
    const [appliedRows] = await connection.query(`SELECT filename, checksum FROM schema_migrations ORDER BY id ASC`);
    const appliedMap = new Map(appliedRows.map(r => [r.filename, r.checksum]));

    for (const file of files) {
      const filePath = path.join(migrationsDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      const currentChecksum = getChecksum(content);

      if (appliedMap.has(file)) {
        // 9. Detect checksum changes
        if (appliedMap.get(file) !== currentChecksum) {
          throw new Error(`Checksum mismatch for applied migration: ${file}. Expected ${appliedMap.get(file)} but got ${currentChecksum}`);
        }
        console.log(`[Migrations] Skipped (already applied): ${file}`);
        continue;
      }

      console.log(`\n[Migrations] Running migration: ${file}`);
      
      // We cannot guarantee DDL rollback via transactions in MySQL (implicit commits).
      // If a migration fails mid-way, it will halt and require manual intervention.
      try {
        if (file.endsWith('.sql')) {
          await connection.query(content);
        } else if (file.endsWith('.js')) {
          const migration = require(path.resolve(filePath));
          await migration.up(connection);
        }

        // 6. Record success
        await connection.query(`INSERT INTO schema_migrations (filename, checksum) VALUES (?, ?)`, [file, currentChecksum]);
        console.log(`[Migrations] ✓ Completed and recorded: ${file}`);
      } catch (err) {
        // 7, 8. Stop on failure, never swallow
        console.error(`\n[Migrations] ❌ FAILED on ${file}:`, err.message);
        throw err;
      }
    }

    console.log('\n[Migrations] ✓ All unapplied migrations completed successfully.');
  } catch (err) {
    console.error('\n[Migrations] ❌ Migration process aborted:', err.message);
    process.exitCode = 1;
  } finally {
    if (connection) {
      // 10. Release lock
      try {
        await connection.query(`SELECT RELEASE_LOCK('alpha_migrations_lock')`);
        console.log(`[Migrations] Released advisory lock.`);
      } catch (e) {
        console.error('[Migrations] Failed to release lock:', e.message);
      }
      await connection.end();
    }
  }
}

runMigrations();
