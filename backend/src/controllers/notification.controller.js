const { NotificationService } = require('../services/notification.service');

class NotificationController {
  static async getNotifications(req, res) {
    const limit = parseInt(req.query.limit, 10) || 50;
    const offset = parseInt(req.query.offset, 10) || 0;

    const result = await NotificationService.getNotifications(req.user.id, limit, offset);
    res.status(200).json({
      success: true,
      data: result,
      meta: null
    });
  }

  static async getUnreadCount(req, res) {
    const result = await NotificationService.getUnreadCount(req.user.id);
    res.status(200).json({
      success: true,
      data: result,
      meta: null
    });
  }

  static async markAsRead(req, res) {
    const { id } = req.params;
    const result = await NotificationService.markAsRead(req.user.id, id);
    res.status(200).json({
      success: true,
      data: result,
      meta: null
    });
  }

  static async markAllAsRead(req, res) {
    const result = await NotificationService.markAllAsRead(req.user.id);
    res.status(200).json({
      success: true,
      data: result,
      meta: null
    });
  }

  static async webhook(req, res) {
    // Expected payload: { userId, type, category, title, message, action_data }
    const { userId, type, category, title, message, action_data } = req.body;
    
    // Webhooks might be called by external services like n8n or internal modules without standard JWT auth.
    // For now, assuming internal services pass userId directly. 
    // In production, we'd verify an API key for the webhook.
    if (!userId) {
      return res.status(400).json({ success: false, message: 'Missing userId' });
    }

    const data = { type, category, title, message, action_data };
    const result = await NotificationService.createNotification(userId, data);

    res.status(201).json({
      success: true,
      message: 'Notification created successfully via webhook',
      data: result
    });
  }
}

module.exports = { NotificationController };
