const express = require('express');
const authRoutes = require('./src/routes/auth.routes');
const onboardingRoutes = require('./src/routes/onboarding.routes');
const financeRoutes = require('./src/routes/finance.routes');
const dashboardRoutes = require('./src/routes/dashboard.routes');
const userRoutes = require('./src/routes/user.routes');
const { errorMiddleware } = require('./src/middleware/error.middleware');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

// Mount routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/onboarding', onboardingRoutes);
app.use('/api/v1', financeRoutes); // contains /expenses, /incomes, /goals
app.use('/api/v1/dashboard', dashboardRoutes);
app.use('/api/v1/users', userRoutes);

app.get('/', (req, res) => {
  res.send('Hello from Node.js Backend!');
});

app.use(errorMiddleware);

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
