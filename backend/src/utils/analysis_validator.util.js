const { AppError } = require('./app-error');

const STATUS_ALLOWLIST = new Set(['unavailable', 'on_track', 'warning', 'exceeded', 'completed']);
const FORBIDDEN_KEYS = new Set([
  'action',
  'actions',
  'command',
  'commands',
  'tool',
  'tools',
  'toolCall',
  'sql',
  'SQL',
  'mutation',
  'mutations',
  'endpoint',
  'webhook',
  'financialMutation',
  'transactionWrite',
]);

function fail(message, code) {
  throw new AppError(message, 502, code);
}

function assertNoForbiddenFields(value) {
  if (!value || typeof value !== 'object') return;
  if (Array.isArray(value)) {
    value.forEach(assertNoForbiddenFields);
    return;
  }

  for (const [key, child] of Object.entries(value)) {
    if (FORBIDDEN_KEYS.has(key)) {
      fail('Upstream response contains forbidden mutation fields', 'ANALYSIS_UPSTREAM_FORBIDDEN_FIELDS');
    }
    assertNoForbiddenFields(child);
  }
}

function boundedStringList(value, fieldName, maxItems) {
  if (!Array.isArray(value)) {
    fail(`Upstream response missing ${fieldName} array`, 'ANALYSIS_UPSTREAM_INVALID_ARRAYS');
  }

  return value
    .map(item => (typeof item === 'string' ? item.trim() : ''))
    .filter(Boolean)
    .slice(0, maxItems)
    .map(item => item.slice(0, 700));
}

function normalizeMetric(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { current: null, target: null, percent: null, status: 'unavailable' };
  }

  const status = typeof value.status === 'string' && STATUS_ALLOWLIST.has(value.status)
    ? value.status
    : 'unavailable';

  if (status === 'unavailable') {
    return { current: null, target: null, percent: null, status };
  }

  const current = Number(value.current);
  const target = Number(value.target);
  const percent = Number(value.percent);

  if (![current, target, percent].every(Number.isFinite)) {
    fail('Upstream response contains malformed metrics', 'ANALYSIS_UPSTREAM_INVALID_METRICS');
  }

  return { current, target, percent, status };
}

function normalizeAudio(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { url: null, duration: null };
  }

  const rawUrl = value.url;
  if (rawUrl === null || rawUrl === undefined || rawUrl === '') {
    return { url: null, duration: null };
  }
  if (typeof rawUrl !== 'string' || rawUrl.length > 2048) {
    fail('Upstream response contains malformed audio metadata', 'ANALYSIS_UPSTREAM_INVALID_AUDIO');
  }

  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch (_) {
    return { url: null, duration: null };
  }

  if (parsed.protocol === 'http:') {
    parsed.protocol = 'https:';
    rawUrl = parsed.toString();
  }

  const allowedHosts = (process.env.ANALYSIS_AUDIO_ALLOWED_HOSTS || '')
    .split(',')
    .map(host => host.trim().toLowerCase())
    .filter(Boolean);

  if (allowedHosts.length > 0 && !allowedHosts.includes(parsed.hostname.toLowerCase())) {
    if (!parsed.hostname.toLowerCase().includes('cloudinary.com')) {
      return { url: null, duration: null };
    }
  }

  const duration = value.duration === null || value.duration === undefined
    ? null
    : Number(value.duration);
  if (duration !== null && (!Number.isFinite(duration) || duration < 0 || duration > 3600)) {
    fail('Upstream response contains malformed audio metadata', 'ANALYSIS_UPSTREAM_INVALID_AUDIO');
  }

  return { url: rawUrl, duration };
}

class AnalysisValidator {
  static validateConfig() {
    const webhookUrl = process.env.N8N_ANALYSIS_WEBHOOK_URL;
    const timeoutMs = parseInt(process.env.N8N_ANALYSIS_TIMEOUT_MS || '30000', 10);

    if (!webhookUrl) {
      throw new Error('N8N_ANALYSIS_WEBHOOK_URL is not configured');
    }

    return { webhookUrl, timeoutMs };
  }

