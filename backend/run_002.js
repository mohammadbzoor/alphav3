const fs = require('fs');
const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigration() {
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: 'root', // overriding to root for ALTER privileges
      password: '',
      database: process.env.DB_NAME || 'alpha',
      port: process.env.DB_PORT || 3306,
      multipleStatements: true
    });

    const sql = fs.readFileSync('./src/database/migrations/002_add_otp_fields.sql', 'utf8');
    
    const statements = sql.split(';').filter(s => s.trim().length > 0);
    
    for (let stmt of statements) {
      console.log('Executing:', stmt);
      await connection.query(stmt);
    }
    
    console.log('Migration completed successfully.');
    await connection.end();
  } catch (err) {
    console.error('Migration failed:', err.message);
  }
}

runMigration();
