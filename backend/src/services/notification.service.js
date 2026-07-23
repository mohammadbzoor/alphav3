const { NotificationRepository } = require('../repositories/notification.repository');
const { AppError } = require('../middleware/error.middleware');
const axios = require('axios');

class NotificationService {
  static async forwardEventToN8n(userId, eventType, data) {
    const WEBHOOK_URL = process.env.N8N_NOTIFICATION_WEBHOOK_URL;
    if (!WEBHOOK_URL) return false;

    try {
      await axios.post(WEBHOOK_URL, {
        userId,
        eventType,
        data,
        timestamp: new Date().toISOString()
      }, {
        timeout: 10000
      });
      return true;
    } catch (error) {
      console.error('Failed to forward event to N8N notifications webhook:', error.message);
      return false;
    }
  }
  static async createNotification(userId, data) {
    const { type = 'info', category, title, message, action_data } = data;

    if (!category || !title || !message) {
      throw new AppError('Missing required notification fields', 400, 'INVALID_PAYLOAD');
    }

    const validTypes = ['info', 'success', 'warning', 'critical'];
    if (!validTypes.includes(type)) {
      throw new AppError('Invalid notification type', 400, 'INVALID_PAYLOAD');
    }

    const validCategories = ['budget', 'goal', 'cycle', 'system', 'ai'];
    if (!validCategories.includes(category)) {
      throw new AppError('Invalid notification category', 400, 'INVALID_PAYLOAD');
    }

    const id = await NotificationRepository.create(userId, type, category, title, message, action_data);
    return { id, type, category, title, message, action_data };
  }

  static async getNotifications(userId, limit = 50, offset = 0) {
    return await NotificationRepository.getForUser(userId, limit, offset);
  }

  static async getUnreadCount(userId) {
    const count = await NotificationRepository.getUnreadCount(userId);
    return { unreadCount: count };
  }

  static async markAsRead(userId, notificationId) {
    const success = await NotificationRepository.markAsRead(userId, notificationId);
    if (!success) {
      throw new AppError('Notification not found or unauthorized', 404, 'NOT_FOUND');
    }
    return { success: true };
  }

  static async markAllAsRead(userId) {
    const updatedCount = await NotificationRepository.markAllAsRead(userId);
    return { success: true, updatedCount };
  }
}

module.exports = { NotificationService };
