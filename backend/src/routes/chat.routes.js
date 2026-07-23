const { Router } = require('express');
const { authenticate } = require('../middleware/auth.middleware');
const chatController = require('../controllers/chat.controller');
const rateLimit = require('express-rate-limit');
const { AppError } = require('../utils/app-error');

const router = Router();

// Focused rate limiter for chat endpoints
const chatRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // 10 requests per minute per IP
  handler: (req, res, next) => {
    next(new AppError('Too many chat requests, please try again later.', 429, 'CHAT_UPSTREAM_RATE_LIMITED'));
  },
  standardHeaders: true,
  legacyHeaders: false,
});

router.post('/messages', authenticate, chatRateLimiter, chatController.sendMessage);

module.exports = router;