const { db } = require('../config/database');

class NotificationRepository {
  static async create(userId, type, category, title, message, actionData) {
    const [result] = await db.execute(
      `INSERT INTO notifications (user_id, type, category, title, message, action_data)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, type, category, title, message, JSON.stringify(actionData || {})]
    );
    return result.insertId;
  }

  static async getForUser(userId, limit = 50, offset = 0) {
    const [rows] = await db.execute(
      `SELECT id, type, category, title, message, action_data as actionData, is_read as isRead, created_at as createdAt
       FROM notifications
       WHERE user_id = ?
       ORDER BY is_read ASC, created_at DESC
       LIMIT ? OFFSET ?`,
      [userId, String(limit), String(offset)]
    );

    // Count unread
    const [countRows] = await db.execute(
      `SELECT COUNT(*) as unreadCount FROM notifications WHERE user_id = ? AND is_read = FALSE`,
      [userId]
    );

    return {
      items: rows,
      unreadCount: Number(countRows[0].unreadCount)
    };
  }

  static async getUnreadCount(userId) {
    const [rows] = await db.execute(
      `SELECT COUNT(*) as unreadCount FROM notifications WHERE user_id = ? AND is_read = FALSE`,
      [userId]
    );
    return Number(rows[0].unreadCount);
  }

  static async markAsRead(userId, notificationId) {
    const [result] = await db.execute(
      `UPDATE notifications SET is_read = TRUE WHERE user_id = ? AND id = ?`,
      [userId, notificationId]
    );
    return result.affectedRows > 0;
  }

  static async markAllAsRead(userId) {
    const [result] = await db.execute(
      `UPDATE notifications SET is_read = TRUE WHERE user_id = ? AND is_read = FALSE`,
      [userId]
    );
    return result.affectedRows;
  }
  static async checkDuplicateBudgetAlert(userId, cycleId, bucket, threshold) {
    const [rows] = await db.execute(
      `SELECT id FROM notifications 
       WHERE user_id = ? 
         AND category = 'budget' 
         AND JSON_EXTRACT(action_data, '$.cycleId') = ? 
         AND JSON_EXTRACT(action_data, '$.bucket') = ? 
         AND JSON_EXTRACT(action_data, '$.threshold') = ?
       LIMIT 1`,
      [userId, cycleId, bucket, threshold]
    );
    return rows.length > 0;
  }
}

module.exports = { NotificationRepository };
