const { db } = require('../config/database');

class ChallengeRepository {
  static async getAvailableChallenges(userId) {
    const [rows] = await db.execute(`
      SELECT 
        t.id as templateId,
        t.title,
        t.description,
        t.challenge_type as type,
        t.metric_type as metricType,
        t.target_value as targetValue,
        t.duration_days as totalDays,
        t.xp_reward as xpReward,
        t.icon
      FROM challenge_templates t
      WHERE t.is_active = TRUE
      AND NOT EXISTS (
        SELECT 1 FROM user_challenges uc 
        WHERE uc.template_id = t.id 
          AND uc.user_id = ? 
          AND uc.status = 'current'
      )
    `, [userId]);
    return rows;
  }

  static async getCurrentChallenges(userId) {
    const [rows] = await db.execute(`
      SELECT 
        uc.id as id,
        t.id as templateId,
        t.title,
        t.description,
        t.challenge_type as type,
        uc.status,
        p.progress_percentage as progress,
        p.current_value as currentValue,
        p.target_value as targetValue,
        t.duration_days as totalDays,
        t.xp_reward as xpReward,
        t.icon,
        TRUE as isAccepted,
        uc.start_date as startDate,
        uc.end_date as endDate
      FROM user_challenges uc
      JOIN challenge_templates t ON uc.template_id = t.id
      LEFT JOIN challenge_progress p ON uc.id = p.user_challenge_id
      WHERE uc.user_id = ? AND uc.status = 'current'
    `, [userId]);
    return rows;
  }

  static async getCompletedChallenges(userId) {
    const [rows] = await db.execute(`
      SELECT 
        uc.id as id,
        t.id as templateId,
        t.title,
        t.description,
        t.challenge_type as type,
        uc.status,
        p.progress_percentage as progress,
        p.current_value as currentValue,
        p.target_value as targetValue,
        t.duration_days as totalDays,
        t.xp_reward as xpReward,
        t.icon,
        TRUE as isAccepted,
        uc.start_date as startDate,
        uc.end_date as endDate
      FROM user_challenges uc
      JOIN challenge_templates t ON uc.template_id = t.id
      LEFT JOIN challenge_progress p ON uc.id = p.user_challenge_id
      WHERE uc.user_id = ? AND uc.status = 'completed'
    `, [userId]);
    return rows;
  }

  static async getChallengeTemplate(templateId) {
    const [rows] = await db.execute(`
      SELECT id, target_value as targetValue, duration_days as durationDays, is_active as isActive
      FROM challenge_templates
      WHERE id = ? LIMIT 1
    `, [templateId]);
    return rows[0];
  }

  static async getActiveCycle(userId) {
    const [rows] = await db.execute(`
      SELECT id FROM financial_cycles WHERE user_id = ? AND status = 'open' LIMIT 1
    `, [userId]);
    return rows[0];
  }

  static async acceptChallenge(userId, templateId, cycleId, durationDays, targetValue) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      const startDate = new Date();
      const endDate = new Date(startDate.getTime() + (durationDays * 24 * 60 * 60 * 1000));

      const [insertUserChallenge] = await conn.execute(`
        INSERT INTO user_challenges (user_id, template_id, cycle_id, status, start_date, end_date, accepted_at)
        VALUES (?, ?, ?, 'current', ?, ?, ?)
      `, [userId, templateId, cycleId, startDate, endDate, startDate]);

      const userChallengeId = insertUserChallenge.insertId;

      await conn.execute(`
        INSERT INTO challenge_progress (user_challenge_id, current_value, target_value, progress_percentage)
        VALUES (?, 0.00, ?, 0.00)
      `, [userChallengeId, targetValue]);

