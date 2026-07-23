module.exports = {
  up: async (conn) => {
    console.log('--- Applying 023_add_notifications ---');

    const [rows] = await conn.query("SHOW TABLES LIKE 'notifications'");
    if (rows.length === 0) {
      await conn.query(`
        CREATE TABLE notifications (
          id BIGINT AUTO_INCREMENT PRIMARY KEY,
          user_id BIGINT UNSIGNED NOT NULL,
          type ENUM('info', 'success', 'warning', 'critical') DEFAULT 'info',
          category ENUM('budget', 'goal', 'cycle', 'system', 'ai') NOT NULL,
          title VARCHAR(255) NOT NULL,
          message TEXT NOT NULL,
          action_data JSON DEFAULT NULL,
          is_read BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
      `);
      console.log('  notifications: created');
    } else {
      console.log('  notifications: already exists, skipped');
    }
  },

  down: async (conn) => {
    console.log('--- Reverting 022_add_notifications ---');
    await conn.query('DROP TABLE IF EXISTS notifications');
  }
};
