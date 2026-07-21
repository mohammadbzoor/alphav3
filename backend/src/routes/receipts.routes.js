const express = require('express');
const multer = require('multer');
const { ReceiptsController } = require('../controllers/receipts.controller');
const { authenticate } = require('../middleware/auth.middleware');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

router.post('/analyze', authenticate, upload.single('receipt'), ReceiptsController.analyze);

module.exports = router;
