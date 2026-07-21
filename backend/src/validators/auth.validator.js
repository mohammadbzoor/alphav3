const { body } = require('express-validator');

const registerValidator = [
  body('fullName')
    .trim()
    .notEmpty().withMessage('Full name is required')
    .isLength({ min: 2 }).withMessage('Full name must be at least 2 characters')
    .isLength({ max: 150 }).withMessage('Full name must not exceed 150 characters'),

  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .custom((value) => {
      // Basic normalization logic for Jordanian numbers
      let normalized = value;
      if (normalized.startsWith('07')) {
        normalized = '+9627' + normalized.substring(2);
      } else if (normalized.startsWith('79') || normalized.startsWith('78') || normalized.startsWith('77')) {
        normalized = '+962' + normalized;
      }

      if (!/^(\+9627)[789]\d{7}$/.test(normalized)) {
        throw new Error('Invalid Jordanian phone number format');
      }
      return true;
    }),

  body('email')
    .trim()
    .toLowerCase()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Please provide a valid email address'),

  body('birthDate')
    .notEmpty().withMessage('Birth date is required')
    .isDate({ format: 'YYYY-MM-DD' }).withMessage('Birth date must be a valid date (YYYY-MM-DD)')
    .custom((value) => {
      const selectedDate = new Date(value);
      const today = new Date();
      if (selectedDate > today) {
        throw new Error('Birth date cannot be in the future');
      }
      return true;
    }),

  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/(?=.*[a-z])/).withMessage('Password must contain a lowercase letter')
    .matches(/(?=.*[A-Z])/).withMessage('Password must contain an uppercase letter')
    .matches(/(?=.*\d)/).withMessage('Password must contain a number')
];

const verifyPhoneValidator = [
  body('phoneNumber')
    .trim()
    .notEmpty().withMessage('Phone number is required'),
  body('otpCode')
    .trim()
    .notEmpty().withMessage('OTP code is required')
    .isLength({ min: 6, max: 6 }).withMessage('OTP must be exactly 6 digits')
];

const loginValidator = [
  body('phoneNumber')
    .trim()
    .notEmpty().withMessage('Phone number is required'),
  body('password')
    .notEmpty().withMessage('Password is required')
];

const forgotPasswordValidator = [
  body('email')
    .trim()
    .toLowerCase()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Please provide a valid email address')
];

const verifyResetOtpValidator = [
  body('email')
    .trim()
    .toLowerCase()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Please provide a valid email address'),
  body('otpCode')
    .trim()
    .notEmpty().withMessage('OTP code is required')
    .isLength({ min: 6, max: 6 }).withMessage('OTP must be exactly 6 digits')
];

const resetPasswordValidator = [
  body('email')
    .trim()
    .toLowerCase()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Please provide a valid email address'),
  body('otpCode')
    .trim()
    .notEmpty().withMessage('OTP code is required')
    .isLength({ min: 6, max: 6 }).withMessage('OTP must be exactly 6 digits'),
  body('newPassword')
    .notEmpty().withMessage('New password is required')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/(?=.*[a-z])/).withMessage('Password must contain a lowercase letter')
    .matches(/(?=.*[A-Z])/).withMessage('Password must contain an uppercase letter')
    .matches(/(?=.*\d)/).withMessage('Password must contain a number')
];

module.exports = {
  registerValidator,
  verifyPhoneValidator,
  loginValidator,
  forgotPasswordValidator,
  verifyResetOtpValidator,
  resetPasswordValidator
};
