const express = require('express');
const multer = require('multer');
const { VoiceController } = require('../controllers/voice.controller');
const { authenticate } = require('../middleware/auth.middleware');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    console.log(`VOICE_UPLOAD originalExtension=.${file.originalname.split('.').pop()}`);
    console.log(`VOICE_UPLOAD mimetype=${file.mimetype}`);
    console.log(`VOICE_UPLOAD fieldname=${file.fieldname}`);
    console.log(`VOICE_UPLOAD sizeAvailableAtFilter=${!!file.size}`);

    const allowedMimeTypes = ['audio/mp4', 'audio/x-m4a', 'audio/m4a', 'audio/aac'];
    if (allowedMimeTypes.includes(file.mimetype)) {
      console.log(`VOICE_UPLOAD accepted=true`);
      cb(null, true);
    } else {
      const error = new Error('UNSUPPORTED_AUDIO_FORMAT');
      error.code = 'UNSUPPORTED_AUDIO_FORMAT';
      cb(error, false);
    }
  }
});

const uploadMiddleware = (req, res, next) => {
  upload.single('audio')(req, res, (err) => {
    if (err) {
      if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
          return res.status(413).json({
            success: false,
            code: 'VOICE_FILE_TOO_LARGE',
            message: 'The voice recording is too large. Please record a shorter message.',
            data: null,
            meta: null
          });
        }
        if (err.code === 'LIMIT_UNEXPECTED_FILE') {
          return res.status(400).json({
            success: false,
            code: 'INVALID_AUDIO_FIELD',
            message: 'Unexpected file field.',
            data: null,
            meta: null
          });
        }
      } else if (err.code === 'UNSUPPORTED_AUDIO_FORMAT') {
        return res.status(415).json({
          success: false,
          code: 'UNSUPPORTED_AUDIO_FORMAT',
          message: 'The audio format is not supported.',
          data: null,
          meta: null
        });
      }
      return res.status(500).json({
        success: false,
        code: 'UPLOAD_ERROR',
        message: 'Unable to analyze the voice recording. Please try again.',
        data: null,
        meta: null
      });
    }
    next();
  });
};

router.post('/parse', authenticate, uploadMiddleware, VoiceController.parse);

module.exports = router;
