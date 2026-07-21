const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigrations() {
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'alpha',
      port: process.env.DB_PORT || 3306,
      multipleStatements: true
    });

    const migrationsDir = './src/database/migrations';
    const files = fs.readdirSync(migrationsDir).sort();
    
    for (const file of files) {
      if (file.endsWith('.sql') || file.endsWith('.js')) {
        const filePath = path.join(migrationsDir, file);
        console.log(`\nRunning migration: ${file}`);
        
        if (file.endsWith('.sql')) {
          const sql = fs.readFileSync(filePath, 'utf8');
          const statements = sql.split(';').filter(s => s.trim().length > 0);
          
          for (let stmt of statements) {
            try {
              await connection.query(stmt);
              console.log(`  ✓ Executed SQL statement`);
            } catch (err) {
              if (err.code === 'ER_DUP_FIELDNAME' || err.code === 'ER_DUP_KEYNAME') {
                console.log(`  ⚠ Field/key already exists (skipped)`);
              } else {
                throw err;
              }
            }
          }
        } else if (file.endsWith('.js')) {
          const migration = require(path.resolve(filePath));
          await migration.up(connection);
          console.log(`  ✓ Executed JS migration`);
        }
      }
    }
    
    console.log('\n✓ All migrations completed successfully.');
    await connection.end();
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    process.exit(1);
  }
}

runMigrations();
