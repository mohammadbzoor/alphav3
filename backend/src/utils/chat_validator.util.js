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
   * Validates the input given to ChatContextService.
   */
  static validateChatContextInput(input) {
    if (!input || typeof input !== 'object') {
      throw new AppError('Invalid chat context input', 400, 'INVALID_INPUT');
    }

    const { userId, conversationId, requestId, message, intent = 'chat', language = 'ar', source = 'mobile', purchase = null, timestamp } = input;

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
      timestamp: parsedDate
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
