const { db } = require('../config/database');

/**
 * Contract: Numeric strings (e.g., "10") are intentionally accepted to accommodate 
 * HTTP query parameters which typically arrive as strings. They are parsed strictly.
 */
function parsePaginationLimit(value, defaultVal, maxVal) {
  if (value === undefined || value === null) return defaultVal;
  if (typeof value !== 'number' && typeof value !== 'string') throw new Error('Invalid limit: must be a positive integer');
  if (typeof value === 'string' && value.trim() === '') throw new Error('Invalid limit: must be a positive integer');
  const parsed = Number(value);
  if (parsed > Number.MAX_SAFE_INTEGER) throw new Error('Invalid limit: exceeds MAX_SAFE_INTEGER');
  if (!Number.isInteger(parsed) || parsed <= 0 || parsed > maxVal) throw new Error(`Invalid limit: must be between 1 and ${maxVal}`);
  return parsed;
}

function parsePaginationOffset(value) {
  if (value === undefined || value === null) return 0;
  if (typeof value !== 'number' && typeof value !== 'string') throw new Error('Invalid offset: must be a non-negative integer');
  if (typeof value === 'string' && value.trim() === '') throw new Error('Invalid offset: must be a non-negative integer');
  const parsed = Number(value);
  if (parsed > Number.MAX_SAFE_INTEGER) throw new Error('Invalid offset: exceeds MAX_SAFE_INTEGER');
  if (!Number.isInteger(parsed) || parsed < 0) throw new Error('Invalid offset: must be a non-negative integer');
  return parsed;
}

class ChatRepository {
  // ==========================================
  // CONVERSATIONS
  // ==========================================

  static async createConversation(userId, data = {}, conn = null) {
    const exec = conn || db;
    const title = data.title || null;
    const channel = data.channel || 'mobile';
    const language = data.language || 'ar';
    const status = data.status || 'active';

    const [result] = await exec.execute(
      `INSERT INTO chat_conversations (user_id, title, status, language, channel) VALUES (?, ?, ?, ?, ?)`,
      [userId, title, status, language, channel]
    );
    return result.insertId;
  }

