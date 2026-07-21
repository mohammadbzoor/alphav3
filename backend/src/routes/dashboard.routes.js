const express = require('express');
const { DashboardController } = require('../controllers/dashboard.controller');
const { authenticate } = require('../middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get('/summary', DashboardController.getSummary);

module.exports = router;
