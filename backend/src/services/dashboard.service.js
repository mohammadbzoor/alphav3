const { FinanceRepository } = require('../repositories/finance.repository');

class DashboardService {
  static async getDashboard(userId) {
    const totals = await FinanceRepository.getDashboardTotals(userId);

    const balance = totals.totalIncome - totals.totalExpenses;

    let savingsRate = 0;
    if (totals.totalIncome > 0) {
      savingsRate = (balance / totals.totalIncome) * 100;
    }

    return {
      totalIncome: totals.totalIncome,
      totalExpenses: totals.totalExpenses,
      balance: balance,
      activeGoals: totals.activeGoals,
      savingsRate: savingsRate
    };
  }

  static async getHealthScore(userId) {
    const totals = await FinanceRepository.getDashboardTotals(userId);

    const balance = totals.totalIncome - totals.totalExpenses;
    let savingsRate = 0;
    if (totals.totalIncome > 0) {
      savingsRate = (balance / totals.totalIncome) * 100;
    }

    let score = 50; // Base score

    // Add points for positive cashflow
    if (balance > 0) score += 20;
    if (balance < 0) score -= 20;

    // Add points for savings rate
    if (savingsRate > 20) score += 20;
    else if (savingsRate > 10) score += 10;
    else if (savingsRate < 0) score -= 10;

    // Add points for having active goals
    if (totals.activeGoals > 0) score += 10;
    if (totals.activeGoals > 3) score += 10;

    // Clamp score between 0 and 100
    score = Math.max(0, Math.min(100, score));

    let status = 'Fair';
    if (score >= 80) status = 'Excellent';
    else if (score >= 60) status = 'Good';
    else if (score < 40) status = 'Poor';

    return {
      score: score,
      status: status
    };
  }
}

module.exports = { DashboardService };
