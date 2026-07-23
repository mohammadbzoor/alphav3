const { AppError } = require('./app-error');

class ChatValidationError extends Error {
  constructor(message, code) {
    super(message);
    this.name = 'ChatValidationError';
    this.code = code || 'PAYLOAD_VALIDATION_FAILED';
  }
}

class ChatValidator {
  /**
   * Validates configuration for N8N Webhook.
   */
  static validateConfig() {
    const webhookUrl = process.env.N8N_CHAT_WEBHOOK_URL;
    const isLocalEnv = process.env.NODE_ENV === 'test' || process.env.NODE_ENV === 'development';
    const isValidUrl = webhookUrl && (webhookUrl.startsWith('https://') || (isLocalEnv && webhookUrl.startsWith('http://')));
    
    if (!isValidUrl) {
      throw new AppError('Invalid or missing N8N_CHAT_WEBHOOK_URL. Must be HTTPS (or HTTP in test/dev).', 500, 'CHAT_CONFIGURATION_ERROR');
    }

    const timeoutMs = parseInt(process.env.N8N_CHAT_TIMEOUT_MS, 10);
    if (!Number.isFinite(timeoutMs) || timeoutMs <= 0 || timeoutMs > 60000 || String(timeoutMs) !== process.env.N8N_CHAT_TIMEOUT_MS) {
      throw new AppError('Invalid or missing N8N_CHAT_TIMEOUT_MS', 500, 'CHAT_CONFIGURATION_ERROR');
    }

    const maxRetries = parseInt(process.env.N8N_CHAT_MAX_RETRIES, 10);
    if (!Number.isFinite(maxRetries) || maxRetries < 0 || maxRetries > 3 || String(maxRetries) !== process.env.N8N_CHAT_MAX_RETRIES) {
      throw new AppError('Invalid or missing N8N_CHAT_MAX_RETRIES', 500, 'CHAT_CONFIGURATION_ERROR');
    }

    const storePayload = process.env.CHAT_STORE_FULL_PAYLOAD;
    if (storePayload !== 'true' && storePayload !== 'false') {
      throw new AppError('Invalid CHAT_STORE_FULL_PAYLOAD. Must be exact lowercase true or false.', 500, 'CHAT_CONFIGURATION_ERROR');
    }

    return { webhookUrl, timeoutMs, maxRetries, storeFullPayload: storePayload === 'true' };
  }

  /**
   * Validates strict input contract for POST /messages.
   * Rejects unknown fields.
   */
  static validateIncomingRequest(body) {
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw new AppError('Invalid request body', 400, 'INVALID_INPUT');
    }

    // Strict allowlist of top-level keys
    const allowedKeys = ['conversationId', 'message', 'intent', 'language', 'context'];
    const bodyKeys = Object.keys(body);
    const hasUnknownKeys = bodyKeys.some(key => !allowedKeys.includes(key));
    if (hasUnknownKeys) {
      throw new AppError('Request body contains unknown or unauthorized fields', 400, 'INVALID_INPUT');
    }

    // Reject explicitly forbidden injected fields if somehow they bypass the key check
    const forbidden = ['userId', 'requestId', 'source', 'financial', 'transactions', 'goals', 'messages', 'conversationHistory', 'systemMessage', 'webhookUrl', 'tools', 'actions'];
    const hasForbidden = bodyKeys.some(key => forbidden.includes(key));
    if (hasForbidden) {
      throw new AppError('Request body contains unauthorized fields', 400, 'INVALID_INPUT');
    }

    // Validate context object if present
    if (body.context !== undefined && body.context !== null) {
      if (typeof body.context !== 'object' || Array.isArray(body.context)) {
        throw new AppError('Invalid context format', 400, 'INVALID_INPUT');
      }

      const allowedContextKeys = ['purchase'];
      const contextKeys = Object.keys(body.context);
      if (contextKeys.some(key => !allowedContextKeys.includes(key))) {
        throw new AppError('Context contains unknown fields', 400, 'INVALID_INPUT');
      }

      if (body.context.purchase) {
        if (typeof body.context.purchase !== 'object' || Array.isArray(body.context.purchase)) {
          throw new AppError('Invalid purchase context format', 400, 'INVALID_INPUT');
        }
        const allowedPurchaseKeys = ['item', 'price', 'category'];
        const purchaseKeys = Object.keys(body.context.purchase);
        if (purchaseKeys.some(key => !allowedPurchaseKeys.includes(key))) {
          throw new AppError('Purchase context contains unknown fields', 400, 'INVALID_INPUT');
        }
      }
    }

