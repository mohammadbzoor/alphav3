const { db } = require('./src/config/database');
async function run() {
  try {
    const [rows] = await db.execute('SELECT * FROM goal_transactions ORDER BY created_at DESC LIMIT 10');
    console.log('Goal Txs:', rows);
    const [cycles] = await db.execute('SELECT * FROM financial_cycles ORDER BY start_date DESC LIMIT 1');
    console.log('Cycles:', cycles);
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}
run();
