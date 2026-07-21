const { app } = require('./app');
const { env } = require('./config/env');
const { db } = require('./config/database');

const startServer = async () => {
  try {
    // Test DB connection
    await db.query('SELECT 1');
    console.log('Connected to MySQL Database');

    app.listen(env.port, () => {
      console.log(`Server is running on port ${env.port}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();
