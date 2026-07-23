const express = require('express');
const { NotificationController } = require('../controllers/notification.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../utils/async-handler');

const router = express.Router();

// Webhook endpoint (should have separate auth in production, e.g., API Key, but kept open internally for now)
router.post('/webhook', asyncHandler(NotificationController.webhook));

// Protected routes (Require JWT)
router.use(authenticate);

router.get('/', asyncHandler(NotificationController.getNotifications));
router.get('/unread-count', asyncHandler(NotificationController.getUnreadCount));
router.put('/read-all', asyncHandler(NotificationController.markAllAsRead));
router.put('/:id/read', asyncHandler(NotificationController.markAsRead));

module.exports = router;
