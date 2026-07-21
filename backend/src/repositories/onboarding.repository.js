const { db } = require('../config/database');

class OnboardingRepository {
  static async upsertUserProfile(userId, data) {
    const [rows] = await db.execute('SELECT * FROM user_profiles WHERE user_id = ?', [userId]);
    const exists = rows.length > 0;

    const dbMap = {
      employmentStatus: 'employment_status',
      monthlyIncome: 'monthly_income',
      basicExpenses: 'basic_expenses',
      hasDependents: 'has_dependents',
      financialKnowledge: 'financial_knowledge',
      primaryFinancialGoal: 'primary_financial_goal',
      primarySpendingCategory: 'primary_spending_category',
      relationshipWithMoney: 'relationship_with_money',
      monthlyExtraSavingsGoal: 'monthly_extra_savings_goal',
      mainFinancialGoal12M: 'main_financial_goal_12m',
      incomeSources: 'income_sources',
      fixedExpenses: 'fixed_expenses',
      variableExpenses: 'variable_expenses',
      pinnedMonths: 'pinned_months',
      gender: 'gender',
      maritalStatus: 'marital_status',
      isHeadOfHousehold: 'is_head_of_household',
      isStudent: 'is_student',
      familySize: 'family_size',
    };

    const updates = [];
    const values = [];

    // Map the fields that exist in data
    for (const [key, dbCol] of Object.entries(dbMap)) {
      if (data[key] !== undefined) {
        updates.push(`${dbCol} = ?`);

        // Stringify JSON arrays/objects
        if (['incomeSources', 'fixedExpenses', 'variableExpenses'].includes(key) && data[key]) {
          values.push(JSON.stringify(data[key]));
        } else if (['hasDependents', 'isHeadOfHousehold', 'isStudent'].includes(key)) {
          values.push(data[key] ? 1 : 0);
        } else {
          values.push(data[key]);
        }
      }
    }

    if (updates.length === 0) return; // nothing to update

    if (exists) {
      values.push(userId);
      const updateQuery = `UPDATE user_profiles SET ${updates.join(', ')} WHERE user_id = ?`;
      await db.execute(updateQuery, values);
    } else {
      const columns = updates.map(u => u.split(' = ')[0]);
      const placeholders = columns.map(() => '?');
      const insertQuery = `INSERT INTO user_profiles (user_id, ${columns.join(', ')}) VALUES (?, ${placeholders.join(', ')})`;
      await db.execute(insertQuery, [userId, ...values]);
    }
  }

  static async markOnboarded(userId) {
    const { UserRepository } = require('./user.repository');
    await UserRepository.markOnboarded(userId);
  }

  static async saveGoal(userId, data) {
    const { icon, name, targetAmount, targetDate, flexibility } = data;
    const amount = Math.round(targetAmount || 0);
    const planningMode = flexibility === 'flexible' ? 'contribution_based' : 'deadline_based';

    await db.execute(
      `INSERT INTO goals (user_id, goal_type, name, target_amount, target_date, planning_mode, status) VALUES (?, ?, ?, ?, ?, ?, 'active')`,
      [userId, icon || 'default', name, amount, targetDate ? new Date(targetDate) : null, planningMode]
    );
  }
  static async upsertFinancialProfile(userId, income, detectedTier) {
    const [rows] = await db.execute('SELECT * FROM financial_profiles WHERE user_id = ?', [userId]);
    const exists = rows.length > 0;

    if (exists) {
      await db.execute(
        `UPDATE financial_profiles SET expected_monthly_income = ?, detected_tier = ? WHERE user_id = ?`,
        [income, detectedTier, userId]
      );
    } else {
      await db.execute(
        `INSERT INTO financial_profiles (user_id, expected_monthly_income, detected_tier, currency, timezone, onboarding_status) VALUES (?, ?, ?, 'JOD', 'Asia/Amman', 'completed')`,
        [userId, income, detectedTier]
      );
    }
  }

  static async upsertAllocationPreferences(userId, needsBps, wantsBps, savingsBps, source, basedOnIncome) {
    const [rows] = await db.execute('SELECT * FROM allocation_preferences WHERE user_id = ?', [userId]);
    const exists = rows.length > 0;

    if (exists) {
      await db.execute(
        `UPDATE allocation_preferences SET needs_bps = ?, wants_bps = ?, savings_bps = ?, source = ?, based_on_income = ? WHERE user_id = ?`,
        [needsBps, wantsBps, savingsBps, source, basedOnIncome, userId]
      );
    } else {
      await db.execute(
        `INSERT INTO allocation_preferences (user_id, needs_bps, wants_bps, savings_bps, source, based_on_income) VALUES (?, ?, ?, ?, ?, ?)`,
        [userId, needsBps, wantsBps, savingsBps, source, basedOnIncome]
      );
    }
  }
}

module.exports = { OnboardingRepository };
