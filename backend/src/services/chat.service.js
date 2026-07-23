const crypto = require('crypto');
const { db } = require('../config/database');
const { ChatRepository } = require('../repositories/chat.repository');
const { ChatContextService } = require('./chat_context.service');
const { N8nChatClientService } = require('./n8n_chat_client.service');
const { ChatValidator } = require('../utils/chat_validator.util');
const { AppError } = require('../utils/app-error');

class ChatService {
  /**
   * Processes a new user chat message, coordinates context gathering, 
   * communicates with N8N, and persists the response.
   */
  static async processUserMessage(userId, inputBody) {
    // 1. Strict input validation
    ChatValidator.validateIncomingRequest(inputBody);
    
    let { conversationId, message, intent = 'chat', language = 'ar', context: inputContext } = inputBody;
    const purchase = inputContext?.purchase || null;
    
    // Generate UUID
    const requestId = crypto.randomUUID();

    // 2. Local Preparation Transaction
    let conn = await db.getConnection();
    let userMessageId = null;
    let chatRequestId = null;

    try {
      await conn.beginTransaction();

      if (!conversationId) {
        conversationId = await ChatRepository.createConversation(userId, { language }, conn);
      } else {
        const conv = await ChatRepository.findConversationByIdAndUserId(conversationId, userId, conn);
        if (!conv) {
          throw new AppError('Conversation not found', 404, 'NOT_FOUND');
        }
        if (conv.status === 'closed' || conv.status === 'archived') {
          throw new AppError(`Cannot send message to ${conv.status} conversation`, 403, 'CONVERSATION_CLOSED');
        }
      }

      userMessageId = await ChatRepository.createMessage(conversationId, {
        role: 'user',
        content: message,
        intent,
        status: 'pending'
      }, conn);

      chatRequestId = await ChatRepository.createChatRequest({
        conversationId,
        userId,
        userMessageId,
        requestIdentifier: requestId,
        provider: 'n8n',
        status: 'pending'
      }, conn);

      await ChatRepository.updateConversationLastMessageAt(conversationId, userId, new Date(), conn);

      await conn.commit();
    } catch (error) {
      await conn.rollback();
      throw error;
    } finally {
      conn.release();
    }

    // 3. Build Context
    let aiPayload;
    try {
      aiPayload = await ChatContextService.buildChatPayload({
        userId,
        conversationId,
        requestId,
        message,
        intent,
        language,
        source: 'mobile',
        purchase,
        timestamp: new Date(),
        excludeMessageId: userMessageId
      });
      ChatValidator.validateAIPayload(aiPayload);
    } catch (error) {
      console.error('CONTEXT BUILD ERROR:', error);
      await ChatRepository.failChatRequestInternal(chatRequestId, { errorMessage: 'CHAT_CONTEXT_BUILD_FAILED' });
      await ChatRepository.updateMessageStatus(userMessageId, 'failed');
      throw new AppError('Failed to build chat context', 500, 'CHAT_CONTEXT_BUILD_FAILED');
    }

    // 4. Send to N8N with bounded retries
    await ChatRepository.setChatRequestProcessingInternal(chatRequestId);

    const config = ChatValidator.validateConfig();
    const maxRetries = config.maxRetries;
    const n8nClient = new N8nChatClientService();
    
    let attempt = 0;
    let n8nResult = null;
    let transportError = null;

    while (attempt <= maxRetries) {
      try {
        n8nResult = await n8nClient.sendToWebhook(aiPayload);
        transportError = null;
        break; // Success
      } catch (error) {
        transportError = error;
        
        // Transient errors that can be retried
        const isTransient = 
          error.code === 'CHAT_UPSTREAM_TIMEOUT' || 
          error.code === 'CHAT_UPSTREAM_CONNECTION_FAILED' ||
          (error.statusCode && [502, 503, 504].includes(error.statusCode));
          
        if (isTransient && attempt < maxRetries) {
          // Attempt retry
          await new Promise(resolve => setTimeout(resolve, 500)); // Small bounded delay
          const retrySuccess = await ChatRepository.retryChatRequestInternal(chatRequestId);
          if (!retrySuccess) {
            break; // State mismatch or max retry reached in DB
          }
          attempt++;
        } else {
          break; // Non-transient or max retries reached
        }
      }
    }

    if (transportError) {
      await ChatRepository.failChatRequestInternal(chatRequestId, { 
        errorMessage: transportError.code || 'CHAT_UPSTREAM_SERVER_ERROR',
        httpStatus: transportError.statusCode
      });
      await ChatRepository.updateMessageStatus(userMessageId, 'failed');
      
      // Return safe failure to client
      throw new AppError(
        'تعذر الحصول على الرد حاليًا، يرجى المحاولة لاحقًا.', 
        503, 
        'CHAT_SERVICE_UNAVAILABLE'
      );
    }

    // 5. Success Persistence Transaction
    const { safeResponse, httpStatus, durationMs } = n8nResult;
    conn = await db.getConnection();
    let assistantMessageId = null;

    try {
      await conn.beginTransaction();

      // Lock or conditionally update request to prevent duplicates
      // completeChatRequestInternal only updates if status is 'processing'
      const completed = await ChatRepository.completeChatRequestInternal(chatRequestId, {
        httpStatus,
        durationMs,
        responsePayload: safeResponse // Repository redacts based on env
      }, conn);

      if (!completed) {
        // Either already completed, failed, or we hit a race condition
        throw new Error('Duplicate completion detected or request not in processing state');
      }

      // Create assistant message
      assistantMessageId = await ChatRepository.createMessage(conversationId, {
        role: 'assistant',
        content: safeResponse.reply,
        intent: safeResponse.intent,
        status: 'completed',
        metadata: safeResponse.metadata
      }, conn);

      // Link assistant message to request
      await conn.execute(
        `UPDATE chat_requests SET assistant_message_id = ? WHERE id = ?`,
        [assistantMessageId, chatRequestId]
      );

      // Mark user message completed
      await ChatRepository.updateMessageStatus(userMessageId, 'completed', conn);

      // Update conversation timestamp
      await ChatRepository.updateConversationLastMessageAt(conversationId, userId, new Date(), conn);

      await conn.commit();
    } catch (error) {
      await conn.rollback();
      // If we failed here, we do NOT blindly resubmit.
      // The transport succeeded, but our persistence failed.
      await ChatRepository.failChatRequestInternal(chatRequestId, { errorMessage: 'CHAT_RESPONSE_PERSISTENCE_FAILED' });
      await ChatRepository.updateMessageStatus(userMessageId, 'failed');
      throw new AppError('تعذر حفظ الرد، يرجى المحاولة لاحقًا.', 500, 'CHAT_SERVICE_UNAVAILABLE');
    } finally {
      conn.release();
    }

    // 6. API Success Response
    // Fetch the stored message for exact timestamp
    const storedAssistantMsg = await ChatRepository.findMessageById(assistantMessageId);

    return {
      success: true,
      requestId,
      conversationId,
      message: {
        id: assistantMessageId,
        role: 'assistant',
        content: safeResponse.reply,
        timestamp: storedAssistantMsg.created_at,
        metadata: safeResponse.metadata
      }
    };
  }
}

module.exports = { ChatService };