  static validateRequestBody(body = {}) {
    const allowedFields = ['mode', 'language', 'includeSpeechText', 'maxInsights', 'maxRecommendations'];
    const invalidFields = Object.keys(body).filter(key => !allowedFields.includes(key));
    if (invalidFields.length > 0) {
      throw new AppError(
        `Invalid request fields provided: ${invalidFields.join(', ')}. Only mode, language, includeSpeechText, maxInsights, maxRecommendations are allowed.`,
        400,
        'ANALYSIS_INVALID_REQUEST'
      );
    }

    const config = {
      mode: body.mode || 'financial_snapshot',
      language: body.language || 'ar',
      includeSpeechText: typeof body.includeSpeechText === 'boolean' ? body.includeSpeechText : false,
      maxInsights: body.maxInsights ? parseInt(body.maxInsights, 10) : 3,
      maxRecommendations: body.maxRecommendations ? parseInt(body.maxRecommendations, 10) : 3,
    };

    if (config.mode !== 'financial_snapshot') {
      throw new AppError('Only financial_snapshot mode is supported currently', 400, 'ANALYSIS_UNSUPPORTED_MODE');
    }
    if (config.language !== 'ar') {
      throw new AppError('Only Arabic analysis is supported currently', 400, 'ANALYSIS_UNSUPPORTED_LANGUAGE');
    }
    if (!Number.isInteger(config.maxInsights) || !Number.isInteger(config.maxRecommendations) ||
        config.maxInsights < 1 || config.maxInsights > 5 ||
        config.maxRecommendations < 1 || config.maxRecommendations > 5) {
      throw new AppError('maxInsights and maxRecommendations must be integers from 1 to 5', 400, 'ANALYSIS_INVALID_LIMITS');
    }

    return config;
  }

  static validateN8nResponse(rawResponse, expectedRequestId, options = {}) {
    if (typeof rawResponse === 'string' && rawResponse.trim().startsWith('<')) {
      fail('Upstream returned HTML instead of JSON', 'ANALYSIS_UPSTREAM_INVALID_RESPONSE');
    }
    if (!rawResponse || typeof rawResponse !== 'object') {
      fail('Invalid or empty upstream response', 'ANALYSIS_UPSTREAM_INVALID_RESPONSE');
    }

    if (Array.isArray(rawResponse)) {
      if (rawResponse.length !== 1) {
        fail('Upstream response must contain exactly one result', 'ANALYSIS_UPSTREAM_INVALID_ARRAY_SHAPE');
      }
      rawResponse = rawResponse[0];
    }

    if (!rawResponse || typeof rawResponse !== 'object' || Array.isArray(rawResponse)) {
      fail('Invalid upstream result object', 'ANALYSIS_UPSTREAM_INVALID_RESPONSE');
    }

    assertNoForbiddenFields(rawResponse);

    if (rawResponse.status !== 'success') {
      fail('Upstream returned non-success status', 'ANALYSIS_UPSTREAM_FAILED');
    }

    const data = rawResponse.data || rawResponse;
    const content = data?.content;
    const metadata = rawResponse.metadata || {};

    if (!content || typeof content !== 'object' || Array.isArray(content)) {
      fail('Upstream response missing content object', 'ANALYSIS_UPSTREAM_INVALID_CONTENT');
    }

    const requestId = metadata?.requestId || expectedRequestId;
    if (!requestId || requestId === 'unknown' || requestId !== expectedRequestId) {
      fail('Upstream request ID missing or mismatched', 'ANALYSIS_UPSTREAM_ID_MISMATCH');
    }

    const summary = typeof content.summary === 'string' ? content.summary.trim() : '';
    if (!summary) {
      fail('Upstream response missing valid summary text', 'ANALYSIS_UPSTREAM_INVALID_SUMMARY');
    }

    return {
      status: 'success',
      data: {
        content: {
          summary: summary.slice(0, 4000),
          insights: boundedStringList(content.insights, 'insights', options.maxInsights || 3),
          recommendations: boundedStringList(content.recommendations, 'recommendations', options.maxRecommendations || 3),
          speechText: typeof content.speechText === 'string' && content.speechText.trim()
            ? content.speechText.trim().slice(0, 5000)
            : null,
        },
        uiMetrics: {
          savings: normalizeMetric(data?.uiMetrics?.savings),
          needs: normalizeMetric(data?.uiMetrics?.needs),
          wants: normalizeMetric(data?.uiMetrics?.wants),
        },
        audio: normalizeAudio(data?.audio),
      },
      metadata: {
        requestId,
        analysisAsOfDate: metadata?.analysisAsOfDate || new Date().toISOString().slice(0, 10),
        generatedAt: (metadata?.generatedAt ? new Date(metadata.generatedAt) : new Date()).toISOString().slice(0, 19).replace('T', ' '),
      },
    };
  }
}

module.exports = { AnalysisValidator };