  static async findConversationByIdAndUserId(conversationId, userId, conn = null) {
    const exec = conn || db;
    const [rows] = await exec.execute(
      `SELECT id, user_id, title, status, language, channel, started_at, last_message_at, created_at, updated_at 
       FROM chat_conversations 
       WHERE id = ? AND user_id = ? LIMIT 1`,
      [conversationId, userId]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async listUserConversations(userId, options = {}, conn = null) {
    const exec = conn || db;
    const limit = parsePaginationLimit(options.limit, 20, 50);
    const offset = parsePaginationOffset(options.offset);

    const [rows] = await exec.execute(
      `SELECT id, user_id, title, status, language, channel, started_at, last_message_at, created_at, updated_at 
       FROM chat_conversations 
       WHERE user_id = ? 
       ORDER BY last_message_at DESC, id DESC 
       LIMIT ? OFFSET ?`,
      [userId, limit.toString(), offset.toString()]
    );
    return rows;
  }

  static async updateConversationLastMessageAt(conversationId, userId, timestamp, conn = null) {
    const exec = conn || db;
    const [result] = await exec.execute(
      `UPDATE chat_conversations 
       SET last_message_at = GREATEST(last_message_at, ?) 
       WHERE id = ? AND user_id = ?`,
      [timestamp, conversationId, userId]
    );
    return result.affectedRows > 0;
  }

  static async closeConversation(conversationId, userId, conn = null) {
    const exec = conn || db;
    const [result] = await exec.execute(
      `UPDATE chat_conversations SET status = 'closed' WHERE id = ? AND user_id = ?`,
      [conversationId, userId]
    );
    return result.affectedRows > 0;
  }

  // ==========================================
  // MESSAGES
  // ==========================================

  static async createMessage(conversationId, data, conn = null) {
    const exec = conn || db;
    const { role, content, intent = null, status = 'completed', metadata = null } = data;
    const metaJson = metadata ? JSON.stringify(metadata) : null;

    const [result] = await exec.execute(
      `INSERT INTO chat_messages (conversation_id, role, content, intent, status, metadata) VALUES (?, ?, ?, ?, ?, ?)`,
      [conversationId, role, content, intent, status, metaJson]
    );
    return result.insertId;
  }

  static async findMessageById(messageId, conn = null) {
    const exec = conn || db;
    const [rows] = await exec.execute(
      `SELECT id, conversation_id, role, content, intent, status, created_at 
       FROM chat_messages 
       WHERE id = ? LIMIT 1`,
      [messageId]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async updateMessageStatus(messageId, status, conn = null) {
    const exec = conn || db;
    const [result] = await exec.execute(
      `UPDATE chat_messages SET status = ? WHERE id = ?`,
      [status, messageId]
    );
    return result.affectedRows > 0;
  }

  static async getConversationMessages(conversationId, userId, options = {}, conn = null) {
    const exec = conn || db;
    const limit = parsePaginationLimit(options.limit, 50, 100);
    const offset = parsePaginationOffset(options.offset);

    const query = `
      SELECT m.id, m.conversation_id, m.role, m.content, m.intent, m.status, m.created_at
      FROM chat_messages AS m
      INNER JOIN chat_conversations AS c ON c.id = m.conversation_id
      WHERE m.conversation_id = ? AND c.user_id = ?
      ORDER BY m.created_at ASC, m.id ASC
      LIMIT ? OFFSET ?
    `;
    const [rows] = await exec.execute(query, [conversationId, userId, limit.toString(), offset.toString()]);
    return rows;
  }

  static async getRecentConversationMessages(conversationId, userId, limit = 10, conn = null) {
    const exec = conn || db;
    const parsedLimit = parsePaginationLimit(limit, 10, 50);
    
    // To get chronological order of the most recent, we use a subquery to bound and sort DESC, then outer sort ASC
    const [rows] = await exec.execute(
      `SELECT * FROM (
         SELECT m.id, m.conversation_id, m.role, m.content, m.intent, m.status, m.created_at
         FROM chat_messages AS m
         INNER JOIN chat_conversations AS c ON c.id = m.conversation_id
         WHERE m.conversation_id = ? AND c.user_id = ? AND m.status = 'completed'
         ORDER BY m.created_at DESC, m.id DESC 
         LIMIT ?
       ) AS recent ORDER BY created_at ASC, id ASC`,
      [conversationId, userId, parsedLimit.toString()]
    );
    return rows;
  }

  // ==========================================
  // REQUESTS
  // ==========================================

  static async createChatRequest(data, conn = null) {
    const exec = conn || db;
    const {
      conversationId,
      userId,
      userMessageId = null,
      assistantMessageId = null,
      requestIdentifier,
      provider = 'n8n',
      providerExecutionId = null,
      status = 'pending',
      requestPayload = null,
      responsePayload = null
    } = data;

    // Strict payload redaction
    const storeFullPayload = process.env.CHAT_STORE_FULL_PAYLOAD === 'true';

    let finalReq = null;
    if (requestPayload && typeof requestPayload === 'object') {
      if (storeFullPayload) {
        finalReq = requestPayload;
      } else {
        // Redacted allow-list for request
        finalReq = {
          schemaVersion: requestPayload.schemaVersion,
          requestIdentifier: requestPayload.requestIdentifier,
          conversationId: requestPayload.conversationId,
          intent: requestPayload.intent,
          language: requestPayload.language,
          source: requestPayload.source,
          transactionCount: requestPayload.transactionCount,
          goalCount: requestPayload.goalCount,
          hasPurchaseContext: requestPayload.hasPurchaseContext,
          generatedAt: requestPayload.generatedAt,
          redacted: true
        };
      }
    }

    let finalRes = null;
    if (responsePayload && typeof responsePayload === 'object') {
      if (storeFullPayload) {
        finalRes = responsePayload;
      } else {
        // Redacted allow-list for response
        finalRes = {
          success: responsePayload.success,
          requestIdentifier: responsePayload.requestIdentifier,
          provider: responsePayload.provider,
          providerExecutionId: responsePayload.providerExecutionId,
          responseStatus: responsePayload.responseStatus,
          generatedAt: responsePayload.generatedAt,
          redacted: true
        };
      }
    }

    const reqJson = finalReq ? JSON.stringify(finalReq) : null;
    const resJson = finalRes ? JSON.stringify(finalRes) : null;

    const [result] = await exec.execute(
      `INSERT INTO chat_requests (
        conversation_id, user_id, user_message_id, assistant_message_id,
        request_identifier, provider, provider_execution_id, status,
        request_payload, response_payload
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        conversationId, userId, userMessageId, assistantMessageId,
        requestIdentifier, provider, providerExecutionId, status,
        reqJson, resJson
      ]
    );
    return result.insertId;
  }

  static async findChatRequestByIdentifier(requestIdentifier, conn = null) {
    const exec = conn || db;
    // Normal request lookup MUST NOT return JSON payloads
    const [rows] = await exec.execute(
      `SELECT id, conversation_id, user_id, user_message_id, assistant_message_id,
              request_identifier, provider, provider_execution_id, status, http_status,
              duration_ms, retry_count, error_message, sent_at, completed_at, created_at, updated_at
       FROM chat_requests WHERE request_identifier = ? LIMIT 1`,
      [requestIdentifier]
    );
    return rows.length > 0 ? rows[0] : null;
  }
  
  static async findChatRequestByIdentifierAndUserId(requestIdentifier, userId, conn = null) {
    const exec = conn || db;
    const [rows] = await exec.execute(
      `SELECT id, conversation_id, user_id, user_message_id, assistant_message_id,
              request_identifier, provider, provider_execution_id, status, http_status,
              duration_ms, retry_count, error_message, sent_at, completed_at, created_at, updated_at
       FROM chat_requests WHERE request_identifier = ? AND user_id = ? LIMIT 1`,
      [requestIdentifier, userId]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  /**
   * Internal diagnostic method explicitly explicitly requesting payload inclusion.
   * Do not use in normal chat operations.
   */
  static async findChatRequestWithPayloadByIdentifier(requestIdentifier, conn = null) {
    const exec = conn || db;
    const [rows] = await exec.execute(
      `SELECT id, conversation_id, user_id, user_message_id, assistant_message_id,
              request_identifier, provider, provider_execution_id, status,
              request_payload, response_payload, http_status, duration_ms,
              retry_count, error_message, sent_at, completed_at, created_at, updated_at
       FROM chat_requests WHERE request_identifier = ? LIMIT 1`,
      [requestIdentifier]
    );
    return rows.length > 0 ? rows[0] : null;
  }

  static async updateChatRequestStatusInternal(requestId, newStatus, currentStatusCondition = null, data = {}, conn = null) {
    const exec = conn || db;
    const updates = ['status = ?'];
    const values = [newStatus];

    if (data.responsePayload !== undefined) {
      updates.push('response_payload = ?');
      if (data.responsePayload && typeof data.responsePayload === 'object') {
        const storeFullPayload = process.env.CHAT_STORE_FULL_PAYLOAD === 'true';
        let finalRes = data.responsePayload;
        if (!storeFullPayload) {
          finalRes = {
            success: finalRes.success,
            requestIdentifier: finalRes.requestIdentifier,
            provider: finalRes.provider,
            providerExecutionId: finalRes.providerExecutionId,
            responseStatus: finalRes.responseStatus,
            generatedAt: finalRes.generatedAt,
            redacted: true
          };
        }
        values.push(JSON.stringify(finalRes));
      } else {
        values.push(null);
      }
    }
    if (data.httpStatus !== undefined) {
      updates.push('http_status = ?');
      values.push(data.httpStatus);
    }
    if (data.durationMs !== undefined) {
      updates.push('duration_ms = ?');
      values.push(data.durationMs);
    }
    if (data.errorMessage !== undefined) {
      updates.push('error_message = ?');
      values.push(data.errorMessage);
    }
    if (data.sentAt !== undefined) {
      updates.push('sent_at = ?');
      values.push(data.sentAt);
    }
    if (data.completedAt !== undefined) {
      updates.push('completed_at = ?');
      values.push(data.completedAt);
    }
    if (data.assistantMessageId !== undefined) {
      updates.push('assistant_message_id = ?');
      values.push(data.assistantMessageId);
    }

    values.push(requestId);
    
    let query = `UPDATE chat_requests SET ${updates.join(', ')} WHERE id = ?`;
    if (currentStatusCondition) {
      if (Array.isArray(currentStatusCondition)) {
        query += ` AND status IN (${currentStatusCondition.map(() => '?').join(', ')})`;
        values.push(...currentStatusCondition);
      } else {
        query += ` AND status = ?`;
        values.push(currentStatusCondition);
      }
    }

    const [result] = await exec.execute(query, values);
    return result.affectedRows > 0;
  }

  static async completeChatRequestInternal(requestId, data = {}, conn = null) {
    // only processing -> completed is valid
    return this.updateChatRequestStatusInternal(requestId, 'completed', 'processing', {
      ...data,
      completedAt: new Date()
    }, conn);
  }

  static async failChatRequestInternal(requestId, data = {}, conn = null) {
    // pending or processing -> failed is valid
    return this.updateChatRequestStatusInternal(requestId, 'failed', ['pending', 'processing'], {
      ...data,
      completedAt: new Date()
    }, conn);
  }

  static async setChatRequestProcessingInternal(requestId, conn = null) {
    // pending -> processing only
    return this.updateChatRequestStatusInternal(requestId, 'processing', 'pending', {}, conn);
  }

  static async retryChatRequestInternal(requestId, conn = null) {
    const exec = conn || db;
    // Atomically transition from failed -> processing and increment retry_count
    const [result] = await exec.execute(
      `UPDATE chat_requests 
       SET status = 'processing', retry_count = retry_count + 1 
       WHERE id = ? AND status = 'failed' AND retry_count < 255`,
      [requestId]
    );
    return result.affectedRows > 0;
  }
}

module.exports = { ChatRepository };
