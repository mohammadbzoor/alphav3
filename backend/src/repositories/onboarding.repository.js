const { db } = require('../config/database');

class OnboardingRepository {
  static async lockUserForOnboarding(conn, userId) {
    const [rows] = await conn.execute(
      `SELECT id, is_onboarded FROM users WHERE id = ? FOR UPDATE`,
      [userId]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async findUserProfile(connOrNull, userId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT user_id, employment_status, monthly_income, has_dependents, financial_knowledge,
              primary_financial_goal, gender, marital_status, is_head_of_household,
              is_student, family_size, primary_spending_category, relationship_with_money,
              monthly_extra_savings_goal, main_financial_goal_12m, income_sources,
              fixed_expenses, variable_expenses, pinned_months, basic_expenses
       FROM user_profiles WHERE user_id = ?`,
      [userId]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async findFinancialProfile(connOrNull, userId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT id, user_id, expected_monthly_income, detected_tier, payment_day, currency, timezone, onboarding_status
       FROM financial_profiles WHERE user_id = ?`,
      [userId]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async findAllocationPreferences(connOrNull, userId) {
    const exec = connOrNull || db;
    const [rows] = await exec.execute(
      `SELECT user_id, needs_bps, wants_bps, savings_bps, source, based_on_income
       FROM allocation_preferences WHERE user_id = ?`,
      [userId]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async upsertUserProfile(conn, userId, data) {
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

    const columns = [];
    const values = [];
    const updateClauses = [];

    // Map the fields that exist in data
    for (const [key, dbCol] of Object.entries(dbMap)) {
      if (data[key] !== undefined) {
        columns.push(dbCol);
        values.push(data[key]);
        updateClauses.push(`${dbCol} = VALUES(${dbCol})`);
      }
    }

    if (columns.length === 0) return { created: false, updated: false, affectedRows: 0 };

    const placeholders = columns.map(() => '?').join(', ');
    const insertQuery = `
      INSERT INTO user_profiles (user_id, ${columns.join(', ')})
      VALUES (?, ${placeholders})
      ON DUPLICATE KEY UPDATE ${updateClauses.join(', ')}
    `;

    const [result] = await conn.execute(insertQuery, [userId, ...values]);

    return {
      created: result.insertId !== 0,
      updated: result.affectedRows > 0,
      affectedRows: result.affectedRows
    };
  }

  static async upsertFinancialProfile(conn, userId, data) {
    const dbMap = {
      expectedIncome: 'expected_monthly_income',
      detectedTier: 'detected_tier',
      paymentDay: 'payment_day',
      currency: 'currency',
      timezone: 'timezone',
      onboardingStatus: 'onboarding_status'
    };

    const columns = [];
    const values = [];
    const updateClauses = [];

    for (const [key, dbCol] of Object.entries(dbMap)) {
      if (data[key] !== undefined) {
        columns.push(dbCol);
        values.push(data[key]);
        updateClauses.push(`${dbCol} = VALUES(${dbCol})`);
      }
    }

    if (columns.length === 0) return { affectedRows: 0 };

    const placeholders = columns.map(() => '?').join(', ');
    const insertQuery = `
      INSERT INTO financial_profiles (user_id, ${columns.join(', ')})
      VALUES (?, ${placeholders})
      ON DUPLICATE KEY UPDATE ${updateClauses.join(', ')}
    `;

    const [result] = await conn.execute(insertQuery, [userId, ...values]);
    return { affectedRows: result.affectedRows };
  }

  static async upsertAllocationPreferences(conn, userId, data) {
    const dbMap = {
      needsBps: 'needs_bps',
      wantsBps: 'wants_bps',
      savingsBps: 'savings_bps',
      source: 'source',
      basedOnIncome: 'based_on_income'
    };

    const columns = [];
    const values = [];
    const updateClauses = [];

    for (const [key, dbCol] of Object.entries(dbMap)) {
      if (data[key] !== undefined) {
        columns.push(dbCol);
        values.push(data[key]);
        updateClauses.push(`${dbCol} = VALUES(${dbCol})`);
      }
    }

    if (columns.length === 0) return { affectedRows: 0 };

    const placeholders = columns.map(() => '?').join(', ');
    const insertQuery = `
      INSERT INTO allocation_preferences (user_id, ${columns.join(', ')})
      VALUES (?, ${placeholders})
      ON DUPLICATE KEY UPDATE ${updateClauses.join(', ')}
    `;

    const [result] = await conn.execute(insertQuery, [userId, ...values]);
    return { affectedRows: result.affectedRows };
  }

  static async saveGoal(conn, userId, data) {
    const {
      name,
      goalType,
      customName,
      targetAmount,
      targetDate,
      planningMode,
      plannedContribution,
      priority
    } = data;

    const finalCols = ['user_id', 'goal_type', 'name', 'target_amount', 'planning_mode', 'status'];
    const finalVals = [userId, goalType, name, targetAmount, planningMode, 'active'];

    if (customName !== undefined && customName !== null) {
      finalCols.push('custom_name');
      finalVals.push(customName);
    }

    if (targetDate !== undefined && targetDate !== null) {
      finalCols.push('target_date');
      finalVals.push(targetDate);
    }

    if (plannedContribution !== null && plannedContribution !== undefined) {
      finalCols.push('planned_contribution');
      finalVals.push(plannedContribution);
    }

    if (priority !== undefined) {
      finalCols.push('priority');
      finalVals.push(priority);
    }

    const placeholders = finalCols.map(() => '?').join(', ');
    const query = `INSERT INTO goals (${finalCols.join(', ')}) VALUES (${placeholders})`;

    const [result] = await conn.execute(query, finalVals);
    return result.insertId;
  }
}

module.exports = { OnboardingRepository };
