const crypto = require('crypto');
const { DashboardQueryService } = require('./dashboard.query.service');
const { ChatContextRepository } = require('../repositories/chat_context.repository');
const { FinanceRepository } = require('../repositories/finance.repository');

class FinancialAnalysisContextService {
  /**
   * Builds the enriched snapshot payload for n8n analysis.
   */
  static async buildSnapshotPayload(userId, requestId = crypto.randomUUID()) {
    // 1. Basic profile (currency, expected income)
    const profile = await ChatContextRepository.getFinancialProfileForChat(userId);
    const currency = profile?.currency || 'JOD';
    const expectedIncome = profile?.expected_monthly_income ?? null;

    // 2. Dashboard summary (current open cycle, allocations, commitments, goals)
    const summary = await DashboardQueryService.getSummary(userId);

    // Ensure we have an open cycle; otherwise return minimal payload
    if (!summary.cycle || !summary.cycle.id) {
      return {
        payload: {
          schemaVersion: '1.1',
          type: 'analyze',
          request: {
            id: requestId,
            mode: 'financial_snapshot',
            requestedAt: new Date().toISOString(),
            analysisAsOfDate: new Date().toISOString().slice(0,10),
            language: 'ar',
            timezone: 'Asia/Amman',
            includeSpeechText: true,
            maxInsights: 3,
            maxRecommendations: 3
          },
          userContext: { locale: 'ar-JO', currency },
          financialProfile: { expectedIncome, currency, timezone: 'Asia/Amman' },
          cycle: null,
          plan: null,
          actuals: null,
          expenseCategories: [],
          recentTransactions: [],
          commitments: { paidCount: 0, upcomingCount: 0, overdueCount: 0, unpaidAmount: 0, items: [] },
          goals: { activeCount: 0, readyCount: 0, totalTargetAmount: 0, totalCurrentBalance: 0, totalRemainingAmount: 0, items: [] },
          emergencyFund: {},
          historicalCycles: [],
          dataQuality: { hasFinancialProfile: false, hasCurrentCycle: false, hasApprovedSnapshot: false, isPartialCycle: false, missingFields: [], transactionsAreConfirmedOnly: true, transactionDetailsAreBounded: true, historicalCyclesAreBounded: true },
          privacy: { containsFinancialData: true, dataScope: 'extended_financial_analysis', generatedAt: new Date().toISOString() }
        },
        dataQuality: { hasFinancialProfile: false, hasCurrentCycle: false, hasApprovedSnapshot: false, isPartialCycle: false, missingFields: ['plan.needs.targetBps', 'plan.wants.targetBps', 'plan.savings.targetBps', 'actuals.remainingBudget', 'actuals.projectedExpenses', 'actuals.safeDailySpend', 'emergencyFund.plannedRate', 'emergencyFund.plannedCycleAmount', 'emergencyFund.lifetimeBalance', 'emergencyFund.targetAmount'], transactionsAreConfirmedOnly: true, transactionDetailsAreBounded: true, historicalCyclesAreBounded: true },
        scope: 'no_active_cycle'
      };
    }

    // 3. Assemble detailed sections using repository helpers
    const cycle = summary.cycle;
    const cycleId = cycle.id;
    const startDate = new Date(cycle.startDate);
    const endDate = new Date(cycle.endDate);
    const totalDays = Math.max(1, Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24)));
    const elapsedDays = Math.max(0, totalDays - cycle.daysRemaining);
    const remainingDays = Math.max(0, cycle.daysRemaining);
    const isPartial = elapsedDays < totalDays;

    // Plan (allocation snapshot for the current cycle)
    const allocation = summary.buckets; // already contains targets

    // Actuals (confirmed expenses)
    const actuals = {
      confirmedIncome: summary.income?.recorded ?? 0,
      needsSpent: summary.buckets.needs.actual ?? 0,
      wantsSpent: summary.buckets.wants.actual ?? 0,
      confirmedSavings: summary.buckets.savings.actual ?? 0,
      totalSpent: (summary.buckets.needs.actual ?? 0) + (summary.buckets.wants.actual ?? 0) + (summary.buckets.savings.actual ?? 0),
      remainingBudget: null,
      projectedExpenses: null,
      safeDailySpend: summary.safeDailySpending?.amount ?? null
    };

    // Expense categories (top 5)
    const expenseCategories = await FinanceRepository.getTopExpenseCategories(userId, cycleId, 5);

    // Recent bounded transactions (max 10)
    const recentTransactions = await FinanceRepository.getBoundedRecentTransactions(userId, cycleId, 10);

    // Commitments detailed list (max 5)
    const commitments = await FinanceRepository.getCommitmentDetails(userId, 5);

    // Ordinary goals (max 5, filtered)
    const goals = await FinanceRepository.getOrdinaryGoalDetails(userId, 5);

    // Emergency fund details
    const emergencyFundGoal = await FinanceRepository.getEmergencyFundDetails(userId);
    const emergencyFund = {
      exists: emergencyFundGoal.exists,
      plannedRate: allocation.savings.plannedEmergencyFundRate ?? null,
      plannedCycleAmount: allocation.savings.plannedEmergencyFund ?? null,
      lifetimeBalance: emergencyFundGoal.currentBalance,
      targetAmount: emergencyFundGoal.targetAmount,
      status: emergencyFundGoal.status
    };

    // Historical cycles (last 3 completed)
    const historicalCycles = await FinanceRepository.getHistoricalCycles(userId, 3);

    const missingFields = [];
    if (allocation.needs.targetBps === null) missingFields.push('plan.needs.targetBps');
    if (allocation.wants.targetBps === null) missingFields.push('plan.wants.targetBps');
    if (allocation.savings.targetBps === null) missingFields.push('plan.savings.targetBps');
    if (actuals.remainingBudget === null) missingFields.push('actuals.remainingBudget');
    if (actuals.projectedExpenses === null) missingFields.push('actuals.projectedExpenses');
    if (actuals.safeDailySpend === null) missingFields.push('actuals.safeDailySpend');
    if (emergencyFund.plannedRate === null) missingFields.push('emergencyFund.plannedRate');
    if (emergencyFund.plannedCycleAmount === null) missingFields.push('emergencyFund.plannedCycleAmount');
    if (emergencyFund.lifetimeBalance === null) missingFields.push('emergencyFund.lifetimeBalance');
    if (emergencyFund.targetAmount === null) missingFields.push('emergencyFund.targetAmount');
    missingFields.sort();

    // Data quality flags
    const dataQuality = {
      hasFinancialProfile: true,
      hasCurrentCycle: true,
      hasApprovedSnapshot: true,
      isPartialCycle: isPartial,
      missingFields: missingFields,
      transactionsAreConfirmedOnly: true,
      transactionDetailsAreBounded: true,
      historicalCyclesAreBounded: true
    };

    const payload = {
      schemaVersion: '1.1',
      type: 'analyze',
      request: {
        id: requestId,
        mode: 'financial_snapshot',
        requestedAt: new Date().toISOString(),
        analysisAsOfDate: new Date().toISOString().slice(0,10),
        language: 'ar',
        timezone: 'Asia/Amman',
        includeSpeechText: true,
        maxInsights: 3,
        maxRecommendations: 3
      },
      userContext: { locale: 'ar-JO', currency },
      financialProfile: { expectedIncome, currency, timezone: 'Asia/Amman' },
      cycle: {
        id: String(cycleId),
        status: cycle.status,
        startDate: cycle.startDate,
        endDate: cycle.endDate,
        elapsedDays,
        remainingDays,
        totalDays,
        isPartial
      },
      plan: {
        baseIncome: expectedIncome,
        needs: { targetBps: allocation.needs.targetBps, targetAmount: allocation.needs.target },
        wants: { targetBps: allocation.wants.targetBps, targetAmount: allocation.wants.target },
        savings: { targetBps: allocation.savings.targetBps, targetAmount: allocation.savings.target }
      },
      actuals,
      expenseCategories,
      recentTransactions,
      commitments,
      goals,
      emergencyFund,
      historicalCycles,
      dataQuality,
      privacy: { containsFinancialData: true, dataScope: 'extended_financial_analysis', generatedAt: new Date().toISOString() }
    };

    return { payload, dataQuality, scope: 'current_cycle_to_date' };
  }
}

module.exports = { FinancialAnalysisContextService };
