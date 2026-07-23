const { AnalysisService } = require('../services/analysis.service');
const { AnalysisValidator } = require('../utils/analysis_validator.util');
const { AppError } = require('../utils/app-error');

class AnalysisController {
  static async generate(req, res, next) {
    try {
      const userId = req.user.id;
      const config = AnalysisValidator.validateRequestBody(req.body || {});
      const analysis = await AnalysisService.requestAnalysis(userId, config);

      res.status(200).json({
        success: true,
        analysis,
      });
    } catch (error) {
      next(error);
    }
  }

  static async list(req, res, next) {
    try {
      const data = await AnalysisService.listAnalyses(req.user.id, req.query || {});
      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  }

  static async detail(req, res, next) {
    try {
      const id = Number(req.params.id);
      if (!Number.isInteger(id) || id <= 0) {
        throw new AppError('Analysis not found', 404, 'ANALYSIS_NOT_FOUND');
      }

      const analysis = await AnalysisService.getAnalysis(req.user.id, id);
      res.status(200).json({
        success: true,
        analysis,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = { AnalysisController };
