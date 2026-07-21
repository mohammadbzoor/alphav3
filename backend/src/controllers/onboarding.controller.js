const { OnboardingService } = require('../services/onboarding.service');

class OnboardingController {
  static async getStatus(req, res) {
    const userId = req.user.id;
    const result = await OnboardingService.getStatus(userId);

    res.status(200).json({
      success: true,
      message: 'Onboarding status retrieved',
      data: result,
      meta: null
    });
  }

  static async savePersonalInfo(req, res) {
    // req.user should be populated by authMiddleware
    const userId = req.user.id;
    const result = await OnboardingService.savePersonalInfo(userId, req.body);

    res.status(200).json({
      success: true,
      message: 'Personal info saved successfully',
      data: result,
      meta: null
    });
  }

  static async saveFinancialSetup(req, res) {
    const userId = req.user.id;
    const result = await OnboardingService.saveFinancialSetup(userId, req.body);

    res.status(200).json({
      success: true,
      message: 'Financial setup saved and user marked as onboarded',
      data: result,
      meta: null
    });
  }
  static async saveFirstGoal(req, res) {
    const userId = req.user.id;
    const result = await OnboardingService.saveFirstGoal(userId, req.body);

    res.status(200).json({
      success: true,
      message: 'First goal saved successfully',
      data: result,
      meta: null
    });
  }
}

module.exports = { OnboardingController };
