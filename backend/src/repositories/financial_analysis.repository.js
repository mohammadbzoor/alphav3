const { db } = require('../config/database');

function parsePositiveInt(value, defaultValue, maxValue) {
  if (value === undefined || value === null || value === '') return defaultValue;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) return defaultValue;
  return Math.min(parsed, maxValue);
}

function parseJsonColumn(value, fallback) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

function toIso(value) {
  if (!value) return null;
  if (value instanceof Date) return value.toISOString();
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value.toString() : date.toISOString();
}

function toDateOnly(value) {
  if (!value) return null;
  if (typeof value === 'string') return value.slice(0, 10);
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return value.toString().slice(0, 10);
}

function mapFull(row) {
  if (!row) return null;
  const insights = parseJsonColumn(row.insights_json, []);
  const recommendations = parseJsonColumn(row.recommendations_json, []);
  const audioUrl = row.audio_url || null;

  return {
    id: Number(row.id),
    analysisId: row.request_identifier,
    status: row.status,
    generatedAt: toIso(row.generated_at || row.created_at),
    asOfDate: toDateOnly(row.analysis_as_of_date),
    scope: row.scope,
    summary: row.summary || '',
    insights: Array.isArray(insights) ? insights : [],
    recommendations: Array.isArray(recommendations) ? recommendations : [],
    speechText: row.speech_text || null,
    uiMetrics: parseJsonColumn(row.ui_metrics_json, null),
    audio: {
      url: audioUrl,
      duration: row.audio_duration === null || row.audio_duration === undefined
        ? null
        : Number(row.audio_duration),
    },
    dataQuality: parseJsonColumn(row.data_quality_json, {}),
  };
}

function mapListItem(row) {
  return {
    id: Number(row.id),
    analysisId: row.request_identifier,
    status: row.status,
    summaryPreview: row.summary_preview || '',
    scope: row.scope,
    analysisAsOfDate: toDateOnly(row.analysis_as_of_date),
    generatedAt: toIso(row.generated_at || row.created_at),
    insightCount: Number(row.insight_count || 0),
    hasAudio: !!row.audio_url,
  };
}

class FinancialAnalysisRepository {
  static parsePagination(query = {}) {
    const page = parsePositiveInt(query.page, 1, Number.MAX_SAFE_INTEGER);
    const limit = parsePositiveInt(query.limit, 20, 50);
    return { page, limit, offset: (page - 1) * limit };
  }

  static async createPending(data, conn = null) {
    const exec = conn || db;
    const [result] = await exec.execute(
      `INSERT INTO financial_analyses
        (request_identifier, user_id, mode, scope, language, status)
       VALUES (?, ?, ?, ?, ?, 'pending')`,
      [
        data.requestIdentifier,
        data.userId,
        data.mode,
        data.scope || 'current_cycle_to_date',
        data.language,
      ]
    );
    return result.insertId;
  }

  static async setProcessing(id, userId, conn = null) {
    const exec = conn || db;
    const [result] = await exec.execute(
      `UPDATE financial_analyses
       SET status = 'processing'
       WHERE id = ? AND user_id = ? AND status = 'pending'`,
      [id, userId]
    );
    return result.affectedRows === 1;
  }

  static async complete(id, userId, data, conn = null) {
    const exec = conn || db;
    const [result] = await exec.execute(
      `UPDATE financial_analyses
       SET status = 'completed',
           scope = ?,
           summary = ?,
           insights_json = ?,
           recommendations_json = ?,
           speech_text = ?,
           ui_metrics_json = ?,
           data_quality_json = ?,
           audio_url = ?,
           audio_duration = ?,
           analysis_as_of_date = ?,
           generated_at = ?,
           error_code = NULL
       WHERE id = ? AND user_id = ? AND status = 'processing'`,
      [
        data.scope,
        data.summary,
        JSON.stringify(data.insights),
        JSON.stringify(data.recommendations),
        data.speechText || null,
        JSON.stringify(data.uiMetrics),
        JSON.stringify(data.dataQuality || {}),
        data.audio?.url || null,
        data.audio?.duration ?? null,
        data.analysisAsOfDate || null,
        data.generatedAt,
        id,
        userId,
      ]
    );
    return result.affectedRows === 1;
  }

  static async fail(id, userId, errorCode, conn = null) {
    const exec = conn || db;
    const [result] = await exec.execute(
      `UPDATE financial_analyses
       SET status = 'failed', error_code = ?
       WHERE id = ? AND user_id = ? AND status IN ('pending', 'processing')`,
      [String(errorCode || 'ANALYSIS_FAILED').slice(0, 80), id, userId]
    );
    return result.affectedRows === 1;
  }

  static async findCompletedByIdAndUserId(id, userId, conn = null) {
    const exec = conn || db;
    const [rows] = await exec.execute(
      `SELECT id, request_identifier, status, scope, summary, insights_json,
              recommendations_json, speech_text, ui_metrics_json, data_quality_json,
              audio_url, audio_duration, analysis_as_of_date, generated_at, created_at
       FROM financial_analyses
       WHERE id = ? AND user_id = ? AND status = 'completed'
       LIMIT 1`,
      [id, userId]
    );
    return mapFull(rows[0]);
  }

  static async listForUser(userId, options = {}, conn = null) {
    const exec = conn || db;
    const { page, limit, offset } = this.parsePagination(options);
    const fetchLimit = limit + 1;

    const [rows] = await exec.execute(
      `SELECT id, request_identifier, status,
              LEFT(COALESCE(summary, ''), 180) AS summary_preview,
              scope, analysis_as_of_date, generated_at, created_at,
              CASE
                WHEN JSON_TYPE(insights_json) = 'ARRAY' THEN JSON_LENGTH(insights_json)
                ELSE 0
              END AS insight_count,
              audio_url
       FROM financial_analyses
       WHERE user_id = ? AND status = 'completed'
       ORDER BY generated_at DESC, id DESC
       LIMIT ? OFFSET ?`,
      [userId, fetchLimit.toString(), offset.toString()]
    );

    return {
      items: rows.slice(0, limit).map(mapListItem),
      pagination: {
        page,
        limit,
        hasMore: rows.length > limit,
      },
    };
  }
}

module.exports = { FinancialAnalysisRepository };
