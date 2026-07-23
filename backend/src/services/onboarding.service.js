const { db } = require('../config/database');
const { AppError } = require('../utils/app-error');
const { OnboardingRepository } = require('../repositories/onboarding.repository');
const { UserRepository } = require('../repositories/user.repository');
const { AllocationService } = require('./allocation.service');
const { CycleRepository } = require('../repositories/cycle.repository');

class OnboardingService {
  /**
   * Centralized logic to resolve the next onboarding step for a user.
   * Returns an object { nextStep, isOnboarded, canCreateCycle }.
   */
  static async resolveNextStep(userId, connOrNull = null) {
    const user = await UserRepository.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404, 'USER_NOT_FOUND');
    }

    const baseResponse = {
      isOnboarded: false,
      nextStep: 'otp_verification',
      canCreateCycle: false,
      financialProfileComplete: false,
      missingFinancialFields: []
    };

    if (!user.is_verified) {
      return baseResponse;
    }

    const profile = await OnboardingRepository.findUserProfile(null, userId);
    if (!profile) {
      return { ...baseResponse, nextStep: 'personal_info' };
    }

    const financial = await OnboardingRepository.findFinancialProfile(null, userId);
    const pref = await OnboardingRepository.findAllocationPreferences(null, userId);

    const missingFields = [];
    if (!financial) {
      missingFields.push('financial_profiles');
    } else {
      if (!financial.expected_monthly_income || Number(financial.expected_monthly_income) <= 0) {
        missingFields.push('expectedMonthlyIncome');
      }
      if (!Number.isSafeInteger(financial.payment_day) || financial.payment_day < 1 || financial.payment_day > 31) {
        missingFields.push('paymentDay');
      }
      if (!financial.currency) {
        missingFields.push('currency');
      }
    }

    if (!pref) {
      missingFields.push('allocation_preferences');
    } else {
      const needs = Number(pref.needs_bps);
      const wants = Number(pref.wants_bps);
      const savings = Number(pref.savings_bps);
      if (!Number.isSafeInteger(needs) || needs < 0 ||
          !Number.isSafeInteger(wants) || wants < 0 ||
          !Number.isSafeInteger(savings) || savings < 0 ||
          (needs + wants + savings) !== 10000) {
        missingFields.push('valid_allocation_bps');
      }
      if (!pref.based_on_income) {
        missingFields.push('based_on_income');
      }
    }

    const financialProfileComplete = missingFields.length === 0;

    const isOnboarded = Number(user.is_onboarded) === 1;
    let nextStep = 'dashboard';

    if (!isOnboarded) {
      const incomeValid = financial && financial.expected_monthly_income && Number(financial.expected_monthly_income) > 0;
      const paymentDayValid = financial && Number.isSafeInteger(financial.payment_day) && financial.payment_day >= 1 && financial.payment_day <= 31;
      const tierPresent = financial && financial.detected_tier !== null && financial.detected_tier !== undefined;

      if (!(incomeValid && paymentDayValid && tierPresent)) {
        nextStep = 'financial_setup';
      } else {
        nextStep = 'allocation_review';
      }
    }

    let canCreateCycle = false;
    let cycleCreationState = 'ready';

    if (!isOnboarded) {
      cycleCreationState = 'onboarding_incomplete';
    } else if (!financialProfileComplete) {
      cycleCreationState = 'financial_profile_incomplete';
    } else {
      const activeCycle = await CycleRepository.findOpenCycle(connOrNull, userId);
      if (activeCycle) {
        cycleCreationState = 'active_cycle_exists';
      } else {
        canCreateCycle = true;
      }
    }

    return {
      nextStep,
      isOnboarded,
      canCreateCycle,
      financialProfileComplete,
      missingFinancialFields: missingFields,
      cycleCreationState
    };
  }

  static async getStatus(userId) {
    const user = await UserRepository.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404, 'USER_NOT_FOUND');
    }
    const profile = await OnboardingRepository.findUserProfile(null, userId);
    const stepInfo = await this.resolveNextStep(userId);

    let allocationData = undefined;
    let income = undefined;
    let tier = undefined;

    if (stepInfo.nextStep === 'allocation_review' || stepInfo.isOnboarded) {
      const pref = await OnboardingRepository.findAllocationPreferences(null, userId);
      const financial = await OnboardingRepository.findFinancialProfile(null, userId);
      if (pref && financial) {
        income = AllocationService.normalizeIncome(financial.expected_monthly_income);
        tier = financial.detected_tier;
        const amounts = AllocationService.calculateAmounts(income, pref.needs_bps, pref.wants_bps, pref.savings_bps);
        allocationData = {
          needsBps: pref.needs_bps,
          wantsBps: pref.wants_bps,
          savingsBps: pref.savings_bps,
          needsAmount: amounts.needsAmount,
          wantsAmount: amounts.wantsAmount,
          savingsAmount: amounts.savingsAmount,
          source: pref.source,
          basedOnIncome: pref.based_on_income,
          isCustomized: pref.source === 'user_adjusted'
        };
      }
    }

    return {
      isOnboarded: stepInfo.isOnboarded,
      nextStep: stepInfo.nextStep,
      canCreateCycle: stepInfo.canCreateCycle,
      financialProfileComplete: stepInfo.financialProfileComplete,
      missingFinancialFields: stepInfo.missingFinancialFields,
      cycleCreationState: stepInfo.cycleCreationState,
      profile,
      ...(allocationData ? { allocation: allocationData, income, tier } : {})
    };
  }

  static normalizeUserProfileData(data) {
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
    if (data.userId !== undefined) {
      throw new AppError('userId is not allowed in payload', 400, 'INVALID_PAYLOAD');
    }
    const normalized = {};
    for (const [key] of Object.entries(dbMap)) {
      if (data[key] !== undefined) {
        if (['hasDependents', 'isHeadOfHousehold', 'isStudent'].includes(key)) {
          if (typeof data[key] !== 'boolean') {
            throw new AppError(`${key} must be a boolean`, 422, 'INVALID_BOOLEAN');
          }
          normalized[key] = data[key] ? 1 : 0;
        } else if (['incomeSources', 'fixedExpenses', 'variableExpenses'].includes(key)) {
          const val = data[key];
          if (val !== null && !Array.isArray(val)) {
            throw new AppError(`${key} must be a valid JSON array`, 422, 'INVALID_JSON_FIELD');
          }
          normalized[key] = val === null ? null : JSON.stringify(val);
        } else if (['familySize', 'pinnedMonths'].includes(key)) {
          const val = Number(data[key]);
          if (!Number.isSafeInteger(val) || val < 0) {
            throw new AppError(`${key} must be a positive integer`, 422, 'INVALID_NUMBER');
          }
          normalized[key] = val;
        } else {
          if (data[key] !== null) {
            if (typeof data[key] !== 'string' && typeof data[key] !== 'number') {
              throw new AppError(`${key} must be a string`, 422, 'INVALID_STRING');
            }
            normalized[key] = String(data[key]).trim();
          } else {
            normalized[key] = null;
          }
        }
      }
    }
    if (data.monthlyIncome !== undefined) {
      normalized.monthlyIncome = AllocationService.normalizeIncome(data.monthlyIncome);
    }
    if (data.basicExpenses !== undefined && data.basicExpenses !== null) {
      const basicExp = Number(data.basicExpenses);
      if (!Number.isFinite(basicExp) || basicExp < 0) {
        throw new AppError('basicExpenses must be a positive number', 422, 'INVALID_NUMBER');
      }
      normalized.basicExpenses = Math.round(basicExp);
    }
    if (data.monthlyExtraSavingsGoal !== undefined && data.monthlyExtraSavingsGoal !== null) {
      const msGoal = Number(data.monthlyExtraSavingsGoal);
      if (!Number.isFinite(msGoal) || msGoal < 0) {
        throw new AppError('monthlyExtraSavingsGoal must be a positive number', 422, 'INVALID_NUMBER');
      }
      normalized.monthlyExtraSavingsGoal = Math.round(msGoal);
    }
    return normalized;
  }

  static normalizePositiveMoney(value, fieldName) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue) || numericValue <= 0) {
      throw new AppError(`${fieldName} must be a positive number`, 422, 'INVALID_AMOUNT');
    }
    const rounded = Math.round(numericValue);
    if (!Number.isSafeInteger(rounded) || rounded <= 0) {
      throw new AppError(`${fieldName} is outside the supported range`, 422, 'INVALID_AMOUNT');
    }
    return rounded;
  }

  static async savePersonalInfo(userId, data) {
    const normalizedData = this.normalizeUserProfileData(data);
    if (Object.keys(normalizedData).length === 0) {
      throw new AppError('No valid fields provided for update', 400, 'EMPTY_UPDATE');
    }
    const conn = await db.getConnection();
    let trx = false;
    try {
      await conn.beginTransaction();
      trx = true;
      const user = await OnboardingRepository.lockUserForOnboarding(conn, userId);
      if (!user) {
        throw new AppError('User not found', 404, 'USER_NOT_FOUND');
      }
      await OnboardingRepository.upsertUserProfile(conn, userId, normalizedData);
      await conn.commit();
      trx = false;
    } catch (e) {
      if (trx) {
        try { await conn.rollback(); } catch (_) {}
      }
      throw e;
    } finally {
      conn.release();
    }
    return { success: true, nextStep: 'financial_setup' };
  }

  static async saveFinancialSetup(userId, data) {
    if (data.monthlyIncome === undefined) {
      throw new AppError('monthlyIncome is required', 422, 'MONTHLY_INCOME_REQUIRED');
    }
    if (data.salaryPaymentDay !== undefined && data.paymentDay !== undefined) {
      if (Number(data.salaryPaymentDay) !== Number(data.paymentDay)) {
        throw new AppError('Conflicting payment day fields', 400, 'CONFLICTING_PAYMENT_DAY_FIELDS');
      }
    }
    const rawPaymentDay = data.salaryPaymentDay ?? data.paymentDay;
    if (rawPaymentDay === undefined) {
      throw new AppError('Payment day is required', 422, 'INVALID_PAYMENT_DAY');
    }
    const paymentDay = Number(rawPaymentDay);
    if (!Number.isSafeInteger(paymentDay) || paymentDay < 1 || paymentDay > 31) {
      throw new AppError('Payment day must be between 1 and 31', 422, 'INVALID_PAYMENT_DAY');
    }
    const income = AllocationService.normalizeIncome(data.monthlyIncome);
    const { tier, needs_bps, wants_bps, savings_bps } = AllocationService.calculateTierAndBps(income);
    if (needs_bps + wants_bps + savings_bps !== 10000) {
      throw new AppError('BPS sum is not 10000', 500, 'ALLOCATION_INVARIANT_VIOLATION');
    }
    const normalizedProfileData = this.normalizeUserProfileData(data);
    normalizedProfileData.monthlyIncome = income;
    const conn = await db.getConnection();
    let trx = false;
    try {
      await conn.beginTransaction();
      trx = true;
      const user = await OnboardingRepository.lockUserForOnboarding(conn, userId);
      if (!user) {
        throw new AppError('User not found', 404, 'USER_NOT_FOUND');
      }
      await OnboardingRepository.upsertUserProfile(conn, userId, normalizedProfileData);
      await OnboardingRepository.upsertFinancialProfile(conn, userId, {
        expectedIncome: income,
        detectedTier: tier,
        paymentDay,
        currency: 'JOD',
        timezone: 'Asia/Amman'
      });
      await OnboardingRepository.upsertAllocationPreferences(conn, userId, {
        needsBps: needs_bps,
        wantsBps: wants_bps,
        savingsBps: savings_bps,
        source: 'system_tier',
        basedOnIncome: income
      });
      await conn.commit();
      trx = false;
    } catch (e) {
      if (trx) {
        try { await conn.rollback(); } catch (_) {}
      }
      throw e;
    } finally {
      conn.release();
    }
    const amounts = AllocationService.calculateAmounts(income, needs_bps, wants_bps, savings_bps);
    return {
      success: true,
      isOnboarded: false,
      nextStep: 'allocation_review',
      canCreateCycle: false,
      income,
      tier,
      paymentDay,
      allocation: {
        needsBps: needs_bps,
        wantsBps: wants_bps,
        savingsBps: savings_bps,
        needsAmount: amounts.needsAmount,
        wantsAmount: amounts.wantsAmount,
        savingsAmount: amounts.savingsAmount,
        source: 'system_tier',
        isCustomized: false
      }
    };
  }

  static async approveAllocation(userId, payload) {
    const { needsBps, wantsBps, savingsBps } = payload;
    const bpsVals = [needsBps, wantsBps, savingsBps];
    if (bpsVals.some(v => v === undefined || v === null || !Number.isInteger(v) || v < 0)) {
      throw new AppError('BPS values must be non‑negative integers', 422, 'INVALID_BPS');
    }
    if (needsBps + wantsBps + savingsBps !== 10000) {
      throw new AppError('BPS values must sum to 10000', 422, 'INVALID_BPS_SUM');
    }
    let income, tier, source;
    const conn = await db.getConnection();
    let trx = false;
    try {
      await conn.beginTransaction();
      trx = true;
      const user = await OnboardingRepository.lockUserForOnboarding(conn, userId);
      if (!user) {
        throw new AppError('User not found', 404, 'USER_NOT_FOUND');
      }
      const financial = await OnboardingRepository.findFinancialProfile(conn, userId);
      if (!financial) {
        throw new AppError('Financial profile not found', 404, 'FINANCIAL_NOT_FOUND');
      }
      income = AllocationService.normalizeIncome(financial.expected_monthly_income);
      tier = financial.detected_tier;
      const { needs_bps: sysNeeds, wants_bps: sysWants, savings_bps: sysSavings } = AllocationService.calculateTierAndBps(income);
      source = (needsBps === sysNeeds && wantsBps === sysWants && savingsBps === sysSavings) ? 'system_tier' : 'user_adjusted';
      await OnboardingRepository.upsertAllocationPreferences(conn, userId, {
        needsBps,
        wantsBps,
        savingsBps,
        source,
        basedOnIncome: income
      });
      await UserRepository.markOnboarded(conn, userId);
      try {
        await OnboardingRepository.upsertFinancialProfile(conn, userId, { onboardingStatus: 'completed' });
      } catch (_) {}
      await conn.commit();
      trx = false;
    } catch (e) {
      if (trx) {
        try { await conn.rollback(); } catch (_) {}
      }
      throw e;
    } finally {
      conn.release();
    }
    const amounts = AllocationService.calculateAmounts(income, needsBps, wantsBps, savingsBps);
    return {
      success: true,
      isOnboarded: true,
      nextStep: 'dashboard',
      canCreateCycle: true,
      income,
      tier,
      allocation: {
        needsBps,
        wantsBps,
        savingsBps,
        needsAmount: amounts.needsAmount,
        wantsAmount: amounts.wantsAmount,
        savingsAmount: amounts.savingsAmount,
        source,
        isCustomized: source === 'user_adjusted'
      }
    };
  }

  static async saveFirstGoal(userId, data) {
    const APPROVED_GOAL_TYPES = [
      'emergency_fund',
      'laptop',
      'travel',
      'religious_travel',
      'holiday_expenses',
      'tuition',
      'car_down_payment',
      'home_down_payment',
      'business_startup',
      'electrical_appliances',
      'furniture',
      'clothing_accessories',
      'custom'
    ];
    if (!data.goalType) {
      throw new AppError('goalType is required', 422, 'GOAL_TYPE_REQUIRED');
    }
    const goalTypeStr = typeof data.goalType === 'string' ? data.goalType.trim() : '';
    if (!goalTypeStr || !APPROVED_GOAL_TYPES.includes(goalTypeStr)) {
      throw new AppError('INVALID_GOAL_TYPE', 422, 'INVALID_GOAL_TYPE');
    }
    if (!data.name || typeof data.name !== 'string' || data.name.trim() === '') {
      throw new AppError('name is required and must be a string', 422, 'INVALID_STRING');
    }
    let customName = undefined;
    if (goalTypeStr === 'custom') {
      if (!data.customName || typeof data.customName !== 'string' || data.customName.trim() === '') {
        throw new AppError('customName must be a non-empty string for custom goalType', 422, 'INVALID_STRING');
      }
      customName = data.customName.trim();
    }
    const targetAmount = this.normalizePositiveMoney(data.targetAmount, 'targetAmount');
    const planningMode = data.flexibility === 'flexible' ? 'contribution_based' : 'deadline_based';
    let plannedContribution = undefined;
    let targetDate = undefined;
    if (planningMode === 'contribution_based') {
      if (data.plannedContribution === undefined || data.plannedContribution === null || data.plannedContribution === '') {
        throw new AppError('plannedContribution is required for contribution_based goals', 422, 'INVALID_AMOUNT');
      }
      plannedContribution = this.normalizePositiveMoney(data.plannedContribution, 'plannedContribution');
    } else {
      if (!data.targetDate || typeof data.targetDate !== 'string') {
        throw new AppError('targetDate is required for deadline_based goals', 422, 'INVALID_DATE');
      }
      const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
      if (!dateRegex.test(data.targetDate)) {
        throw new AppError('targetDate must be in YYYY-MM-DD format', 422, 'INVALID_DATE');
      }
      const dateParts = data.targetDate.split('-');
      const year = parseInt(dateParts[0], 10);
      const month = parseInt(dateParts[1], 10) - 1;
      const day = parseInt(dateParts[2], 10);
      const testDate = new Date(Date.UTC(year, month, day));
      if (testDate.getUTCFullYear() !== year || testDate.getUTCMonth() !== month || testDate.getUTCDate() !== day) {
        throw new AppError('targetDate must be a valid date', 422, 'INVALID_DATE');
      }
      const today = new Date();
      const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
      if (data.targetDate < todayStr) {
        throw new AppError('targetDate cannot be in the past', 422, 'INVALID_DATE');
      }
      targetDate = data.targetDate;
    }
    let priority = undefined;
    if (data.priority !== undefined && data.priority !== null) {
      const prio = Number(data.priority);
      if (!Number.isSafeInteger(prio) || prio < 1 || prio > 10) {
        throw new AppError('priority must be between 1 and 10', 422, 'INVALID_PRIORITY');
      }
      priority = prio;
    }
    const normalizedGoal = {
      name: data.name.trim(),
      goalType: goalTypeStr,
      customName,
      targetAmount,
      targetDate,
      planningMode,
      plannedContribution,
      priority
    };
    let goalId;
    const conn = await db.getConnection();
    let trx = false;
    try {
      await conn.beginTransaction();
      trx = true;
      const user = await OnboardingRepository.lockUserForOnboarding(conn, userId);
      if (!user) {
        throw new AppError('User not found', 404, 'USER_NOT_FOUND');
      }
      goalId = await OnboardingRepository.saveGoal(conn, userId, normalizedGoal);
      await conn.commit();
      trx = false;
    } catch (e) {
      if (trx) {
        try { await conn.rollback(); } catch (_) {}
      }
      throw e;
    } finally {
      conn.release();
    }
    return { success: true, goalId };
  }
}

module.exports = { OnboardingService };
