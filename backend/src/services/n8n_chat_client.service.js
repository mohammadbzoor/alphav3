const axios = require('axios');
const { ChatValidator } = require('../utils/chat_validator.util');
const { AppError } = require('../utils/app-error');

class N8nChatClientService {
  constructor(httpClient = null) {
    // Allows dependency injection for tests
    this.httpClient = httpClient || axios.create();
  }

  /**
   * Sends the validated payload to the N8N webhook.
   * Performs exactly one HTTP attempt (retries are orchestrated by ChatService).
   */
  async sendToWebhook(payload) {
    const config = ChatValidator.validateConfig();
    const { webhookUrl, timeoutMs } = config;

    // TEST GUARD: Prevent real webhook calls during automated tests
    if (process.env.NODE_ENV === 'test' && webhookUrl.includes('mohammadn8n.cfd')) {
      throw new Error('TEST GUARD: Real n8n webhook URL used in test environment!');
    }

    const startTime = Date.now();
    let response;

    try {
      response = await this.httpClient.post(webhookUrl, payload, {
        timeout: timeoutMs,
        headers: {
          'Content-Type': 'application/json',
          'X-Request-ID': payload.request.id,
          'Idempotency-Key': payload.request.id,
        },
        maxRedirects: 0, // Do not allow redirects
      });
    } catch (error) {
      const durationMs = Date.now() - startTime;
      
      if (error.code === 'ECONNABORTED' || (error.message && error.message.includes('timeout'))) {
        throw new AppError('Upstream request timed out', 504, 'CHAT_UPSTREAM_TIMEOUT');
      }

      if (error.response) {
        // HTTP status failures
        const status = error.response.status;
        if (status === 429) {
          throw new AppError('Upstream rate limited', 429, 'CHAT_UPSTREAM_RATE_LIMITED');
        } else if (status >= 400 && status < 500) {
          throw new AppError(`Upstream client error: ${status}`, status, 'CHAT_UPSTREAM_CLIENT_ERROR');
        } else if (status >= 500) {
          throw new AppError(`Upstream server error: ${status}`, status, 'CHAT_UPSTREAM_SERVER_ERROR');
        }
      }

      // Connection failures (ECONNREFUSED, ENOTFOUND, etc.)
      throw new AppError('Upstream connection failed', 502, 'CHAT_UPSTREAM_CONNECTION_FAILED');
    }

    const durationMs = Date.now() - startTime;
    
    // Response validation
    const safeResponse = ChatValidator.validateN8nResponse(response.data, payload.request.id);
    
    return {
      safeResponse,
      httpStatus: response.status,
      durationMs
    };
  }
}

module.exports = { N8nChatClientService };
