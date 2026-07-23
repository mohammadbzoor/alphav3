const { UserRepository } = require('../repositories/user.repository');
const { OnboardingRepository } = require('../repositories/onboarding.repository');
const { AllocationService } = require('./allocation.service');

class UserService {
  static async getProfile(userId) {
    const data = await UserRepository.getProfile(userId);
    if (!data) {
      const error = new Error('User not found');
      error.statusCode = 404;
      throw error;
    }

    const income = parseFloat(data.financialProfile?.expected_monthly_income || 0);

    // Combine fields into the shape Flutter expects
    const response = {
      id: data.user.id,
      fullName: data.user.full_name,
      email: data.user.email,
      phoneNumber: data.user.phone, // Flutter expects phoneNumber
      birthDate: data.user.birth_date,
      isOnboarded: Boolean(data.user.is_onboarded),
      // from profile
      gender: data.profile?.gender || null,
      maritalStatus: data.profile?.marital_status || null,
      isHeadOfHousehold: Boolean(data.profile?.is_head_of_household),
      isStudent: Boolean(data.profile?.is_student),
      monthlyIncome: income,
      familySize: data.profile?.family_size || 1,
      // Provide nested profiles for Flutter backwards compatibility
      profiles: [{
        monthlyIncome: income,
        primarySpendingCategory: data.profile?.primary_spending_category || 'غير محدد'
      }]
    };
    return response;
  }

  static async calculateProfileCompletion(userId) {
    const data = await UserRepository.getProfileCompletionData(userId);
    
    const missingFields = [];
    const missingSections = [];
    let nextRequiredSection = null;
    let analysisReliability = 'limited';
    
    // Check personal information (actual columns in users table)
    let personalComplete = true;
    const personalFields = ['full_name', 'birth_date'];
    
    for (const f of personalFields) {
      if (data.user[f] === null || data.user[f] === undefined || data.user[f] === '') {
        missingFields.push(f);
        personalComplete = false;
      }
    }

    // Check employment/financial basic info (actual columns in user_profiles)
    if (!personalComplete) {
      missingSections.push('personal_information');
      if (!nextRequiredSection) nextRequiredSection = 'personal_information';
    }

    // Check financial information (actual columns)
    let financialComplete = true;
    const income = parseFloat(data.financialProfile?.expected_monthly_income);
    if (isNaN(income) || income <= 0) {
      missingFields.push('expected_monthly_income');
      financialComplete = false;
    }

    const pDay = parseInt(data.financialProfile?.payment_day, 10);
    if (isNaN(pDay) || pDay < 1 || pDay > 31) {
      missingFields.push('payment_day');
      financialComplete = false;
    }

    if (!financialComplete) {
      missingSections.push('financial_information');
      if (!nextRequiredSection) nextRequiredSection = 'financial_information';
    }

    // Check allocation preference
    let allocationComplete = true;
    if (!data.allocationPreferences) {
      missingFields.push('allocation_preference');
      allocationComplete = false;
    } else {
      const { needs_bps, wants_bps, savings_bps } = data.allocationPreferences;
      if (needs_bps === undefined || wants_bps === undefined || savings_bps === undefined) {
        missingFields.push('allocation_preference');
        allocationComplete = false;
      } else {
        const totalBps = Number(needs_bps) + Number(wants_bps) + Number(savings_bps);
        if (totalBps !== 10000) {
          missingFields.push('allocation_preference');
          allocationComplete = false;
        }
      }
    }

    if (!allocationComplete) {
      missingSections.push('allocation_preference');
      if (!nextRequiredSection) nextRequiredSection = 'allocation_preference';
    }

    // Calculate reliability
    if (!personalComplete || !financialComplete) {
      analysisReliability = 'limited';
    } else if (!allocationComplete) {
      analysisReliability = 'estimated';
    } else {
      analysisReliability = 'reliable';
    }

    // Total critical fields: 2 (personal) + 2 (financial) + 1 (allocation) = 5
    const totalCriticalFields = 5;
    const completedCriticalFields = totalCriticalFields - missingFields.length;
    const percentage = Math.round((completedCriticalFields / totalCriticalFields) * 100);

    return {
      isComplete: missingFields.length === 0,
      percentage,
      missingFields,
      missingSections,
      nextRequiredSection,
      analysisReliability
    };
  }

