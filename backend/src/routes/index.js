const { Router } = require('express');
const authRoutes = require('./auth.routes');
const onboardingRoutes = require('./onboarding.routes');
const financeRoutes = require('./finance.routes');
const dashboardRoutes = require('./dashboard.routes');
const userRoutes = require('./user.routes');
const receiptsRoutes = require('./receipts.routes');
const voiceRoutes = require('./voice.routes');
const cycleRoutes = require('./cycle.routes');
const chatRoutes = require('./chat.routes');
const analysisRoutes = require('./analysis.routes');

const router = Router();

router.use('/auth', authRoutes);
router.use('/onboarding', onboardingRoutes);
router.use('/', financeRoutes); // contains /expenses, /incomes, /goals
router.use('/dashboard', dashboardRoutes);
router.use('/users', userRoutes);
router.use('/receipts', receiptsRoutes);
router.use('/voice', voiceRoutes);
router.use('/financial-cycles', cycleRoutes);
router.use('/chat', chatRoutes);
router.use('/financial-analysis', analysisRoutes);

module.exports = router;
