const { AppError } = require('../utils/app-error');

class AllocationService {
  /**
   * Normalize and validate income.
   * @param {any} income
   * @returns {number}
   */
  static normalizeIncome(income) {
    if (income === null || income === undefined || income === '') {
      throw new AppError('Income must be a positive number', 422, 'INVALID_INCOME');
    }
    const parsed = Number(income);
    if (isNaN(parsed) || !isFinite(parsed) || parsed <= 0) {
      throw new AppError('Income must be a positive number', 422, 'INVALID_INCOME');
    }
    const rounded = Math.round(parsed);
    if (!Number.isSafeInteger(rounded) || rounded <= 0) {
      throw new AppError('Income must be a positive safe integer', 422, 'INVALID_INCOME');
    }
    return rounded;
  }

  /**
   * Determine the tier and allocation basis points based on the expected monthly income.
   * @param {number|string} income
   */
  static calculateTierAndBps(income) {
    const parsedIncome = Number(income);
    if (!Number.isSafeInteger(parsedIncome) || parsedIncome <= 0) {
      throw new AppError('Income must be a positive safe integer', 422, 'INVALID_INCOME');
    }

    if (parsedIncome < 300) {
      return { tier: 'Very Low', needs_bps: 8000, wants_bps: 1500, savings_bps: 500 };
    }
    if (parsedIncome < 450) {
      return { tier: 'Low', needs_bps: 7000, wants_bps: 2000, savings_bps: 1000 };
    }
    if (parsedIncome < 750) {
      return { tier: 'Lower Middle', needs_bps: 6000, wants_bps: 2500, savings_bps: 1500 };
    }
    if (parsedIncome < 1200) {
      return { tier: 'Middle', needs_bps: 5000, wants_bps: 3000, savings_bps: 2000 };
    }
    if (parsedIncome < 2000) {
      return { tier: 'Upper Middle', needs_bps: 4000, wants_bps: 3500, savings_bps: 2500 };
    }
    if (parsedIncome < 3000) {
      return { tier: 'High', needs_bps: 3000, wants_bps: 4000, savings_bps: 3000 };
    }

    return { tier: 'Very High', needs_bps: 2000, wants_bps: 4500, savings_bps: 3500 };
  }

  /**
   * Calculate exact allocation amounts for needs, wants, and savings using the Largest Remainder Method.
   */
  static calculateAmounts(income, needsBps, wantsBps, savingsBps) {
    const nIncome = Number(income);
    const nNeeds = Number(needsBps);
    const nWants = Number(wantsBps);
    const nSavings = Number(savingsBps);

    if (!Number.isSafeInteger(nIncome) || nIncome <= 0) {
      throw new AppError('Income must be a positive safe integer', 422, 'INVALID_INCOME');
    }
    if (!Number.isSafeInteger(nNeeds) || nNeeds < 0 ||
        !Number.isSafeInteger(nWants) || nWants < 0 ||
        !Number.isSafeInteger(nSavings) || nSavings < 0) {
      throw new AppError('BPS values must be non-negative safe integers', 422, 'INVALID_BPS');
    }
    if (nNeeds + nWants + nSavings !== 10000) {
      throw new AppError(`BPS values must sum to 10000 (got ${nNeeds + nWants + nSavings})`, 422, 'INVALID_BPS_SUM');
    }

    // Exact amounts
    const needsExact = nIncome * (nNeeds / 10000);
    const wantsExact = nIncome * (nWants / 10000);
    const savingsExact = nIncome * (nSavings / 10000);

    // Initial floor amounts
    let needsAmount = Math.floor(needsExact);
    let wantsAmount = Math.floor(wantsExact);
    let savingsAmount = Math.floor(savingsExact);

    // Calculate remainders
    const remainders = [
      { type: 'needs', remainder: needsExact - needsAmount, originalOrder: 1 },
      { type: 'wants', remainder: wantsExact - wantsAmount, originalOrder: 2 },
      { type: 'savings', remainder: savingsExact - savingsAmount, originalOrder: 3 },
    ];

    // Sort remainders descending, with Tie-Breaker based on originalOrder
    remainders.sort((a, b) => {
      if (b.remainder !== a.remainder) {
        return b.remainder - a.remainder;
      }
      return a.originalOrder - b.originalOrder;
    });

    // How much is left to distribute
    let difference = nIncome - (needsAmount + wantsAmount + savingsAmount);

    // Distribute remainder safely with modulo
    for (let i = 0; i < difference; i++) {
      const target = remainders[i % remainders.length];
      if (target.type === 'needs') needsAmount += 1;
      if (target.type === 'wants') wantsAmount += 1;
      if (target.type === 'savings') savingsAmount += 1;
    }

    return {
      needsAmount,
      wantsAmount,
      savingsAmount
    };
  }
}

module.exports = { AllocationService };
