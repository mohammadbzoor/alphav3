const { up } = require('./src/database/migrations/008_add_payment_method');
const { db } = require('./src/config/database');

async function run() {
  try {
    await up();
  } catch(e) {
    console.error(e);
  } finally {
    await db.end();
  }
}
run();