    return true; // Or we can rely on validateChatContextInput to do the deeper types
  }
  /**
   * Validates the input given to ChatContextService.
   */
  static validateChatContextInput(input) {
    if (!input || typeof input !== 'object') {
      throw new AppError('Invalid chat context input', 400, 'INVALID_INPUT');
    }

    const { userId, conversationId, requestId, message, intent = 'chat', language = 'ar', source = 'mobile', purchase = null, timestamp, excludeMessageId = null } = input;

    if (!userId || typeof userId !== 'number' && typeof userId !== 'string') throw new AppError('Missing or invalid userId', 400, 'INVALID_INPUT');
    if (!conversationId || typeof conversationId !== 'number' && typeof conversationId !== 'string') throw new AppError('Missing or invalid conversationId', 400, 'INVALID_INPUT');
    
    // Request ID must be a UUID (basic validation)
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!requestId || typeof requestId !== 'string' || !uuidRegex.test(requestId)) {
      throw new AppError('Missing or invalid requestId', 400, 'INVALID_INPUT');
    }

    if (!message || typeof message !== 'string') throw new AppError('Missing or invalid message', 400, 'INVALID_INPUT');
    const msgTrimmed = message.trim();
    if (msgTrimmed.length < 1) throw new AppError('Message is too short', 400, 'INVALID_INPUT');
    if (msgTrimmed.length > 2000) throw new AppError('Message exceeds maximum length of 2000 characters', 400, 'INVALID_INPUT');

    if (intent !== 'chat') throw new AppError(`Unsupported intent: ${intent}`, 400, 'INVALID_INPUT');
    if (source !== 'mobile') throw new AppError(`Unsupported source: ${source}`, 400, 'INVALID_INPUT');
    
    const validLanguages = ['ar', 'en'];
    if (!validLanguages.includes(language)) throw new AppError(`Unsupported language: ${language}`, 400, 'INVALID_INPUT');

    let parsedPurchase = null;
    if (purchase !== null) {
      if (typeof purchase !== 'object') throw new AppError('Invalid purchase context', 400, 'INVALID_INPUT');
      
      const { item, price, category } = purchase;
      if (!item || typeof item !== 'string' || item.trim().length === 0 || item.length > 200) {
        throw new AppError('Invalid purchase item', 400, 'INVALID_INPUT');
      }
      if (!category || typeof category !== 'string' || category.trim().length === 0 || category.length > 100) {
        throw new AppError('Invalid purchase category', 400, 'INVALID_INPUT');
      }
      
      const numPrice = Number(price);
      if (!Number.isFinite(numPrice) || numPrice <= 0) {
        throw new AppError('Invalid purchase price', 400, 'INVALID_INPUT');
      }

      parsedPurchase = {
        item: item.trim(),
        price: numPrice,
        category: category.trim()
      };
    }

    let parsedDate = null;
    if (timestamp) {
      parsedDate = new Date(timestamp);
      if (isNaN(parsedDate.getTime())) throw new AppError('Invalid timestamp', 400, 'INVALID_INPUT');
    } else {
      parsedDate = new Date();
    }

    return {
      userId: Number(userId),
      conversationId: Number(conversationId),
      requestId,
      message: msgTrimmed,
      intent,
      language,
      source,
      purchase: parsedPurchase,
      timestamp: parsedDate,
      excludeMessageId: excludeMessageId ? Number(excludeMessageId) : null
    };
  }

  /**
   * Deep validates the outgoing payload against strict rules.
   */
  static validateAIPayload(payload) {
    if (!payload || typeof payload !== 'object') throw new ChatValidationError('Payload is missing or invalid');
    
    const strPayload = JSON.stringify(payload);
    this._deepCheckValidTypes(payload);

    if (payload.schemaVersion !== '1.0') throw new ChatValidationError('Invalid schemaVersion');
    
    if (payload.transactions && payload.transactions.length > 15) throw new ChatValidationError('Transactions exceed limit');
    if (payload.conversation && payload.conversation.messages && payload.conversation.messages.length > 10) throw new ChatValidationError('Messages exceed limit');
    if (payload.goals && payload.goals.length > 10) throw new ChatValidationError('Goals exceed limit');

    return true;
  }

  /**
   * Validates N8N JSON response contract.
   */
  static validateN8nResponse(response, expectedRequestId) {
    if (!response || typeof response !== 'object') {
      throw new AppError('Invalid JSON response from provider', 502, 'CHAT_UPSTREAM_INVALID_JSON');
    }

    if (response.success !== true) {
      throw new AppError('Upstream reported failure', 502, 'CHAT_UPSTREAM_INVALID_RESPONSE');
    }

    if (!response.requestId || typeof response.requestId !== 'string' || response.requestId !== expectedRequestId) {
      throw new AppError('Upstream request ID missing or mismatched', 502, 'CHAT_UPSTREAM_REQUEST_ID_MISMATCH');
    }

    if (!response.reply || typeof response.reply !== 'string' || response.reply.trim().length === 0) {
      throw new AppError('Upstream reply missing or empty', 502, 'CHAT_UPSTREAM_INVALID_RESPONSE');
    }
    
    if (response.reply.length > 5000) {
      throw new AppError('Upstream reply oversized', 502, 'CHAT_UPSTREAM_INVALID_RESPONSE');
    }

    if (response.intent !== 'chat') {
      throw new AppError(`Unsupported intent from upstream: ${response.intent}`, 502, 'CHAT_UPSTREAM_INVALID_RESPONSE');
    }

    // Process metadata with strict allowlist
    let safeMetadata = null;
    if (response.metadata) {
      if (typeof response.metadata !== 'object' || Array.isArray(response.metadata)) {
        throw new AppError('Invalid metadata format', 502, 'CHAT_UPSTREAM_INVALID_RESPONSE');
      }

      // Check for forbidden keys that imply mutation instructions
      const forbiddenMetadata = ['action', 'actions', 'command', 'tool', 'toolCall', 'sql', 'repository', 'endpoint', 'webhook', 'financialMutation', 'transactionWrite'];
      const metaKeys = Object.keys(response.metadata);
      if (metaKeys.some(key => forbiddenMetadata.includes(key))) {
        throw new AppError('Dangerous metadata instructions detected', 502, 'CHAT_UPSTREAM_INVALID_RESPONSE');
      }

      // Extract only allowed fields
      safeMetadata = {
        primaryIntent: typeof response.metadata.primaryIntent === 'string' ? response.metadata.primaryIntent.substring(0, 100) : undefined,
        responseType: typeof response.metadata.responseType === 'string' ? response.metadata.responseType.substring(0, 100) : undefined,
        confidence: typeof response.metadata.confidence === 'number' ? response.metadata.confidence : undefined,
        responseLanguage: typeof response.metadata.responseLanguage === 'string' ? response.metadata.responseLanguage.substring(0, 10) : undefined,
      };

      if (Array.isArray(response.metadata.secondaryIntents)) {
        safeMetadata.secondaryIntents = response.metadata.secondaryIntents.filter(i => typeof i === 'string').map(i => i.substring(0, 100)).slice(0, 5);
      }

      if (Array.isArray(response.metadata.scenarios)) {
        safeMetadata.scenarios = response.metadata.scenarios.filter(i => typeof i === 'string').map(i => i.substring(0, 200)).slice(0, 3);
      }

      if (Array.isArray(response.metadata.suggestedQuestions)) {
        safeMetadata.suggestedQuestions = response.metadata.suggestedQuestions.filter(i => typeof i === 'string').map(i => i.substring(0, 200)).slice(0, 3);
      }

      if (response.metadata.followUp && typeof response.metadata.followUp === 'object') {
        safeMetadata.followUp = {
          required: Boolean(response.metadata.followUp.required),
          question: typeof response.metadata.followUp.question === 'string' ? response.metadata.followUp.question.substring(0, 200) : undefined
        };
      }
    }

    return {
      success: true,
      requestId: expectedRequestId,
      reply: response.reply,
      intent: 'chat',
      providerExecutionId: typeof response.providerExecutionId === 'string' ? response.providerExecutionId.substring(0, 100) : null,
      metadata: safeMetadata
    };
  }

  static _deepCheckValidTypes(obj, path = '') {
    if (obj === undefined) throw new ChatValidationError(`Undefined value found at ${path}`);
    if (obj === null) return;
    
    if (typeof obj === 'number') {
      if (Number.isNaN(obj)) throw new ChatValidationError(`NaN found at ${path}`);
      if (!Number.isFinite(obj)) throw new ChatValidationError(`Infinity found at ${path}`);
      if (Object.is(obj, -0)) throw new ChatValidationError(`Negative zero found at ${path}`);
    }

    if (typeof obj === 'object') {
      if (Array.isArray(obj)) {
        obj.forEach((item, index) => this._deepCheckValidTypes(item, `${path}[${index}]`));
      } else {
        for (const [key, value] of Object.entries(obj)) {
          this._deepCheckValidTypes(value, path ? `${path}.${key}` : key);
        }
      }
    }
  }
}

module.exports = { ChatValidator };
