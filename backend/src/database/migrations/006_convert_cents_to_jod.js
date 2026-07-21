const { db } = require('../../config/database');

async function up() {
  console.log('Converting cents to whole JOD...');
  try {
    // Goals
    await db.execute('UPDATE goals SET target_amount = ROUND(target_amount / 100)');
    await db.execute('UPDATE goals SET current_balance = ROUND(current_balance / 100)');
    await db.execute('UPDATE goals SET cycle_allocation = ROUND(cycle_allocation / 100)');

    // Transactions (in case any exist)
    await db.execute('UPDATE transactions SET amount = ROUND(amount / 100)');

    console.log('Successfully converted cents to whole JOD.');
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

async function down() {
  console.log('Reverting whole JOD to cents...');
  try {
    // Goals
    await db.execute('UPDATE goals SET target_amount = target_amount * 100');
    await db.execute('UPDATE goals SET current_balance = current_balance * 100');
    await db.execute('UPDATE goals SET cycle_allocation = cycle_allocation * 100');

    // Transactions
    await db.execute('UPDATE transactions SET amount = amount * 100');

    console.log('Successfully reverted whole JOD to cents.');
  } catch (error) {
    console.error('Rollback failed:', error);
    throw error;
  }
}

module.exports = { up, down };
