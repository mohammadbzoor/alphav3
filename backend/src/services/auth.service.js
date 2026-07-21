const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const axios = require('axios');
const { env } = require('../config/env');
const { UserRepository } = require('../repositories/user.repository');
const { AppError } = require('../utils/app-error');

class AuthService {
  static normalizePhone(phone) {
    let normalized = phone.trim();
    if (normalized.startsWith('07')) {
      normalized = '+9627' + normalized.substring(2);
    } else if (normalized.startsWith('79') || normalized.startsWith('78') || normalized.startsWith('77')) {
      normalized = '+962' + normalized;
    }
    return normalized;
  }

  static async register(data) {
    const email = data.email.trim().toLowerCase();
    const phone = this.normalizePhone(data.phone);
    const { fullName, birthDate, password } = data;

    const existingUser = await UserRepository.findByEmailOrPhone(email, phone);

    if (existingUser) {
      if (existingUser.email.toLowerCase() === email) {
        throw new AppError('Email is already registered', 409, 'EMAIL_ALREADY_EXISTS');
      }
      if (existingUser.phone === phone) {
        throw new AppError('Phone number is already registered', 409, 'PHONE_ALREADY_EXISTS');
      }
    }

    const passwordHash = await bcrypt.hash(password, env.bcryptSaltRounds);

    const userId = await UserRepository.createUser({
      fullName: fullName.trim(),
      email,
      phone,
      birthDate,
      passwordHash
    });

    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    // Save OTP to DB
    await UserRepository.saveOtp(userId, otpCode, expiresAt);

    // Send to terminal
    console.log('\n=============================================');
    console.log(`[SIMULATED SMS] To: ${phone}`);
    console.log(`Your Alpha verification code is: ${otpCode}`);
    console.log('=============================================\n');

    // Trigger n8n webhook
    try {
      if (env.n8nOtpWebhookUrl) {
        await axios.post(env.n8nOtpWebhookUrl, {
        email: email,
        name: fullName.trim(),
        otp: otpCode
        });
      }
    } catch (err) {
      console.error('Failed to send OTP to n8n webhook:', err.message);
    }

    const user = await UserRepository.findById(userId);

    // Format for response
    return {
      id: user.id,
      fullName: user.full_name,
      phone: user.phone,
      email: user.email,
      birthDate: user.birth_date,
      isVerified: Boolean(user.is_verified)
    };
  }

  static async verifyPhone(data) {
    const phone = this.normalizePhone(data.phoneNumber);
    const { otpCode } = data;

    const result = await UserRepository.verifyOtp(phone, otpCode);

    if (!result.valid) {
      throw new AppError(result.message, 400, 'INVALID_OTP');
    }

    // Usually we would generate JWT tokens here since the user is now fully verified and logged in
    const user = await UserRepository.findById(result.userId);

    const accessToken = jwt.sign({ id: user.id }, env.jwtAccessSecret || 'secret', { expiresIn: env.jwtAccessExpiresIn || '15m' });
    const refreshToken = jwt.sign({ id: user.id }, env.jwtRefreshSecret || 'secret', { expiresIn: env.jwtRefreshExpiresIn || '30d' });

    return {
      user: {
        id: user.id,
        fullName: user.full_name,
        phone: user.phone,
        email: user.email,
        birthDate: user.birth_date,
        isVerified: Boolean(user.is_verified),
        isOnboarded: Boolean(user.is_onboarded)
      },
      tokens: {
        accessToken,
        refreshToken
      }
    };
  }

  static async login(data) {
    const phone = this.normalizePhone(data.phoneNumber);
    const { password } = data;

    const user = await UserRepository.findByPhone(phone);
    if (!user) {
      throw new AppError('Invalid phone number or password', 401, 'INVALID_CREDENTIALS');
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      throw new AppError('Invalid phone number or password', 401, 'INVALID_CREDENTIALS');
    }

    if (!user.is_verified) {
      throw new AppError('Account not verified', 403, 'ACCOUNT_NOT_VERIFIED');
    }

    const accessToken = jwt.sign({ id: user.id }, env.jwtAccessSecret || 'secret', { expiresIn: env.jwtAccessExpiresIn || '15m' });
    const refreshToken = jwt.sign({ id: user.id }, env.jwtRefreshSecret || 'secret', { expiresIn: env.jwtRefreshExpiresIn || '30d' });

    return {
      user: {
        id: user.id,
        fullName: user.full_name,
        phone: user.phone,
        email: user.email,
        isOnboarded: Boolean(user.is_onboarded)
      },
      tokens: {
        accessToken,
        refreshToken
      }
    };
  }

