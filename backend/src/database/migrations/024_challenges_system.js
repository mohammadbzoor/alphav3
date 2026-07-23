const { db } = require('../../config/database');

async function up() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    await conn.execute(`
      CREATE TABLE IF NOT EXISTS challenge_templates (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        challenge_type ENUM('individual') NOT NULL DEFAULT 'individual',
        metric_type ENUM('wants_spending_limit', 'savings_amount', 'goal_contribution_count', 'expense_tracking_days', 'no_spend_category') NOT NULL,
        target_value DECIMAL(15, 2) NOT NULL,
        duration_days INT NOT NULL,
        xp_reward INT NOT NULL DEFAULT 0,
        icon VARCHAR(50) NOT NULL DEFAULT 'star',
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        conditions JSON NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    `);

    await conn.execute(`
      CREATE TABLE IF NOT EXISTS user_challenges (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        user_id BIGINT UNSIGNED NOT NULL,
        template_id INT NOT NULL,
        cycle_id BIGINT UNSIGNED NULL,
        status ENUM('current', 'completed', 'failed', 'cancelled') NOT NULL DEFAULT 'current',
        start_date TIMESTAMP NOT NULL,
        end_date TIMESTAMP NOT NULL,
        accepted_at TIMESTAMP NOT NULL,
        completed_at TIMESTAMP NULL,
        failed_at TIMESTAMP NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (template_id) REFERENCES challenge_templates(id) ON DELETE CASCADE,
        FOREIGN KEY (cycle_id) REFERENCES financial_cycles(id) ON DELETE SET NULL,
        UNIQUE KEY unique_active_challenge (user_id, template_id, status)
      ) ENGINE=InnoDB;
    `);

    await conn.execute(`
      CREATE TABLE IF NOT EXISTS challenge_progress (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        user_challenge_id BIGINT UNSIGNED NOT NULL,
        current_value DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
        target_value DECIMAL(15, 2) NOT NULL,
        progress_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
        last_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_challenge_id) REFERENCES user_challenges(id) ON DELETE CASCADE
      ) ENGINE=InnoDB;
    `);

    // Seed templates
    const templates = [
      {
        title: "Keep Wants Under Limit",
        description: "Keep your 'Wants' spending under the cycle budget limit.",
        metric_type: "wants_spending_limit",
        target_value: 100,
        duration_days: 7,
        xp_reward: 100,
        icon: "savings",
        conditions: JSON.stringify({ bucket: 'wants', comparison: 'less_than_or_equal', category: null })
      },
      {
        title: "Save 50 JD",
        description: "Save 50 JD during this cycle.",
        metric_type: "savings_amount",
        target_value: 50,
        duration_days: 7,
        xp_reward: 150,
        icon: "💰",
        conditions: JSON.stringify({})
      },
      {
        title: "Goal Setter",
        description: "Contribute to your financial goals 3 times.",
        metric_type: "goal_contribution_count",
        target_value: 3,
        duration_days: 14,
        xp_reward: 120,
        icon: "🎯",
        conditions: JSON.stringify({})
      },
      {
        title: "Expense Tracker",
        description: "Track expenses for 7 consecutive days.",
        metric_type: "expense_tracking_days",
        target_value: 7,
        duration_days: 7,
        xp_reward: 80,
        icon: "✅",
        conditions: JSON.stringify({})
      },
      {
        title: "No Coffee Week",
        description: "Avoid spending at coffee shops for seven days.",
        metric_type: "no_spend_category",
        target_value: 0,
        duration_days: 7,
        xp_reward: 90,
        icon: "☕",
        conditions: JSON.stringify({ bucket: 'wants', category: 'Coffee' })
      }
    ];

    for (const t of templates) {
      await conn.execute(
        `INSERT INTO challenge_templates (title, description, metric_type, target_value, duration_days, xp_reward, icon, conditions)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [t.title, t.description, t.metric_type, t.target_value, t.duration_days, t.xp_reward, t.icon, t.conditions]
      );
    }

    await conn.commit();
    console.log('Migration 024_challenges_system applied successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Error in migration 024_challenges_system:', err);
    throw err;
  } finally {
    conn.release();
  }
}

async function down() {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    await conn.execute(`DROP TABLE IF EXISTS challenge_progress;`);
    await conn.execute(`DROP TABLE IF EXISTS user_challenges;`);
    await conn.execute(`DROP TABLE IF EXISTS challenge_templates;`);
    await conn.commit();
    console.log('Migration 024_challenges_system reverted successfully.');
  } catch (err) {
    await conn.rollback();
    console.error('Error reverting migration 024_challenges_system:', err);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { up, down };
