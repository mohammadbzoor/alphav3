const express = require('express');
const router = express.Router();
const { AnalysisController } = require('../controllers/analysis.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.get('/', authenticate, AnalysisController.list);
router.get('/:id', authenticate, AnalysisController.detail);
router.post('/', authenticate, AnalysisController.generate);

module.exports = router;
