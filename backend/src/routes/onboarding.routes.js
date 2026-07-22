const { Router } = require('express');
const { OnboardingController } = require('../controllers/onboarding.controller');
const { personalInfoValidator, financialSetupValidator } = require('../validators/onboarding.validator');
const { validateRequest } = require('../middleware/validation.middleware');
const { authenticate } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../utils/async-handler');

const router = Router();

router.get(
  '/status',
  authenticate,
  asyncHandler(OnboardingController.getStatus)
);

router.post(
  '/personal-info',
  authenticate,
  personalInfoValidator,
  validateRequest,
  asyncHandler(OnboardingController.savePersonalInfo)
);

router.post(
  '/financial-setup',
  authenticate,
  financialSetupValidator,
  validateRequest,
  asyncHandler(OnboardingController.saveFinancialSetup)
);

router.post(
  '/first-goal',
  authenticate,
  asyncHandler(OnboardingController.saveFirstGoal)
);

// New endpoint to approve allocation preferences after user adjusts BPS values
router.post(
  '/allocation/approve',
  authenticate,
  asyncHandler(OnboardingController.approveAllocation)
);

module.exports = router;
