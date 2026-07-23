const { FinancialAnalysisContextService } = require('../services/financial_analysis_context.service');
const { DashboardQueryService } = require('../services/dashboard.query.service');
const { ChatContextRepository } = require('../repositories/chat_context.repository');

describe('FinancialAnalysisContextService', () => {
  const mockUserId = 1;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('builds a snapshot payload correctly when cycle is active', async () => {
    vi.spyOn(ChatContextRepository, 'getFinancialProfileForChat').mockResolvedValue({
      currency: 'JOD'
    });

    vi.spyOn(DashboardQueryService, 'getSummary').mockResolvedValue({
      cycle: {
        id: 123,
        startDate: '2026-07-01',
        endDate: '2026-07-31',
        daysRemaining: 15
      },
      buckets: {
        needs: { target: 500, actual: 250 },
        wants: { target: 200, actual: 150 },
        savings: { target: 300, actual: 100 }
      },
      commitments: {
        upcomingCount: 1,
        overdueCount: 1,
        totalReserved: 100
      },
      goals: {
        activeCount: 3
      }
    });

    const result = await FinancialAnalysisContextService.buildSnapshotPayload(mockUserId, 'req-uuid');
    const { payload, dataQuality, scope } = result;

    expect(scope).toBe('current_cycle_to_date');
    expect(dataQuality.isPartialCycle).toBe(true);
    expect(payload.mode).toBe('financial_snapshot');
    expect(payload.request.id).toBe('req-uuid');
    expect(payload.user.currency).toBe('JOD');
    expect(payload.cycle.id).toBe('123');
    expect(payload.cycle.elapsedDays).toBe(15);
    expect(payload.plan.needsTarget).toBe(500);
    expect(payload.actuals.needsSpent).toBe(250);
    expect(payload.commitments.unpaidCount).toBe(2);
    expect(payload.commitments.unpaidAmount).toBe(100);
    expect(payload.goals.activeCount).toBe(3);
  });

  it('returns safe fallback when no active cycle exists', async () => {
    vi.spyOn(ChatContextRepository, 'getFinancialProfileForChat').mockResolvedValue({ currency: 'USD' });
    
    vi.spyOn(DashboardQueryService, 'getSummary').mockResolvedValue({
      cycle: { id: null }
    });

    const result = await FinancialAnalysisContextService.buildSnapshotPayload(mockUserId, 'req-uuid');
    const { payload, dataQuality, scope } = result;

    expect(scope).toBe('no_active_cycle');
    expect(dataQuality.hasCurrentCycle).toBe(false);
    expect(dataQuality.missingFields).toContain('currentCycle');
    expect(payload.cycle).toBeNull();
    expect(payload.plan).toBeNull();
    expect(payload.actuals).toBeNull();
  });
});
