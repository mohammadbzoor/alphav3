const { AuthService } = require('../services/auth.service');
const { sendResponse } = require('../utils/api-response');

class AuthController {
  static async register(req, res) {
    const user = await AuthService.register(req.body);

    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      data: {
        user,
        verificationRequired: true
      },
      meta: null
    });
  }

  static async verifyPhone(req, res) {
    const result = await AuthService.verifyPhone(req.body);

    res.status(200).json({
      success: true,
      message: 'Phone verified successfully',
      data: result,
      meta: null
    });
  }

  static async login(req, res) {
    const result = await AuthService.login(req.body);

    res.status(200).json({
      success: true,
      message: 'Logged in successfully',
      data: result,
      meta: null
    });
  }

  static async logout(req, res) {
    // In a stateless JWT setup, logout is handled client-side by deleting the token.
    // If you implement a token blacklist in the future, you would add the token here.
    res.status(200).json({
      success: true,
      message: 'Logged out successfully',
      data: null,
      meta: null
    });
  }
  static async forgotPassword(req, res) {
    const result = await AuthService.forgotPassword(req.body);
    res.status(200).json({
      success: true,
      message: 'If the email is registered, an OTP has been sent.',
      data: result,
      meta: null
    });
  }

  static async verifyResetOtp(req, res) {
    const result = await AuthService.verifyResetOtp(req.body);
    res.status(200).json({
      success: true,
      message: 'OTP verified successfully.',
      data: result,
      meta: null
    });
  }

  static async resetPassword(req, res) {
    const result = await AuthService.resetPassword(req.body);
    res.status(200).json({
      success: true,
      message: 'Password has been reset successfully.',
      data: result,
      meta: null
    });
  }

  static async refreshToken(req, res) {
    const result = await AuthService.refreshToken(req.body);
    res.status(200).json({
      success: true,
      message: 'Tokens refreshed successfully.',
      data: result,
      meta: null
    });
  }

  static async changePassword(req, res) {
    const result = await AuthService.changePassword(req.user.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Password changed successfully',
      data: result,
      meta: null
    });
  }
}

module.exports = { AuthController };
