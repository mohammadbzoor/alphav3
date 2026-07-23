const { db } = require('../config/database');
const { ChatRepository } = require('../repositories/chat.repository');
const crypto = require('crypto');

describe('ChatRepository', () => {
  let user1Id, user2Id;
  let conv1Id, conv2Id;
  let msg1Id, msg2Id, msg3Id;
  let req1Id, req1Identifier;
  
  beforeAll(async () => {
    // Setup 2 isolated users
    let [res] = await db.execute(
      `INSERT INTO users (full_name, email, phone, password_hash) VALUES (?, ?, ?, ?)`,
      ['Test User 1', `u1_${Date.now()}@test.com`, `+1${Date.now()}`, 'hash']
    );
    user1Id = res.insertId;

    [res] = await db.execute(
      `INSERT INTO users (full_name, email, phone, password_hash) VALUES (?, ?, ?, ?)`,
      ['Test User 2', `u2_${Date.now()}@test.com`, `+2${Date.now()}`, 'hash']
    );
    user2Id = res.insertId;
  });

  afterAll(async () => {
    // Clean up
    await db.execute(`DELETE FROM users WHERE id IN (?, ?)`, [user1Id, user2Id]);
  });

  // ==========================================
  // CONVERSATIONS
  // ==========================================

  it('2. Explicit conversation projections (No SELECT *)', async () => {
    conv1Id = await ChatRepository.createConversation(user1Id, { title: 'User 1 Conv' });
    const conv = await ChatRepository.findConversationByIdAndUserId(conv1Id, user1Id);
    
    expect(conv).toBeDefined();
    expect(conv.id).toBe(conv1Id);
    expect(conv.user_id).toBe(user1Id);
    expect(conv).toHaveProperty('title');
    expect(conv).toHaveProperty('status');
    expect(conv).toHaveProperty('language');
    expect(conv).toHaveProperty('channel');
    expect(conv).toHaveProperty('started_at');
    expect(conv).toHaveProperty('last_message_at');
    expect(conv).toHaveProperty('created_at');
    expect(conv).toHaveProperty('updated_at');
    
    // Ensure it doesn't return anything else (like non-existent 'random_col')
    expect(Object.keys(conv).length).toBe(10);
  });

  it('6. Conversation ownership enforcement', async () => {
    // User 2 cannot access User 1's conversation
    const conv = await ChatRepository.findConversationByIdAndUserId(conv1Id, user2Id);
    expect(conv).toBeNull();
  });

  it('9. Cross-user conversation updates are prevented', async () => {
    const success = await ChatRepository.updateConversationLastMessageAt(conv1Id, user2Id, new Date());
    expect(success).toBe(false); // No rows updated
  });

  it('10. Cross-user conversation closure is prevented', async () => {
    const success = await ChatRepository.closeConversation(conv1Id, user2Id);
    expect(success).toBe(false);
  });

  it('11. Conversation limit maximum is enforced (50)', async () => {
    conv2Id = await ChatRepository.createConversation(user2Id, { title: 'User 2 Conv' });
    await expect(ChatRepository.listUserConversations(user1Id, { limit: 9999 })).rejects.toThrow(/Invalid limit/);
  });

  it('13, 14, 15, 16. Invalid limits and offsets are explicitly rejected without coercion', async () => {
    const invalidLimits = [-5, 0, 1.5, NaN, Infinity, '10abc', '', [], {}, true, false];
    for (const val of invalidLimits) {
      await expect(ChatRepository.listUserConversations(user1Id, { limit: val }))
        .rejects.toThrow(/Invalid limit/);
    }
    const invalidOffsets = [-1, 1.5, NaN, Infinity, '10abc', '', [], {}, true, false];
    for (const val of invalidOffsets) {
      await expect(ChatRepository.listUserConversations(user1Id, { offset: val }))
        .rejects.toThrow(/Invalid offset/);
    }
  });

  it('17. Deterministic conversation ordering', async () => {
    const conv1b = await ChatRepository.createConversation(user1Id, { title: 'User 1 Conv B' });
    const list = await ChatRepository.listUserConversations(user1Id, { limit: 10 });
    expect(list[0].id).toBe(conv1b);
    expect(list[1].id).toBe(conv1Id);
  });

  it('37. last_message_at cannot move backward', async () => {
    const newTime = new Date('2030-01-01T00:00:00Z');
    await ChatRepository.updateConversationLastMessageAt(conv1Id, user1Id, newTime);
    let conv = await ChatRepository.findConversationByIdAndUserId(conv1Id, user1Id);
    expect(conv.last_message_at.getTime()).toBe(newTime.getTime());

    const oldTime = new Date('2020-01-01T00:00:00Z');
    await ChatRepository.updateConversationLastMessageAt(conv1Id, user1Id, oldTime);
    conv = await ChatRepository.findConversationByIdAndUserId(conv1Id, user1Id);
    expect(conv.last_message_at.getTime()).toBe(newTime.getTime());
  });

  // ==========================================
  // MESSAGES
  // ==========================================

  it('3. Explicit message projections (No SELECT * or metadata by default)', async () => {
    msg1Id = await ChatRepository.createMessage(conv1Id, { role: 'user', content: 'hello', metadata: { foo: 'bar' } });
    const messages = await ChatRepository.getConversationMessages(conv1Id, user1Id);
    expect(messages.length).toBe(1);
    const msg = messages[0];
    expect(msg.id).toBe(msg1Id);
    expect(msg).toHaveProperty('conversation_id');
    expect(msg).toHaveProperty('role');
    expect(msg).toHaveProperty('content');
    expect(msg).toHaveProperty('intent');
    expect(msg).toHaveProperty('status');
    expect(msg).toHaveProperty('created_at');
    expect(msg).not.toHaveProperty('metadata');
    expect(Object.keys(msg).length).toBe(7);
  });

  it('7. Message ownership enforcement in SQL', async () => {
    msg2Id = await ChatRepository.createMessage(conv1Id, { role: 'assistant', content: 'hi' });
    const messages = await ChatRepository.getConversationMessages(conv1Id, user2Id);
    expect(messages.length).toBe(0);
  });

  it('8. Cross-user message reads prevented', async () => {
    const recent = await ChatRepository.getRecentConversationMessages(conv1Id, user2Id, 10);
    expect(recent.length).toBe(0);
  });

  it('18. Deterministic message ordering when timestamps match', async () => {
    const messages = await ChatRepository.getConversationMessages(conv1Id, user1Id);
    expect(messages.length).toBe(2);
    expect(messages[0].id).toBe(msg1Id);
    expect(messages[1].id).toBe(msg2Id);
  });

  it('19. Recent messages are returned chronologically', async () => {
    msg3Id = await ChatRepository.createMessage(conv1Id, { role: 'user', content: 'third' });
    const recent = await ChatRepository.getRecentConversationMessages(conv1Id, user1Id, 2);
    expect(recent.length).toBe(2);
    expect(recent[0].id).toBe(msg2Id);
    expect(recent[1].id).toBe(msg3Id);
  });

  // ==========================================
  // REQUESTS & REDACTION
  // ==========================================

  it('24, 27. Default request payload is redacted and nested secrets removed', async () => {
    delete process.env.CHAT_STORE_FULL_PAYLOAD;

    req1Identifier = crypto.randomUUID();
    const sensitivePayload = {
      schemaVersion: '1.0',
      requestIdentifier: req1Identifier,
      conversationId: conv1Id,
      secretToken: 'shhh',
      financialData: { balance: 1000 }
    };

    req1Id = await ChatRepository.createChatRequest({
      conversationId: conv1Id,
      userId: user1Id,
      userMessageId: msg1Id,
      requestIdentifier: req1Identifier,
      requestPayload: sensitivePayload
    });

    const req = await ChatRepository.findChatRequestWithPayloadByIdentifier(req1Identifier);
    expect(req.request_payload.schemaVersion).toBe('1.0');
    expect(req.request_payload.secretToken).toBeUndefined();
    expect(req.request_payload.financialData).toBeUndefined();
    expect(req.request_payload.redacted).toBe(true);
  });

  it('31. JSON is not double encoded', async () => {
    const req = await ChatRepository.findChatRequestWithPayloadByIdentifier(req1Identifier);
    expect(typeof req.request_payload).toBe('object');
    expect(req.request_payload).not.toBeNull();
  });

  it('4. Normal request lookup excludes request_payload', async () => {
    const req = await ChatRepository.findChatRequestByIdentifier(req1Identifier);
    expect(req).toBeDefined();
    expect(req).not.toHaveProperty('request_payload');
    expect(req).not.toHaveProperty('response_payload');
  });

  it('35, 36. Valid and invalid request status transitions', async () => {
    // pending -> processing
    let success = await ChatRepository.setChatRequestProcessingInternal(req1Id);
    expect(success).toBe(true);

    // pending -> processing rejected if already processing
    success = await ChatRepository.setChatRequestProcessingInternal(req1Id);
    expect(success).toBe(false);

    // processing -> completed
    success = await ChatRepository.completeChatRequestInternal(req1Id, {
      assistantMessageId: msg2Id
    });
    expect(success).toBe(true);

    let req = await ChatRepository.findChatRequestByIdentifier(req1Identifier);
    expect(req.status).toBe('completed');

    // completed -> processing rejected
    success = await ChatRepository.setChatRequestProcessingInternal(req1Id);
    expect(success).toBe(false);

    // completed -> failed rejected
    success = await ChatRepository.failChatRequestInternal(req1Id);
    expect(success).toBe(false);

    // failed -> processing via generic method rejected
    const failedReqIdentifier = crypto.randomUUID();
    const failedReqId = await ChatRepository.createChatRequest({
      conversationId: conv1Id,
      userId: user1Id,
      requestIdentifier: failedReqIdentifier,
      status: 'failed'
    });
    success = await ChatRepository.setChatRequestProcessingInternal(failedReqId);
    expect(success).toBe(false);

    // failed -> processing via retry allowed
    success = await ChatRepository.retryChatRequestInternal(failedReqId);
    expect(success).toBe(true);

    req = await ChatRepository.findChatRequestByIdentifier(failedReqIdentifier);
    expect(req.status).toBe('processing');
    expect(req.retry_count).toBe(1);
    
    // processing -> failed allowed
    success = await ChatRepository.failChatRequestInternal(failedReqId);
    expect(success).toBe(true);
  });

  it('25, 28. Default response payload is redacted', async () => {
    const req2IdStr = crypto.randomUUID();
    const req2Id = await ChatRepository.createChatRequest({
      conversationId: conv1Id,
      userId: user1Id,
      requestIdentifier: req2IdStr
    });

    await ChatRepository.setChatRequestProcessingInternal(req2Id);

    const sensitiveRes = {
      success: true,
      requestIdentifier: req2IdStr,
      secretKeys: ['a', 'b'],
      financialState: 'good'
    };

    await ChatRepository.completeChatRequestInternal(req2Id, { responsePayload: sensitiveRes });

    const req = await ChatRepository.findChatRequestWithPayloadByIdentifier(req2IdStr);
    expect(req.response_payload.success).toBe(true);
    expect(req.response_payload.secretKeys).toBeUndefined();
    expect(req.response_payload.financialState).toBeUndefined();
    expect(req.response_payload.redacted).toBe(true);
  });

  it('26. Full storage is enabled only by exact lowercase "true"', async () => {
    process.env.CHAT_STORE_FULL_PAYLOAD = 'TRUE'; // Uppercase
    const req3IdStr = crypto.randomUUID();
    await ChatRepository.createChatRequest({
      conversationId: conv1Id,
      userId: user1Id,
      requestIdentifier: req3IdStr,
      requestPayload: { secret: 1 }
    });
    let req = await ChatRepository.findChatRequestWithPayloadByIdentifier(req3IdStr);
    expect(req.request_payload.secret).toBeUndefined();

    process.env.CHAT_STORE_FULL_PAYLOAD = 'true'; // exact lowercase
    const req4IdStr = crypto.randomUUID();
    await ChatRepository.createChatRequest({
      conversationId: conv1Id,
      userId: user1Id,
      requestIdentifier: req4IdStr,
      requestPayload: { secret: 1 }
    });
    req = await ChatRepository.findChatRequestWithPayloadByIdentifier(req4IdStr);
    expect(req.request_payload.secret).toBe(1); // full payload stored

    // cleanup
    delete process.env.CHAT_STORE_FULL_PAYLOAD;
  });

  it('33, 34. Atomic retry increment with overflow protection', async () => {
    // Manually push to 255 (TINYINT MAX) and fail it
    await db.execute(`UPDATE chat_requests SET retry_count = 255, status = 'failed' WHERE id = ?`, [req1Id]);
    
    // Increment again should fail due to overflow protection
    const success = await ChatRepository.retryChatRequestInternal(req1Id);
    expect(success).toBe(false);
  });

  it('20. Duplicate request identifier is rejected', async () => {
    await expect(ChatRepository.createChatRequest({
      conversationId: conv1Id,
      userId: user1Id,
      requestIdentifier: req1Identifier
    })).rejects.toThrow(/Duplicate entry/);
  });

  // ==========================================
  // TRANSACTIONS
  // ==========================================

  it('38. Repository methods work with an injected transaction connection (commit/rollback proof)', async () => {
    const conn = await db.getConnection();
    
    // Test Rollback
    await conn.beginTransaction();
    const rollbackConvId = await ChatRepository.createConversation(user1Id, { title: 'Rollback Conv' }, conn);
    expect(rollbackConvId).toBeDefined();
    let c = await ChatRepository.findConversationByIdAndUserId(rollbackConvId, user1Id, conn);
    expect(c).toBeDefined(); // visible within transaction
    await conn.rollback();
    c = await ChatRepository.findConversationByIdAndUserId(rollbackConvId, user1Id);
    expect(c).toBeNull(); // gone after rollback

    // Test Commit
    await conn.beginTransaction();
    const commitConvId = await ChatRepository.createConversation(user1Id, { title: 'Commit Conv' }, conn);
    await conn.commit();
    c = await ChatRepository.findConversationByIdAndUserId(commitConvId, user1Id);
    expect(c).toBeDefined(); // visible after commit

    conn.release();
  });

  // ==========================================
  // CASCADES & NULLIFY
  // ==========================================

  it('21, 22. Linked user_message_id and assistant_message_id become NULL after message deletion', async () => {
    // Delete the messages linked to req1Id (msg1Id and msg2Id)
    await db.execute(`DELETE FROM chat_messages WHERE id IN (?, ?)`, [msg1Id, msg2Id]);

    const req = await ChatRepository.findChatRequestByIdentifier(req1Identifier);
    expect(req.user_message_id).toBeNull();
    expect(req.assistant_message_id).toBeNull();
  });

  it('23. Conversation deletion cascades correctly', async () => {
    await db.execute(`DELETE FROM chat_conversations WHERE id = ?`, [conv1Id]);

    const [reqs] = await db.execute(`SELECT id FROM chat_requests WHERE conversation_id = ?`, [conv1Id]);
    expect(reqs.length).toBe(0);

    const [msgs] = await db.execute(`SELECT id FROM chat_messages WHERE conversation_id = ?`, [conv1Id]);
    expect(msgs.length).toBe(0);
  });
});
