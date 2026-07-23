const { AnalysisController } = require('../controllers/analysis.controller');
const { AnalysisService } = require('../services/analysis.service');

describe('AnalysisController', () => {
  let mockReq;
  let mockRes;
  let mockNext;

  beforeEach(() => {
    mockReq = {
      user: { id: 1 }
    };
    mockRes = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn()
    };
    mockNext = vi.fn();
    vi.clearAllMocks();
  });

  it('returns analysis result successfully', async () => {
    const mockResult = { summary: 'test summary' };
    vi.spyOn(AnalysisService, 'requestAnalysis').mockResolvedValue(mockResult);

    await AnalysisController.getAnalysis(mockReq, mockRes, mockNext);

    expect(AnalysisService.requestAnalysis).toHaveBeenCalledWith(1, {
      mode: 'financial_snapshot',
      language: 'ar',
      includeSpeechText: false,
      maxInsights: 3,
      maxRecommendations: 3
    });
    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(mockRes.json).toHaveBeenCalledWith(mockResult);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('calls next with error if service throws', async () => {
    const mockError = new Error('Service failed');
    vi.spyOn(AnalysisService, 'requestAnalysis').mockRejectedValue(mockError);

    await AnalysisController.getAnalysis(mockReq, mockRes, mockNext);

    expect(mockNext).toHaveBeenCalledWith(mockError);
  });
});