  static async forgotPassword(data) {
    const email = data.email.trim().toLowerCase();
    const user = await UserRepository.findByEmail(email);

    if (!user) {
      // Return success anyway to prevent email enumeration attacks
      return { success: true };
    }

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    await UserRepository.saveOtp(user.id, otpCode, expiresAt);

    // Send to terminal for debugging
    console.log('\n=============================================');
    console.log(`[SIMULATED EMAIL] To: ${email}`);
    console.log(`Your Alpha password reset code is: ${otpCode}`);
    console.log('=============================================\n');

    try {
      if (env.n8nOtpWebhookUrl) {
        await axios.post(env.n8nOtpWebhookUrl, {
          email: user.email,
          name: user.full_name,
          otp: otpCode
        });
      }
    } catch (err) {
      console.error('Failed to send Reset OTP to n8n webhook:', err.message);
    }

    return { success: true };
  }

  static async verifyResetOtp(data) {
    const email = data.email.trim().toLowerCase();
    const { otpCode } = data;

    const result = await UserRepository.checkOtpByEmail(email, otpCode);

    if (!result.valid) {
      throw new AppError(result.message, 400, 'INVALID_OTP');
    }

    return { valid: true };
  }

  static async resetPassword(data) {
    const email = data.email.trim().toLowerCase();
    const { otpCode, newPassword } = data;

    const result = await UserRepository.checkOtpByEmail(email, otpCode);

    if (!result.valid) {
      throw new AppError(result.message, 400, 'INVALID_OTP');
    }

    const passwordHash = await bcrypt.hash(newPassword, env.bcryptSaltRounds);

    await UserRepository.updatePassword(result.userId, passwordHash);

    return { success: true };
  }
  static generateTokens(userId) {
    const accessToken = jwt.sign({ id: userId }, env.jwtAccessSecret || 'secret', { expiresIn: env.jwtAccessExpiresIn || '15m' });
    const refreshToken = jwt.sign({ id: userId }, env.jwtRefreshSecret || 'secret', { expiresIn: env.jwtRefreshExpiresIn || '30d' });
    return { accessToken, refreshToken };
  }

  static async refreshToken(data) {
    const { refreshToken } = data;
    if (!refreshToken) {
      throw new AppError('Refresh token required', 400);
    }
    try {
      const decoded = jwt.verify(refreshToken, env.jwtRefreshSecret || 'secret');
      const tokens = this.generateTokens(decoded.id);
      return { tokens };
    } catch (err) {
      throw new AppError('Invalid refresh token', 401, 'TOKEN_EXPIRED');
    }
  }

  static async changePassword(userId, data) {
    const { currentPassword, newPassword, confirmPassword } = data;

    if (!currentPassword || !newPassword || !confirmPassword) {
      throw new AppError('All password fields are required', 400);
    }

    if (newPassword !== confirmPassword) {
      throw new AppError('New passwords do not match', 400);
    }

    if (newPassword.length < 8) {
      throw new AppError('Password must be at least 8 characters long', 400);
    }

    const user = await UserRepository.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    const userWithHash = await UserRepository.findByPhone(user.phone);
    
    const isMatch = await bcrypt.compare(currentPassword, userWithHash.password_hash);
    if (!isMatch) {
      throw new AppError('Current password is incorrect', 400, 'INVALID_CREDENTIALS');
    }

    const isSameAsOld = await bcrypt.compare(newPassword, userWithHash.password_hash);
    if (isSameAsOld) {
      throw new AppError('New password cannot be the same as the current password', 400);
    }

    const passwordHash = await bcrypt.hash(newPassword, env.bcryptSaltRounds);
    await UserRepository.updatePassword(userId, passwordHash);

    return { success: true };
  }
}

module.exports = { AuthService };
