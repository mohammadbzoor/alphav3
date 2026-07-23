const { db } = require('../config/database');

class DashboardQueryService {
  static async getSummary(userId) {
    // 1. Check for active financial cycle (open only)
    const [cycles] = await db.execute(
      `SELECT id, status, start_date, end_date, expected_income FROM financial_cycles
       WHERE user_id = ? AND status = 'open'
       ORDER BY start_date DESC LIMIT 1`,
      [userId]
    );

    if (!cycles || cycles.length === 0) {
      // No open cycle - check if there's a closed cycle to provide context
      const [closedCycles] = await db.execute(
        `SELECT id, closed_at FROM financial_cycles
         WHERE user_id = ? AND status = 'closed'
         ORDER BY closed_at DESC LIMIT 1`,
        [userId]
      );

      const warnings = ['NO_ACTIVE_FINANCIAL_CYCLE'];
      if (closedCycles && closedCycles.length > 0) {
        warnings.push('PREVIOUS_CYCLE_CLOSED');
      }

      return {
        cycle: { id: null, status: null, startDate: null, endDate: null, daysRemaining: null },
        income: { expected: 0, recorded: 0, recurring: 0, unexpected: 0 },
        buckets: {
          needs: { target: 0, actual: 0, reserved: 0, availableVariable: 0, remaining: 0, usagePercent: null, status: 'unavailable' },
          wants: { target: 0, actual: 0, remaining: 0, usagePercent: null, status: 'unavailable' },
          savings: { target: 0, actual: 0, plannedEmergencyFund: 0, plannedGoalAllocations: 0, unallocatedSavings: 0, remaining: 0, usagePercent: null, status: 'unavailable' }
        },
        goals: { activeCount: 0, readyCount: 0, items: [] },
        commitments: { totalReserved: 0, upcomingCount: 0, overdueCount: 0 },
        safeDailySpending: { amount: null, reliability: 'unavailable', reasons: [] },
        comparison: { previousPeriodAvailable: false, incomeChange: null, expenseChange: null, savingsChange: null },
        setupRequired: true,
        reliability: 'unavailable',
        warnings
      };
    }

    const cycle = cycles[0];
    const cycleId = cycle.id;
    
    // Calculate days remaining
    const now = new Date();
    const endDate = new Date(cycle.end_date);
    let daysRemaining = Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
    if (daysRemaining < 0) daysRemaining = 0;

    // Get expected income from cycle
    const expectedIncome = Number(cycle.expected_income) || 0;

    // 2. Income transactions
    const [incomes] = await db.execute(
      `SELECT SUM(amount) as total, income_kind 
       FROM transactions 
       WHERE user_id = ? AND cycle_id = ? AND transaction_type = 'income' AND status = 'confirmed'
       GROUP BY income_kind`,
      [userId, cycleId]
    );

    let recordedIncome = 0;
    let recurringIncome = 0;
    let unexpectedIncome = 0;

    incomes.forEach(row => {
      const amount = Number(row.total);
      recordedIncome += amount;
      if (row.income_kind === 'recurring') recurringIncome += amount;
      if (row.income_kind === 'unexpected') unexpectedIncome += amount;
    });

    // 3. Needs/Wants Actuals
    const [outflows] = await db.execute(
      `SELECT budget_bucket, SUM(amount) as total
       FROM transactions WHERE user_id = ? AND cycle_id = ? AND direction = 'outflow' AND transaction_type = 'expense' AND status = 'confirmed'
       GROUP BY budget_bucket`,
      [userId, cycleId]
    );

    let needsActual = 0;
    let wantsActual = 0;

    outflows.forEach(row => {
      if (row.budget_bucket === 'needs') needsActual += Number(row.total);
      if (row.budget_bucket === 'wants') wantsActual += Number(row.total);
    });

    // 4. Commitments (Reserved Needs) – join financial_commitments to enforce user ownership
    const [commitmentsCounts] = await db.execute(
      `SELECT COUNT(*) as cnt, co.status
       FROM commitment_occurrences co
       JOIN financial_commitments fc ON fc.id = co.commitment_id AND fc.user_id = ?
       WHERE co.cycle_id = ? AND co.status IN ('upcoming', 'due', 'overdue')
       GROUP BY co.status`,
      [userId, cycleId]
    );
    const [commitmentsSums] = await db.execute(
      `SELECT SUM(co.amount) as total, co.status
       FROM commitment_occurrences co
       JOIN financial_commitments fc ON fc.id = co.commitment_id AND fc.user_id = ?
       WHERE co.cycle_id = ? AND co.status IN ('upcoming', 'due', 'overdue')
       GROUP BY co.status`,
      [userId, cycleId]
    );

    let reservedNeeds = 0;
    let upcomingCount = 0;
    let overdueCount = 0;

    if (commitmentsSums && commitmentsSums.length) {
      commitmentsSums.forEach(row => {
        reservedNeeds += Number(row.total);
      });
    }
    if (commitmentsCounts && commitmentsCounts.length) {
      commitmentsCounts.forEach(row => {
        if (row.status === 'upcoming' || row.status === 'due') upcomingCount += Number(row.cnt);
        if (row.status === 'overdue') overdueCount += Number(row.cnt);
      });
    }

    // 5. Bucket Targets
    const [allocations] = await db.execute(
      `SELECT needs_target, wants_target, savings_target, needs_bps, wants_bps, savings_bps
       FROM cycle_allocation_snapshots 
       WHERE cycle_id = ? LIMIT 1`,
      [cycleId]
    );

    let needsTarget = 0;
    let wantsTarget = 0;
    let savingsTarget = 0;
    let needsBps = null;
    let wantsBps = null;
    let savingsBps = null;

    if (allocations.length > 0) {
      needsTarget = Number(allocations[0].needs_target);
      wantsTarget = Number(allocations[0].wants_target);
      savingsTarget = Number(allocations[0].savings_target);
      needsBps = allocations[0].needs_bps !== null ? Number(allocations[0].needs_bps) : null;
      wantsBps = allocations[0].wants_bps !== null ? Number(allocations[0].wants_bps) : null;
      savingsBps = allocations[0].savings_bps !== null ? Number(allocations[0].savings_bps) : null;
    }

    // Savings actual
    const [savingsTrans] = await db.execute(
      `SELECT SUM(amount) as total
       FROM transactions 
       WHERE user_id = ? AND cycle_id = ? AND budget_bucket = 'savings' AND direction = 'outflow' AND status = 'confirmed'`,
      [userId, cycleId]
    );
    let savingsActual = savingsTrans.length > 0 ? (Number(savingsTrans[0].total) || 0) : 0;

    // Planned savings from cycle-linked allocation
    const [savingsAlloc] = await db.execute(
      `SELECT emergency_fund_amount, emergency_fund_rate, total_goal_allocations, unallocated_savings_amount, status
       FROM cycle_savings_allocations
       WHERE cycle_id = ?`,
      [cycleId]
    );
    let plannedEmergencyFund = 0;
    let plannedEmergencyFundRate = null;
    let plannedGoalAllocations = 0;
    let unallocatedSavings = 0;

    if (savingsAlloc.length > 0) {
      plannedEmergencyFund = Number(savingsAlloc[0].emergency_fund_amount);
      plannedEmergencyFundRate = savingsAlloc[0].emergency_fund_rate !== null ? Number(savingsAlloc[0].emergency_fund_rate) : null;
      plannedGoalAllocations = Number(savingsAlloc[0].total_goal_allocations);
      unallocatedSavings = Number(savingsAlloc[0].unallocated_savings_amount);
    }

    // Goals
    const [goalsList] = await db.execute(
      `SELECT id, name, target_amount as targetAmount, current_balance as currentBalance, status
       FROM goals
       WHERE user_id = ? AND status IN ('active', 'ready')`,
      [userId]
    );

    let activeCount = 0;
    let readyCount = 0;
    const goalsItems = goalsList.map(g => {
      if (g.status === 'active') activeCount++;
      if (g.status === 'ready') readyCount++;
      return {
        id: g.id,
        name: g.name,
        targetAmount: Number(g.targetAmount),
        currentBalance: Number(g.currentBalance),
        status: g.status
      };
    });

    // Calculations
    const availableVariableNeeds = needsTarget - needsActual - reservedNeeds;
    
    const calculateBucketStatus = (actual, target, elapsedRatio) => {
        if (target === 0) return 'unavailable';
        const actualRatio = actual / target;
        const paceVariance = actualRatio - elapsedRatio;
        if (actualRatio < 0.5) return 'healthy';
        if (actualRatio < 0.8) return 'moderate';
        if (actualRatio <= 1.0) return 'warning';
        if (paceVariance > 0.2) return 'critical';
        return 'exceeded';
      };
      const now_calc = new Date();
      const start = new Date(cycle.start_date);
      const end = new Date(cycle.end_date);
      const totalDays = Math.max(1, (end - start) / (1000 * 60 * 60 * 24));
      const elapsedDays = Math.min(totalDays, (now_calc - start) / (1000 * 60 * 60 * 24));
      const elapsedRatio = elapsedDays / totalDays;

    return {
      cycle: {
        id: cycleId,
        status: cycle.status,
        startDate: cycle.start_date,
        endDate: cycle.end_date,
        daysRemaining: daysRemaining
      },
      income: {
        expected: expectedIncome,
        recorded: recordedIncome,
        recurring: recurringIncome,
        unexpected: unexpectedIncome
      },
      buckets: {
        needs: {
            target: needsTarget,
            targetBps: needsBps,
            actual: needsActual,
            reserved: reservedNeeds,
            availableVariable: availableVariableNeeds,
            remaining: needsTarget - needsActual,
            usagePercent: needsTarget > 0 ? (needsActual / needsTarget) * 100 : null,
            status: calculateBucketStatus(needsActual, needsTarget, elapsedRatio)
          },
          wants: {
            target: wantsTarget,
            targetBps: wantsBps,
            actual: wantsActual,
            remaining: wantsTarget - wantsActual,
            usagePercent: wantsTarget > 0 ? (wantsActual / wantsTarget) * 100 : null,
            status: calculateBucketStatus(wantsActual, wantsTarget, elapsedRatio)
          },
          savings: {
            target: savingsTarget,
            targetBps: savingsBps,
            actual: savingsActual,
            plannedEmergencyFund: plannedEmergencyFund,
            plannedEmergencyFundRate: plannedEmergencyFundRate,
            plannedGoalAllocations: plannedGoalAllocations,
            unallocatedSavings: unallocatedSavings,
            remaining: savingsTarget - savingsActual,
            usagePercent: savingsTarget > 0 ? (savingsActual / savingsTarget) * 100 : null,
            status: calculateBucketStatus(savingsActual, savingsTarget, elapsedRatio)
          }
      },
      goals: {
        activeCount: activeCount,
        readyCount: readyCount,
        items: goalsItems
      },
      commitments: {
        totalReserved: reservedNeeds,
        upcomingCount: upcomingCount,
        overdueCount: overdueCount
      },
      safeDailySpending: (function() {
          const confirmedIncome = recordedIncome;
          const confirmedConsumption = needsActual + wantsActual;
          const unpaidCommitments = (upcomingCount + overdueCount) > 0 ? reservedNeeds : 0; 
          const reservedSavings = plannedEmergencyFund + plannedGoalAllocations;
          const totalAvailable = confirmedIncome - confirmedConsumption - unpaidCommitments - reservedSavings;
          if (daysRemaining > 0 && totalAvailable > 0) {
            return {
              amount: totalAvailable / daysRemaining,
              reliability: 'reliable',
              reasons: []
            };
          } else {
            const reasons = [];
            if (confirmedIncome === 0) reasons.push('no_confirmed_income');
            if (totalAvailable <= 0) reasons.push('insufficient_funds');
            return { amount: null, reliability: 'unavailable', reasons };
          }
        })(),
      comparison: {
        previousPeriodAvailable: false,
        incomeChange: null,
        expenseChange: null,
        savingsChange: null
      },
      setupRequired: false,
      reliability: 'reliable',
      warnings: []
    };
  }
}

module.exports = { DashboardQueryService };
