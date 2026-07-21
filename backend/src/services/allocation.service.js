class AllocationService {
  /**
   * Determine the tier and allocation basis points based on the expected monthly income.
   * @param {number} income
   */
  static calculateTierAndBps(income) {
    if (income < 300) {
      return { tier: 'Very Low', needs_bps: 8000, wants_bps: 1500, savings_bps: 500 };
    }
    if (income < 450) {
      return { tier: 'Low', needs_bps: 7000, wants_bps: 2000, savings_bps: 1000 };
    }
    if (income < 750) {
      return { tier: 'Lower Middle', needs_bps: 6000, wants_bps: 2500, savings_bps: 1500 };
    }
    if (income < 1200) {
      return { tier: 'Middle', needs_bps: 5000, wants_bps: 3000, savings_bps: 2000 };
    }
    if (income < 2000) {
      return { tier: 'Upper Middle', needs_bps: 4000, wants_bps: 3500, savings_bps: 2500 };
    }
    if (income < 3000) {
      return { tier: 'High', needs_bps: 3000, wants_bps: 4000, savings_bps: 3000 };
    }

    return { tier: 'Very High', needs_bps: 2000, wants_bps: 4500, savings_bps: 3500 };
  }

  /**
   * Calculate exact allocation amounts for needs, wants, and savings using the Largest Remainder Method.
   * @param {number} income
   * @param {number} needsBps
   * @param {number} wantsBps
   * @param {number} savingsBps
   */
  static calculateAmounts(income, needsBps, wantsBps, savingsBps) {
    // Exact amounts
    const needsExact = income * (needsBps / 10000);
    const wantsExact = income * (wantsBps / 10000);
    const savingsExact = income * (savingsBps / 10000);

    // Initial floor amounts
    let needsAmount = Math.floor(needsExact);
    let wantsAmount = Math.floor(wantsExact);
    let savingsAmount = Math.floor(savingsExact);

    // Calculate remainders
    const remainders = [
      { type: 'needs', remainder: needsExact - needsAmount },
      { type: 'wants', remainder: wantsExact - wantsAmount },
      { type: 'savings', remainder: savingsExact - savingsAmount },
    ];

    // Sort remainders descending
    remainders.sort((a, b) => b.remainder - a.remainder);

    // How much is left to distribute
    let difference = income - (needsAmount + wantsAmount + savingsAmount);

    // Distribute remainder
    for (let i = 0; i < difference; i++) {
      if (remainders[i].type === 'needs') needsAmount += 1;
      if (remainders[i].type === 'wants') wantsAmount += 1;
      if (remainders[i].type === 'savings') savingsAmount += 1;
    }

    return {
      needsAmount,
      wantsAmount,
      savingsAmount
    };
  }
}

module.exports = { AllocationService };
