const { AnalysisService } = require('../services/analysis.service');
const { FinancialAnalysisContextService } = require('../services/financial_analysis_context.service');
const { AnalysisValidator } = require('../utils/analysis_validator.util');
const axios = require('axios');

describe('AnalysisService', () => {
  const mockUserId = 1;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('orchestrates analysis successfully', async () => {
    const mockContext = { 
      payload: { request: { id: 'req-uuid' } },
      dataQuality: { isPartialCycle: true },
      scope: 'current_cycle'
    };
    vi.spyOn(FinancialAnalysisContextService, 'buildSnapshotPayload').mockResolvedValue(mockContext);
    
    vi.spyOn(AnalysisValidator, 'validateConfig').mockReturnValue({
      webhookUrl: 'http://localhost/webhook',
      timeoutMs: 15000
    });

    const mockUpstreamResponse = {
      success: true,
      requestId: 'req-uuid',
      analysis: { summary: 'test', insights: [], recommendations: [] },
      metadata: { requestId: 'req-uuid' }
    };

    vi.spyOn(axios, 'post').mockResolvedValue({
      status: 200,
      data: mockUpstreamResponse
    });

    vi.spyOn(AnalysisValidator, 'validateN8nResponse').mockReturnValue({ summary: 'test' });

    const result = await AnalysisService.requestAnalysis(mockUserId);
    
    expect(result.summary).toBe('test');
    expect(result.scope).toBe('current_cycle');
    expect(result.dataQuality.isPartialCycle).toBe(true);
    expect(axios.post).toHaveBeenCalledTimes(1);
    expect(axios.post).toHaveBeenCalledWith('http://localhost/webhook', mockContext.payload, expect.any(Object));
  });

  it('throws timeout error on ECONNABORTED', async () => {
    vi.spyOn(FinancialAnalysisContextService, 'buildSnapshotPayload').mockResolvedValue({ payload: { request: { id: 'test' }}, dataQuality: {}, scope: ''});
    vi.spyOn(AnalysisValidator, 'validateConfig').mockReturnValue({ webhookUrl: 'http://localhost/webhook', timeoutMs: 15000 });
    
    vi.spyOn(axios, 'post').mockRejectedValue({ code: 'ECONNABORTED' });

    await expect(AnalysisService.requestAnalysis(mockUserId))
      .rejects.toThrowError('Analysis request timed out');
  });

  it('throws client error on 400', async () => {
    vi.spyOn(FinancialAnalysisContextService, 'buildSnapshotPayload').mockResolvedValue({ payload: { request: { id: 'test' }}, dataQuality: {}, scope: ''});
    vi.spyOn(AnalysisValidator, 'validateConfig').mockReturnValue({ webhookUrl: 'http://localhost/webhook', timeoutMs: 15000 });
    
    vi.spyOn(axios, 'post').mockRejectedValue({ response: { status: 400 } });

    await expect(AnalysisService.requestAnalysis(mockUserId))
      .rejects.toThrowError('Analysis client error: 400');
  });
});