      await conn.commit();
      return userChallengeId;
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }

  static async cancelChallenge(userId, userChallengeId) {
    const [result] = await db.execute(`
      UPDATE user_challenges 
      SET status = 'cancelled', updated_at = NOW()
      WHERE id = ? AND user_id = ? AND status = 'current'
    `, [userChallengeId, userId]);
    return result.affectedRows > 0;
  }
  static async getActiveChallengesForUser(userId) {
    const [rows] = await db.execute(`
      SELECT 
        uc.id as userChallengeId,
        uc.user_id as userId,
        uc.cycle_id as cycleId,
        uc.start_date as startDate,
        uc.end_date as endDate,
        t.metric_type as metricType,
        t.conditions,
        p.current_value as currentValue,
        p.target_value as targetValue
      FROM user_challenges uc
      JOIN challenge_templates t ON uc.template_id = t.id
      JOIN challenge_progress p ON uc.id = p.user_challenge_id
      WHERE uc.user_id = ? AND uc.status = 'current'
    `, [userId]);
    return rows;
  }

  static async getActiveChallengesByMetricTypes(userId, metricTypes) {
    if (!metricTypes || metricTypes.length === 0) return [];
    const placeholders = metricTypes.map(() => '?').join(',');
    const [rows] = await db.execute(`
      SELECT 
        uc.id as userChallengeId,
        uc.user_id as userId,
        uc.cycle_id as cycleId,
        uc.start_date as startDate,
        uc.end_date as endDate,
        t.metric_type as metricType,
        t.conditions,
        p.current_value as currentValue,
        p.target_value as targetValue
      FROM user_challenges uc
      JOIN challenge_templates t ON uc.template_id = t.id
      JOIN challenge_progress p ON uc.id = p.user_challenge_id
      WHERE uc.user_id = ? AND uc.status = 'current' AND t.metric_type IN (${placeholders})
    `, [userId, ...metricTypes]);
    return rows;
  }

  static async getChallengeWithTemplate(userChallengeId) {
    const [rows] = await db.execute(`
      SELECT 
        uc.id as userChallengeId,
        uc.user_id as userId,
        uc.cycle_id as cycleId,
        uc.status,
        uc.start_date as startDate,
        uc.end_date as endDate,
        t.title,
        t.metric_type as metricType,
        t.conditions,
        p.current_value as currentValue,
        p.target_value as targetValue,
        p.progress_percentage as progressPercentage
      FROM user_challenges uc
      JOIN challenge_templates t ON uc.template_id = t.id
      JOIN challenge_progress p ON uc.id = p.user_challenge_id
      WHERE uc.id = ?
    `, [userChallengeId]);
    return rows[0];
  }

  static async getCurrentChallengeForUpdate(connection, userId, templateId) {
    const [rows] = await connection.execute(`
      SELECT id FROM user_challenges 
      WHERE user_id = ? AND template_id = ? AND status = 'current'
      FOR UPDATE
    `, [userId, templateId]);
    return rows[0];
  }

  static async updateProgress(userChallengeId, currentValue, targetValue, progressPercentage) {
    const [result] = await db.execute(`
      UPDATE challenge_progress 
      SET current_value = ?, target_value = ?, progress_percentage = ?, last_updated_at = NOW()
      WHERE user_challenge_id = ?
    `, [currentValue, targetValue, progressPercentage, userChallengeId]);
    return result.affectedRows > 0;
  }

  static async completeChallenge(userChallengeId) {
    const [result] = await db.execute(`
      UPDATE user_challenges 
      SET status = 'completed', completed_at = NOW(), updated_at = NOW()
      WHERE id = ? AND status = 'current'
    `, [userChallengeId]);
    return result.affectedRows > 0;
  }

  static async failChallenge(userChallengeId) {
    const [result] = await db.execute(`
      UPDATE user_challenges 
      SET status = 'failed', failed_at = NOW(), updated_at = NOW()
      WHERE id = ? AND status = 'current'
    `, [userChallengeId]);
    return result.affectedRows > 0;
  }

  static async getProgressForUpdate(connection, userChallengeId) {
    const [rows] = await connection.execute(`
      SELECT id, current_value as currentValue, target_value as targetValue, progress_percentage as progressPercentage
      FROM challenge_progress 
      WHERE user_challenge_id = ?
      FOR UPDATE
    `, [userChallengeId]);
    return rows[0];
  }

  static async getCycleWantsTarget(userId, cycleId) {
    const [rows] = await db.execute(`
      SELECT wants_target as wantsTarget
      FROM cycle_allocation_snapshots
      WHERE cycle_id = ? LIMIT 1
    `, [cycleId]);
    
    if (!rows || rows.length === 0) return null;
    return rows[0].wantsTarget;
  }

  static async checkDuplicateChallengeMilestone(userId, userChallengeId, milestone) {
    const [rows] = await db.execute(`
      SELECT id FROM notifications 
      WHERE user_id = ? 
        AND category = 'system' 
        AND JSON_EXTRACT(action_data, '$.userChallengeId') = ? 
        AND JSON_EXTRACT(action_data, '$.milestone') = ?
      LIMIT 1
    `, [userId, userChallengeId, milestone]);
    return rows.length > 0;
  }
}

module.exports = { ChallengeRepository };