  static async getProfileSummary(userId) {
    const data = await UserRepository.getProfileSummary(userId);
    if (!data) {
      const error = new Error('User not found');
      error.statusCode = 404;
      throw error;
    }

    // Check account verification status
    if (!data.user.is_verified) {
      const error = new Error('Account not verified');
      error.statusCode = 403;
      error.code = 'ACCOUNT_NOT_VERIFIED';
      throw error;
    }

    const profileCompletion = await this.calculateProfileCompletion(userId);

    // Resolve tier based on priority logic
    let tier = null;
    let level = null;

    if (data.tierData.tier) {
      // Use cycle snapshot or calculated tier
      tier = data.tierData.tier;
    } else if (data.tierData.tierCode) {
      // Use tier code from allocation preferences (needs to map back to tier name)
      // For now, we'll calculate from the bps values
      tier = this._calculateTierFromBps(data.tierData.tierCode);
    } else if (data.tierData.income) {
      // Calculate from income
      const calculatedTier = AllocationService.calculateTierAndBps(data.tierData.income);
      tier = calculatedTier.tier;
    }

    // Map tier to level for frontend
    const levelMap = {
      'Very Low': 'Beginner',
      'Low': 'Beginner',
      'Lower Middle': 'Intermediate',
      'Middle': 'Intermediate',
      'Upper Middle': 'Advanced',
      'High': 'Advanced',
      'Very High': 'Expert'
    };

    if (tier) {
      level = levelMap[tier] || 'Intermediate';
    }

    // Build warnings array
    const warnings = [];
    if (!data.hasActiveCycle) {
      warnings.push('NO_ACTIVE_FINANCIAL_CYCLE');
    }
    if (!data.financialProfile) {
      warnings.push('NO_FINANCIAL_PROFILE');
    }

    return {
      user: {
        id: data.user.id,
        fullName: data.user.full_name,
        email: data.user.email,
        birthDate: data.user.birth_date,
        avatarUrl: null,
        memberSince: data.user.created_at
      },
      financialProfile: {
        level,
        tier
      },
      statistics: {
        activeGoals: data.activeGoals || 0,
        confirmedCycleExpenses: data.confirmedCycleExpenses || 0
      },
      profileCompletion,
      warnings
    };
  }

  static _calculateTierFromBps(bpsData) {
    // Map basis point allocations back to tier names
    const { needs_bps, wants_bps } = bpsData;
    
    if (!needs_bps || !wants_bps) return null;

    // Based on AllocationService.calculateTierAndBps mapping
    if (needs_bps >= 8000) return 'Very Low';
    if (needs_bps >= 7000) return 'Low';
    if (needs_bps >= 6000) return 'Lower Middle';
    if (needs_bps >= 5000) return 'Middle';
    if (needs_bps >= 4000) return 'Upper Middle';
    if (needs_bps >= 3000) return 'High';
    return 'Very High';
  }

  static async updateProfile(userId, updateData) {
    // Basic user info and non-financial profile fields
    await UserRepository.updateProfile(userId, updateData);

    // If monthlyIncome is provided, update financial core & recalculate tier
    if (updateData.monthlyIncome !== undefined) {
      const income = Math.round(parseFloat(updateData.monthlyIncome || 0));
      const tier = AllocationService.calculateTierAndBps(income);

      // Update financial_profiles
      await OnboardingRepository.upsertFinancialProfile(userId, income, tier.tier);

      // Update allocation_preferences based on new tier
      await OnboardingRepository.upsertAllocationPreferences(
        userId,
        tier.needs_bps,
        tier.wants_bps,
        tier.savings_bps,
        'system_tier',
        income
      );
    }

    return await this.getProfile(userId);
  }
}

module.exports = { UserService };
