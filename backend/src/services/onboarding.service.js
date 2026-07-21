const { OnboardingRepository } = require('../repositories/onboarding.repository');

class OnboardingService {
  static async getStatus(userId) {
    const { UserRepository } = require('../repositories/user.repository');
    const { db } = require('../config/database');
    const user = await UserRepository.findById(userId);
    
    const [profiles] = await db.execute('SELECT * FROM user_profiles WHERE user_id = ?', [userId]);
    const profile = profiles.length > 0 ? profiles[0] : null;
    
    return { 
      isOnboarded: Boolean(user?.is_onboarded),
      profile: profile
    };
  }

  static async savePersonalInfo(userId, data) {
    await OnboardingRepository.upsertUserProfile(userId, data);
    return { success: true };
  }

  static async saveFinancialSetup(userId, data) {
    const { AllocationService } = require('./allocation.service');

    // Original behavior
    await OnboardingRepository.upsertUserProfile(userId, data);

    // New Allocation Engine Logic
    if (data.monthlyIncome !== undefined) {
      const income = Math.round(Number(data.monthlyIncome) || 0);
      const { tier, needs_bps, wants_bps, savings_bps } = AllocationService.calculateTierAndBps(income);

      // Store expected_income and detected_tier in financial_profiles
      await OnboardingRepository.upsertFinancialProfile(userId, income, tier);

      // Store bps preferences in allocation_preferences
      await OnboardingRepository.upsertAllocationPreferences(
        userId,
        needs_bps,
        wants_bps,
        savings_bps,
        'system_tier',
        income
      );
    }

    await OnboardingRepository.markOnboarded(userId);
    return { success: true };
  }
  static async saveFirstGoal(userId, data) {
    await OnboardingRepository.saveGoal(userId, data);
    return { success: true, goal: data };
  }
}

module.exports = { OnboardingService };
