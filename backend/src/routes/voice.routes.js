const express = require('express');
const multer = require('multer');
const { VoiceController } = require('../controllers/voice.controller');
const { authenticate } = require('../middleware/auth.middleware');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

router.post('/parse', authenticate, upload.single('audio'), VoiceController.parse);

module.exports = router;
