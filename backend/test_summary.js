const { DashboardQueryService } = require('./src/services/dashboard.query.service');
const { db } = require('./src/config/database');

async function run() {
  try {
    const summary = await DashboardQueryService.getSummary(1);
    console.log(JSON.stringify(summary, null, 2));
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}
run();
