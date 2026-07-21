const { body } = require('express-validator');

const personalInfoValidator = [
  body('employmentStatus')
    .optional()
    .trim()
    .isString(),
  body('hasDependents')
    .optional()
    .isBoolean(),
  body('gender')
    .optional()
    .trim()
    .isString(),
  body('maritalStatus')
    .optional()
    .trim()
    .isString(),
  body('isHeadOfHousehold')
    .optional()
    .isBoolean(),
  body('isStudent')
    .optional()
    .isBoolean(),
  body('familySize')
    .optional()
    .isInt({ min: 1 })
];

const financialSetupValidator = [
  body('monthlyIncome')
    .optional()
    .isNumeric(),
  body('financialKnowledge')
    .optional()
    .trim()
    .isString(),
  body('primaryFinancialGoal')
    .optional()
    .trim()
    .isString()
];

module.exports = { personalInfoValidator, financialSetupValidator };
