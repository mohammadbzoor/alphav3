const { Router } = require('express');
const { AuthController } = require('../controllers/auth.controller');
const {
  registerValidator,
  verifyPhoneValidator,
  loginValidator,
  forgotPasswordValidator,
  verifyResetOtpValidator,
  resetPasswordValidator
} = require('../validators/auth.validator');
const { validateRequest } = require('../middleware/validation.middleware');
const { asyncHandler } = require('../utils/async-handler');
const { authenticate } = require('../middleware/auth.middleware');

const router = Router();

router.post('/register', registerValidator, validateRequest, asyncHandler(AuthController.register));
router.post('/verify-phone', verifyPhoneValidator, validateRequest, asyncHandler(AuthController.verifyPhone));
router.post('/login', loginValidator, validateRequest, asyncHandler(AuthController.login));
router.post('/logout', authenticate, asyncHandler(AuthController.logout));
router.post('/refresh-token', asyncHandler(AuthController.refreshToken));

// Forgot Password Flow
router.post('/forgot-password', forgotPasswordValidator, validateRequest, asyncHandler(AuthController.forgotPassword));
router.post('/verify-reset-otp', verifyResetOtpValidator, validateRequest, asyncHandler(AuthController.verifyResetOtp));
router.post('/reset-password', resetPasswordValidator, validateRequest, asyncHandler(AuthController.resetPassword));

// Change Password
router.post('/change-password', authenticate, asyncHandler(AuthController.changePassword));

module.exports = router;
