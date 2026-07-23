const { db } = require('../config/database');

class ChatContextRepository {
  /**
   * Retrieves the current active financial cycle for a user.
   */
  static async getCurrentCycleForChat(userId) {
    const [cycles] = await db.execute(
      `SELECT id, status, start_date, end_date, expected_income 
       FROM financial_cycles 
       WHERE user_id = ? AND status = 'open' 
       ORDER BY start_date DESC LIMIT 1`,
      [userId]
    );
    return cycles.length > 0 ? cycles[0] : null;
  }

  /**
   * Retrieves the user's financial profile.
   */
  static async getFinancialProfileForChat(userId) {
    const [profiles] = await db.execute(
      `SELECT currency, expected_monthly_income, timezone, onboarding_status
       FROM financial_profiles 
       WHERE user_id = ? LIMIT 1`,
      [userId]
    );
    return profiles.length > 0 ? profiles[0] : null;
  }

  /**
   * Retrieves user basic data.
   */
  static async getUserForChat(userId) {
    const [users] = await db.execute(
      `SELECT id, full_name, is_onboarded, account_status
       FROM users 
       WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
      [userId]
    );
    return users.length > 0 ? users[0] : null;
  }

  /**
   * Verifies conversation ownership and status.
   */
  static async getConversationForChat(conversationId, userId) {
    const [convs] = await db.execute(
      `SELECT id, user_id, status, language, channel
       FROM chat_conversations 
       WHERE id = ? AND user_id = ? LIMIT 1`,
      [conversationId, userId]
    );
    return convs.length > 0 ? convs[0] : null;
  }

  /**
   * Retrieves recent qualifying transactions.
   * Prefer current cycle. Exclude cancelled/reversed if any. 
   */
  static async getRecentCycleTransactionsForChat(userId, cycleId, limit) {
    // If cycleId is null, we can return empty array or global history.
    // Requirement: "If the user does not have an active cycle: Return transactions as an empty array by default."
    if (!cycleId) return [];
    
    // Explicit projection.
    const [rows] = await db.execute(
      `SELECT id, occurred_at as date, transaction_type as type, direction, amount, category, description, status 
       FROM transactions 
       WHERE user_id = ? 
         AND cycle_id = ? 
         AND status = 'confirmed' 
         AND transaction_type IN ('expense', 'income')
       ORDER BY occurred_at DESC, id DESC 
       LIMIT ?`,
      [userId, cycleId, limit.toString()]
    );
    return rows;
  }

  /**
   * Retrieves active goals.
   */
  static async getActiveGoalsForChat(userId, limit) {
    const [rows] = await db.execute(
      `SELECT id, name, target_amount, current_balance, planned_contribution, target_date, status 
       FROM goals 
       WHERE user_id = ? AND status IN ('active', 'ready') 
       ORDER BY target_date ASC, id ASC 
       LIMIT ?`,
      [userId, limit.toString()]
    );
    return rows;
  }

  /**
   * Retrieves relevant commitments (unpaid upcoming/due/overdue in cycle, plus active monthly).
   */
  static async getCommitmentsForChat(userId, cycleId, limit) {
    if (!cycleId) return { monthlyTotal: 0, occurrences: [] };

    // 1. Calculate total active monthly commitments amount
    const [monthlyRows] = await db.execute(
      `SELECT SUM(amount) as total 
       FROM financial_commitments 
       WHERE user_id = ? AND status = 'active' AND frequency = 'monthly'`,
      [userId]
    );
    const monthlyTotal = monthlyRows[0].total ? Number(monthlyRows[0].total) : 0;

    // 2. Get specific occurrences for the cycle
    const [occurrences] = await db.execute(
      `SELECT co.id, fc.name, co.amount, co.due_date, co.status 
       FROM commitment_occurrences co
       JOIN financial_commitments fc ON fc.id = co.commitment_id 
       WHERE fc.user_id = ? AND co.cycle_id = ? AND co.status IN ('upcoming', 'due', 'overdue')
       ORDER BY co.due_date ASC, co.id ASC 
       LIMIT ?`,
      [userId, cycleId, limit.toString()]
    );

    return { monthlyTotal, occurrences };
  }
}

module.exports = { ChatContextRepository };
