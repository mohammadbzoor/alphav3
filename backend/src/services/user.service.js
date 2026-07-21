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
    
    // Check personal information
    let personalComplete = true;
    const personalFields = ['full_name', 'birth_date'];
    const profileFields = ['gender', 'marital_status', 'is_student', 'family_size'];
    
    for (const f of personalFields) {
      if (data.user[f] === null || data.user[f] === undefined || data.user[f] === '') {
        missingFields.push(f);
        personalComplete = false;
      }
    }
    
    for (const f of profileFields) {
      if (data.profile[f] === null || data.profile[f] === undefined || data.profile[f] === '') {
        missingFields.push(f);
        personalComplete = false;
      }
    }

    if (!personalComplete) {
      missingSections.push('personal_information');
      if (!nextRequiredSection) nextRequiredSection = 'personal_information';
    }

    // Check financial information
    let financialComplete = true;
    if (!data.financialProfile.expected_monthly_income || parseFloat(data.financialProfile.expected_monthly_income) <= 0) {
      missingFields.push('expected_monthly_income');
      financialComplete = false;
    }
    if (data.financialProfile.payment_day === null || data.financialProfile.payment_day === undefined) {
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
      }
    }

    if (!allocationComplete) {
      missingSections.push('allocation_preference');
      if (!nextRequiredSection) nextRequiredSection = 'allocation_preference';
    }

    if (!personalComplete) {
      analysisReliability = 'limited';
    } else if (!financialComplete) {
      analysisReliability = 'limited';
    } else if (!allocationComplete) {
      analysisReliability = 'estimated';
    } else {
      analysisReliability = 'reliable';
    }

    const totalFields = personalFields.length + profileFields.length + 3; // 2 financial + 1 allocation
    const missingCount = missingFields.length;
    const percentage = Math.round(((totalFields - missingCount) / totalFields) * 100);

    return {
      isComplete: missingCount === 0,
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

    const profileCompletion = await this.calculateProfileCompletion(userId);

    // Transform level based on tier
    const levelMap = {
      'lower_middle': 'Intermediate',
      'low': 'Beginner',
      'upper_middle': 'Advanced',
      'high': 'Expert'
    };
    
    const tierStr = data.financialProfile?.tier || 'low';

    return {
      user: {
        id: data.user.id,
        fullName: data.user.full_name,
        email: data.user.email,
        avatarUrl: null, // explicitly null per requirements
        memberSince: data.user.created_at
      },
      financialProfile: {
        level: levelMap[tierStr] || 'Intermediate',
        tier: tierStr
      },
      statistics: {
        activeGoals: data.activeGoals || 0,
        confirmedCycleExpenses: data.confirmedCycleExpenses || 0
      },
      profileCompletion
    };
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
