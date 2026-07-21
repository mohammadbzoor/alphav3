const mysql = require('mysql2/promise');
require('dotenv').config();

async function checkSchema() {
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      port: process.env.DB_PORT || 3306
    });

    console.log('\n=== USERS TABLE ===');
    const [usersRows] = await connection.query('SHOW CREATE TABLE users');
    console.log(usersRows[0]['Create Table']);

    console.log('\n=== USER_PROFILES TABLE ===');
    const [profilesRows] = await connection.query('SHOW CREATE TABLE user_profiles');
    console.log(profilesRows[0]['Create Table']);

    await connection.end();
  } catch (err) {
    console.error('Error:', err.message);
  }
}

checkSchema();
