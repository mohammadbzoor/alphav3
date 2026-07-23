const { db } = require('../config/database');
const fs = require('fs');
const path = require('path');

async function run() {
  try {
    const conn = await db.getConnection();
    const migrationsDir = path.join(__dirname, 'migrations');
    const files = fs.readdirSync(migrationsDir).sort();
    
    for (const file of files) {
      if (file.endsWith('.js') && file !== 'run_migrations.js') {
        const migration = require(path.join(migrationsDir, file));
        if (migration.up) {
          try {
            await migration.up(conn);
          } catch (e) {
            console.error(`Error running migration ${file}:`, e);
          }
        }
      }
    }
    conn.release();
    console.log('All migrations checked.');
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}
run();
