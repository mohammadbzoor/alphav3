const axios = require('axios');
const crypto = require('crypto');
const { db } = require('../config/database');
const { FinancialAnalysisContextService } = require('./financial_analysis_context.service');
const { FinancialAnalysisRepository } = require('../repositories/financial_analysis.repository');
const { AnalysisValidator } = require('../utils/analysis_validator.util');
const { AppError } = require('../utils/app-error');

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function metricFromValues(currentValue, targetValue, kind) {
  const current = toNumber(currentValue);
  const target = toNumber(targetValue);
  if (current === null || target === null || target <= 0) {
    return { current: null, target: null, percent: null, status: 'unavailable' };
  }

  const percent = Math.max(0, Math.round((current / target) * 10000) / 100);
  let status = 'on_track';
  if (kind === 'savings') {
    if (percent >= 100) status = 'completed';
    else if (percent < 50) status = 'warning';
  } else if (percent > 100) {
    status = 'exceeded';
  } else if (percent > 85) {
    status = 'warning';
  }

  return { current, target, percent, status };
}

function buildAuthoritativeMetrics(payload) {
  if (!payload || !payload.plan || !payload.actuals) {
    return {
      savings: { current: null, target: null, percent: null, status: 'unavailable' },
      needs: { current: null, target: null, percent: null, status: 'unavailable' },
      wants: { current: null, target: null, percent: null, status: 'unavailable' },
    };
  }

  return {
    savings: metricFromValues(payload.actuals.savingsSaved, payload.plan.savingsTarget, 'savings'),
    needs: metricFromValues(payload.actuals.needsSpent, payload.plan.needsTarget, 'needs'),
    wants: metricFromValues(payload.actuals.wantsSpent, payload.plan.wantsTarget, 'wants'),
  };
}

function safeErrorCode(error) {
  if (error && error.code) return error.code;
  if (error && error.response && error.response.status >= 500) return 'ANALYSIS_UPSTREAM_SERVER_ERROR';
  return 'ANALYSIS_FAILED';
}

class AnalysisService {
  static async createPendingAnalysis(userId, requestId, config) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const id = await FinancialAnalysisRepository.createPending({
        userId,
        requestIdentifier: requestId,
        mode: config.mode,
        language: config.language,
        scope: 'current_cycle_to_date',
      }, conn);
      await conn.commit();
      return id;
    } catch (error) {
      await conn.rollback();
      throw error;
    } finally {
      conn.release();
    }
  }

  static async completeAnalysis(userId, analysisRowId, safeResponse, context) {
    const completed = await FinancialAnalysisRepository.complete(analysisRowId, userId, {
      scope: context.scope,
      summary: safeResponse.data.content.summary,
      insights: safeResponse.data.content.insights,
      recommendations: safeResponse.data.content.recommendations,
      speechText: safeResponse.data.content.speechText,
      uiMetrics: safeResponse.data.uiMetrics,
      dataQuality: context.dataQuality,
      audio: safeResponse.data.audio,
      analysisAsOfDate: safeResponse.metadata.analysisAsOfDate,
      generatedAt: safeResponse.metadata.generatedAt,
    });

    if (!completed) {
      throw new AppError('Analysis could not be completed', 409, 'ANALYSIS_DUPLICATE_COMPLETION');
    }

    return FinancialAnalysisRepository.findCompletedByIdAndUserId(analysisRowId, userId);
  }

  static async requestAnalysis(userId, config = {}) {
    const requestId = crypto.randomUUID();
    const effectiveConfig = {
      mode: config.mode || 'financial_snapshot',
      language: config.language || 'ar',
      includeSpeechText: config.includeSpeechText === true,
      maxInsights: config.maxInsights || 3,
      maxRecommendations: config.maxRecommendations || 3,
    };

    const analysisRowId = await this.createPendingAnalysis(userId, requestId, effectiveConfig);

    try {
      const context = await FinancialAnalysisContextService.buildSnapshotPayload(userId, requestId);
      context.payload.options = {
        language: effectiveConfig.language,
        includeSpeechText: effectiveConfig.includeSpeechText,
        maxInsights: effectiveConfig.maxInsights,
        maxRecommendations: effectiveConfig.maxRecommendations,
      };

      const transitioned = await FinancialAnalysisRepository.setProcessing(analysisRowId, userId);
      if (!transitioned) {
        throw new AppError('Analysis is already processing or completed', 409, 'ANALYSIS_INVALID_STATE');
      }

      const configValues = AnalysisValidator.validateConfig();
      const { webhookUrl, timeoutMs } = configValues;

      if (process.env.NODE_ENV === 'test' && webhookUrl.includes('mohammadn8n.cfd')) {
        throw new Error('TEST GUARD: Real n8n webhook URL used in test environment!');
      }

      let response;
      try {
        response = await axios.post(webhookUrl, context.payload, {
          timeout: timeoutMs,
          headers: {
            'Content-Type': 'application/json',
            'X-Request-ID': requestId,
            'Idempotency-Key': requestId,
          },
          maxRedirects: 0,
        });
      } catch (error) {
        if (error.code === 'ECONNABORTED' || (error.message && error.message.includes('timeout'))) {
          throw new AppError('Analysis request timed out', 504, 'ANALYSIS_UPSTREAM_TIMEOUT');
        }

        if (error.response) {
          const status = error.response.status;
          if (status >= 400 && status < 500) {
            throw new AppError(`Analysis client error: ${status}`, status, 'ANALYSIS_UPSTREAM_CLIENT_ERROR');
          }
          if (status >= 500) {
            throw new AppError(`Analysis server error: ${status}`, status, 'ANALYSIS_UPSTREAM_SERVER_ERROR');
          }
        }

        throw new AppError('Analysis upstream connection failed', 502, 'ANALYSIS_UPSTREAM_CONNECTION_FAILED');
      }

      const safeResponse = AnalysisValidator.validateN8nResponse(response.data, requestId, effectiveConfig);
      return this.completeAnalysis(userId, analysisRowId, safeResponse, context);
    } catch (error) {
      await FinancialAnalysisRepository.fail(analysisRowId, userId, safeErrorCode(error));
      throw error;
    }
  }

  static async listAnalyses(userId, query = {}) {
    return FinancialAnalysisRepository.listForUser(userId, query);
  }

  static async getAnalysis(userId, id) {
    const analysis = await FinancialAnalysisRepository.findCompletedByIdAndUserId(id, userId);
    if (!analysis) {
      throw new AppError('Analysis not found', 404, 'ANALYSIS_NOT_FOUND');
    }
    return analysis;
  }
}

module.exports = { AnalysisService };
