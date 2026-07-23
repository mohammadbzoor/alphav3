
const { N8nChatClientService } = require('../services/n8n_chat_client.service');
const { AppError } = require('../utils/app-error');

describe('N8nChatClientService', () => {
  let mockHttpClient;
  let service;

  beforeEach(() => {
    process.env.N8N_CHAT_WEBHOOK_URL = 'http://localhost:9999/webhook/chat';
    process.env.N8N_CHAT_TIMEOUT_MS = '15000';
    process.env.N8N_CHAT_MAX_RETRIES = '1';
    process.env.CHAT_STORE_FULL_PAYLOAD = 'false';

    mockHttpClient = {
      post: vi.fn()
    };
    service = new N8nChatClientService(mockHttpClient);
  });

  const validPayload = {
    request: { id: '12345678-1234-1234-1234-123456789012' },
    conversationId: 1
  };

  it('performs one successful HTTP request and returns safe response', async () => {
    mockHttpClient.post.mockResolvedValueOnce({
      status: 200,
      data: {
        success: true,
        requestId: validPayload.request.id,
        reply: 'Hello',
        intent: 'chat'
      }
    });

    const result = await service.sendToWebhook(validPayload);
    
    expect(mockHttpClient.post).toHaveBeenCalledTimes(1);
    expect(mockHttpClient.post).toHaveBeenCalledWith(
      'http://localhost:9999/webhook/chat',
      validPayload,
      expect.objectContaining({
        headers: expect.objectContaining({
          'X-Request-ID': validPayload.request.id,
          'Idempotency-Key': validPayload.request.id
        }),
        timeout: 15000
      })
    );
    expect(result.httpStatus).toBe(200);
    expect(result.safeResponse.reply).toBe('Hello');
  });

  it('throws CHAT_UPSTREAM_TIMEOUT on ECONNABORTED', async () => {
    mockHttpClient.post.mockRejectedValueOnce({ code: 'ECONNABORTED' });
    await expect(service.sendToWebhook(validPayload)).rejects.toThrowError('Upstream request timed out');
  });

  it('throws CHAT_UPSTREAM_RATE_LIMITED on 429', async () => {
    mockHttpClient.post.mockRejectedValueOnce({ response: { status: 429 } });
    await expect(service.sendToWebhook(validPayload)).rejects.toThrowError('Upstream rate limited');
  });

  it('throws CHAT_UPSTREAM_CONNECTION_FAILED on connection refusal', async () => {
    mockHttpClient.post.mockRejectedValueOnce({ code: 'ECONNREFUSED' });
    await expect(service.sendToWebhook(validPayload)).rejects.toThrowError('Upstream connection failed');
  });

  it('throws CHAT_UPSTREAM_CLIENT_ERROR on 400', async () => {
    mockHttpClient.post.mockRejectedValueOnce({ response: { status: 400 } });
    await expect(service.sendToWebhook(validPayload)).rejects.toThrowError('Upstream client error: 400');
  });

  it('throws CHAT_UPSTREAM_SERVER_ERROR on 500', async () => {
    mockHttpClient.post.mockRejectedValueOnce({ response: { status: 500 } });
    await expect(service.sendToWebhook(validPayload)).rejects.toThrowError('Upstream server error: 500');
  });
});