const { db } = require('../config/database');

class UserRepository {
  static async findByEmailOrPhone(email, phone) {
    const [rows] = await db.execute(
      `SELECT id, email, phone FROM users WHERE LOWER(email) = LOWER(?) OR phone = ? LIMIT 1`,
      [email, phone]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async createUser(data) {
    const { fullName, email, phone, birthDate, passwordHash } = data;
    const [result] = await db.execute(
      `INSERT INTO users (full_name, phone, email, birth_date, password_hash, is_verified, is_onboarded) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [fullName, phone, email, birthDate, passwordHash, false, false]
    );
    return result.insertId;
  }

  static async markOnboarded(userId) {
    await db.execute(
      `UPDATE users SET is_onboarded = 1 WHERE id = ?`,
      [userId]
    );
  }

  static async findById(id) {
    const [rows] = await db.execute(
      `SELECT id, full_name, phone, email, birth_date, is_verified, is_onboarded, created_at, updated_at FROM users WHERE id = ? LIMIT 1`,
      [id]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async findByPhone(phone) {
    const [rows] = await db.execute(
      `SELECT id, full_name, phone, email, password_hash, is_verified, is_onboarded FROM users WHERE phone = ? LIMIT 1`,
      [phone]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async saveOtp(userId, otpCode, expiresAt) {
    await db.execute(
      `UPDATE users SET otp_code = ?, otp_expires_at = ? WHERE id = ?`,
      [otpCode, expiresAt, userId]
    );
  }

  static async verifyOtp(phone, otpCode) {
    const [rows] = await db.execute(
      `SELECT id, otp_code, otp_expires_at FROM users WHERE phone = ? LIMIT 1`,
      [phone]
    );

    if (rows.length === 0) return { valid: false, message: 'User not found' };

    const user = rows[0];

    if (!user.otp_code) {
      return { valid: false, message: 'No OTP found' };
    }

    if (user.otp_code !== otpCode) {
      return { valid: false, message: 'Invalid OTP code' };
    }

    if (new Date() > new Date(user.otp_expires_at)) {
      await db.execute(`UPDATE users SET otp_code = NULL, otp_expires_at = NULL WHERE id = ?`, [user.id]);
      return { valid: false, message: 'OTP code has expired' };
    }

    // Clear OTP and set verified
    await db.execute(
      `UPDATE users SET is_verified = 1, otp_code = NULL, otp_expires_at = NULL WHERE id = ?`,
      [user.id]
    );

    return { valid: true, userId: user.id };
  }
  static async findByEmail(email) {
    const [rows] = await db.execute(
      `SELECT id, full_name, phone, email FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1`,
      [email]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async checkOtpByEmail(email, otpCode) {
    const [rows] = await db.execute(
      `SELECT id, otp_code, otp_expires_at FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1`,
      [email]
    );

    if (rows.length === 0) return { valid: false, message: 'User not found' };

    const user = rows[0];

    if (!user.otp_code) {
      return { valid: false, message: 'No OTP found' };
    }

    if (user.otp_code !== otpCode) {
      return { valid: false, message: 'Invalid OTP code' };
    }

    if (new Date() > new Date(user.otp_expires_at)) {
      await db.execute(`UPDATE users SET otp_code = NULL, otp_expires_at = NULL WHERE id = ?`, [user.id]);
      return { valid: false, message: 'OTP code has expired' };
    }

    return { valid: true, userId: user.id };
  }

  static async updatePassword(userId, newPasswordHash) {
    await db.execute(
      `UPDATE users SET password_hash = ?, otp_code = NULL, otp_expires_at = NULL WHERE id = ?`,
      [newPasswordHash, userId]
    );
  }

  static async getProfile(userId) {
    const [userRows] = await db.execute(
      `SELECT id, full_name, phone, email, birth_date, is_verified, is_onboarded FROM users WHERE id = ? LIMIT 1`,
      [userId]
    );
    if (userRows.length === 0) return null;

    const [profileRows] = await db.execute(
      `SELECT * FROM user_profiles WHERE user_id = ? LIMIT 1`,
      [userId]
    );

    const [finRows] = await db.execute(
      `SELECT expected_monthly_income FROM financial_profiles WHERE user_id = ? LIMIT 1`,
      [userId]
    );

    return {
      user: userRows[0],
      profile: profileRows.length > 0 ? profileRows[0] : null,
      financialProfile: finRows.length > 0 ? finRows[0] : null
    };
  }

  static async getProfileCompletionData(userId) {
    const [userRows] = await db.execute(
      `SELECT full_name, birth_date FROM users WHERE id = ? LIMIT 1`,
      [userId]
    );

    const [profileRows] = await db.execute(
      `SELECT gender, marital_status, is_student, family_size FROM user_profiles WHERE user_id = ? LIMIT 1`,
      [userId]
    );

    const [finRows] = await db.execute(
      `SELECT expected_monthly_income, payment_day FROM financial_profiles WHERE user_id = ? LIMIT 1`,
      [userId]
    );

    const [allocRows] = await db.execute(
      `SELECT needs_bps, wants_bps, savings_bps FROM allocation_preferences WHERE user_id = ? LIMIT 1`,
      [userId]
    );

    return {
      user: userRows[0] || {},
      profile: profileRows.length > 0 ? profileRows[0] : {},
      financialProfile: finRows.length > 0 ? finRows[0] : {},
      allocationPreferences: allocRows.length > 0 ? allocRows[0] : null
    };
  }

  static async getProfileSummary(userId) {
    const [userRows] = await db.execute(
      `SELECT id, full_name, email, created_at FROM users WHERE id = ? LIMIT 1`,
      [userId]
    );
    if (userRows.length === 0) return null;

    const [finRows] = await db.execute(
      `SELECT tier FROM financial_profiles WHERE user_id = ? LIMIT 1`,
      [userId]
    );

    const [goalRows] = await db.execute(
      `SELECT count(*) as count FROM goals WHERE user_id = ? AND status NOT IN ('deleted', 'cancelled')`,
      [userId]
    );

    const [expenseRows] = await db.execute(
      `SELECT count(*) as count FROM transactions t 
       JOIN financial_cycles c ON t.cycle_id = c.id 
       WHERE t.user_id = ? AND t.transaction_type = 'expense' AND t.status = 'confirmed' AND c.status = 'open'`,
      [userId]
    );

    return {
      user: userRows[0],
      financialProfile: finRows.length > 0 ? finRows[0] : null,
      activeGoals: goalRows[0].count,
      confirmedCycleExpenses: expenseRows[0].count
    };
  }

  static async updateProfile(userId, updateData) {
    const updates = [];
    const values = [];

    // Map flutter field names to DB columns
    const fieldMapping = {
      gender: 'gender',
      maritalStatus: 'marital_status',
      isHeadOfHousehold: 'is_head_of_household',
      isStudent: 'is_student',
      familySize: 'family_size'
    };

    for (const [key, value] of Object.entries(updateData)) {
      if (fieldMapping[key] !== undefined) {
        updates.push(`${fieldMapping[key]} = ?`);
        // Handle booleans mapped to tinyint
        if (typeof value === 'boolean') {
          values.push(value ? 1 : 0);
        } else {
          values.push(value);
        }
      }
    }

    if (updates.length > 0) {
      values.push(userId);
      await db.execute(
        `UPDATE user_profiles SET ${updates.join(', ')} WHERE user_id = ?`,
        values
      );
    }

    // Also update users table if fullName or birthDate is passed
    const userUpdates = [];
    const userValues = [];

    if (updateData.fullName) {
      userUpdates.push('full_name = ?');
      userValues.push(updateData.fullName);
    }
    if (updateData.birthDate) {
      userUpdates.push('birth_date = ?');
      userValues.push(updateData.birthDate);
    }

    if (userUpdates.length > 0) {
      userValues.push(userId);
      await db.execute(
        `UPDATE users SET ${userUpdates.join(', ')} WHERE id = ?`,
        userValues
      );
    }
  }
}

module.exports = { UserRepository };
