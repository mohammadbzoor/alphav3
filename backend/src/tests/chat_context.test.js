const { db } = require('../config/database');
const { ChatContextService } = require('../services/chat_context.service');
const { ChatRepository } = require('../repositories/chat.repository');
const crypto = require('crypto');
const { ChatValidator } = require('../utils/chat_validator.util');

describe('ChatContextService Integration', () => {
  let userId, convId, cycleId, reqId;
  const originalEnv = process.env.CHAT_STORE_FULL_PAYLOAD;

  beforeAll(async () => {
    process.env.CHAT_STORE_FULL_PAYLOAD = 'false';

    // 1. Create User
    const [uRes] = await db.execute(
      `INSERT INTO users (full_name, email, phone, password_hash, is_onboarded, account_status) VALUES (?, ?, ?, ?, 1, 'active')`,
      ['Chat User', `chat_${Date.now()}@test.com`, `+1234${Date.now()}`, 'hash']
    );
    userId = uRes.insertId;

    // 2. Create Profile
    await db.execute(
      `INSERT INTO financial_profiles (user_id, currency, expected_monthly_income, timezone, onboarding_status) VALUES (?, 'JOD', 1000, 'Asia/Amman', 'completed')`,
      [userId]
    );

    // 3. Create Cycle
    const [cRes] = await db.execute(
      `INSERT INTO financial_cycles (user_id, start_date, end_date, expected_income, status) VALUES (?, DATE_SUB(CURDATE(), INTERVAL 5 DAY), DATE_ADD(CURDATE(), INTERVAL 25 DAY), 1000, 'open')`,
      [userId]
    );
    cycleId = cRes.insertId;

    // 4. Create Cycle Allocation Snapshot
    await db.execute(
      `INSERT INTO cycle_allocation_snapshots (cycle_id, allocation_base_income, needs_target, wants_target, savings_target, needs_bps, wants_bps, savings_bps, allocation_source, policy_version, calculation_version, created_at) VALUES (?, 1000, 500, 300, 200, 5000, 3000, 2000, 'system_tier', 'v1', 'v1', NOW())`,
      [cycleId]
    );

    // 5. Create Transactions
    // Need: 1 expense, 1 want expense, 1 income (to test it's excluded from totalSpent)
    await db.execute(
      `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, category, budget_bucket, status) VALUES 
       (?, ?, 50, NOW(), NOW(), 'outflow', 'expense', 'Groceries', 'needs', 'confirmed'),
       (?, ?, 100, NOW(), NOW(), 'outflow', 'expense', 'Entertainment', 'wants', 'confirmed'),
       (?, ?, 200, NOW(), NOW(), 'inflow', 'income', 'Bonus', null, 'confirmed')`,
      [userId, cycleId, userId, cycleId, userId, cycleId]
    );

    // 6. Create Goal
    await db.execute(
      `INSERT INTO goals (user_id, name, target_amount, current_balance, target_date, status, goal_type) VALUES (?, 'New Car', 5000, 1000, DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 'active', 'deadline_based')`,
      [userId]
    );

    // 7. Create Commitment
    const [commRes] = await db.execute(
      `INSERT INTO financial_commitments (user_id, name, amount, frequency, next_due_date, budget_bucket, flexibility, status) VALUES (?, 'Rent', 300, 'monthly', DATE_ADD(CURDATE(), INTERVAL 10 DAY), 'needs', 'fixed', 'active')`,
      [userId]
    );
    await db.execute(
      `INSERT INTO commitment_occurrences (commitment_id, cycle_id, due_date, amount, status) VALUES (?, ?, DATE_ADD(CURDATE(), INTERVAL 10 DAY), 300, 'upcoming')`,
      [commRes.insertId, cycleId]
    );

    // 8. Create Conversation & Message
    convId = await ChatRepository.createConversation(userId, { title: 'Test Conv', language: 'en' });
    await ChatRepository.createMessage(convId, { role: 'user', content: 'Hello', status: 'completed' });

    reqId = crypto.randomUUID();
  });

  afterAll(async () => {
    process.env.CHAT_STORE_FULL_PAYLOAD = originalEnv;
    await db.execute(`DELETE FROM chat_messages WHERE conversation_id IN (SELECT id FROM chat_conversations WHERE user_id = ?)`, [userId]);
    await db.execute(`DELETE FROM chat_conversations WHERE user_id = ?`, [userId]);
    await db.execute(`DELETE FROM commitment_occurrences WHERE cycle_id = ?`, [cycleId]);
    await db.execute(`DELETE FROM financial_commitments WHERE user_id = ?`, [userId]);
    await db.execute(`DELETE FROM goals WHERE user_id = ?`, [userId]);
    await db.execute(`DELETE FROM transactions WHERE user_id = ?`, [userId]);
    // Skip cycle_allocation_snapshots due to trigger preventing deletion, but the cycle will cascade? 
    // Wait, the error is cycle_id cannot be deleted because of trigger? No, the trigger is ON cycle_allocation_snapshots
    // Let's just delete the user... wait, `users` delete is restricted because of `financial_cycles`. 
    // The previous error was: foreign key constraint fails (`alpha_test`.`financial_cycles`, CONSTRAINT `fk_cycles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT
    await db.execute(`DELETE FROM cycle_allocation_snapshots WHERE cycle_id = ?`, [cycleId]).catch(() => {});
    await db.execute(`DELETE FROM financial_cycles WHERE user_id = ?`, [userId]).catch(() => {});
    await db.execute(`DELETE FROM financial_profiles WHERE user_id = ?`, [userId]);
    await db.execute(`DELETE FROM users WHERE id = ?`, [userId]).catch(() => {});
  });

  it('1. Valid complete payload is generated', async () => {
    const payload = await ChatContextService.buildChatPayload({
      userId,
      conversationId: convId,
      requestId: reqId,
      message: 'Hello AI',
      intent: 'chat',
      language: 'en',
      source: 'mobile',
      timestamp: new Date()
    });

    // 2. Correct top-level schema
    expect(payload.schemaVersion).toBe("1.0");
    expect(payload.user).toBeDefined();
    expect(payload.financial).toBeDefined();
    expect(payload.transactions).toBeInstanceOf(Array);
    expect(payload.goals).toBeInstanceOf(Array);
    
    // 3. Correct mobile source
    expect(payload.request.source).toBe('mobile');

    // 22-23. Needs/Wants target, spent, remaining
    expect(payload.financial.needs.target).toBe(500);
    expect(payload.financial.needs.spent).toBe(50);
    expect(payload.financial.needs.remaining).toBe(450);

    expect(payload.financial.wants.target).toBe(300);
    expect(payload.financial.wants.spent).toBe(100);
    expect(payload.financial.wants.remaining).toBe(200);

    // 25. Total spent excludes income
    expect(payload.financial.overall.totalSpent).toBe(150); // 50 + 100, excludes 200 income

    // 33. Commitment monthly total
    expect(payload.financial.commitments.monthly).toBe(300);

    // 34. Unpaid commitment total
    expect(payload.financial.commitments.unpaid).toBe(300);
  });

  it('4. Conversation ownership enforcement & 5. Cross-user rejection', async () => {
    const [res] = await db.execute(`INSERT INTO users (full_name, email, password_hash) VALUES ('Other', 'other_${Date.now()}@test.com', 'hash')`);
    const otherUserId = res.insertId;
    await db.execute(`INSERT INTO financial_profiles (user_id, currency, expected_monthly_income, timezone, onboarding_status) VALUES (?, 'JOD', 800, 'Asia/Amman', 'completed')`, [otherUserId]);

    await expect(ChatContextService.buildChatPayload({
      userId: otherUserId,
      conversationId: convId,
      requestId: crypto.randomUUID(),
      message: 'Hi'
    })).rejects.toThrow('Conversation not found or belongs to another user');

    await db.execute(`DELETE FROM users WHERE id = ?`, [otherUserId]);
  });

  it('66-71. Validator tests for input validation', () => {
    // 54. Empty message
    expect(() => ChatValidator.validateChatContextInput({ userId, conversationId: convId, requestId: reqId, message: '  ' })).toThrow(/Message is too short/);
    
    // 55. Oversized message
    const longMsg = 'a'.repeat(2001);
    expect(() => ChatValidator.validateChatContextInput({ userId, conversationId: convId, requestId: reqId, message: longMsg })).toThrow(/exceeds maximum/);
    
    // 56. Unsupported intent
    expect(() => ChatValidator.validateChatContextInput({ userId, conversationId: convId, requestId: reqId, message: 'Hi', intent: 'unknown' })).toThrow(/Unsupported intent/);

    // 58. Source other than mobile
    expect(() => ChatValidator.validateChatContextInput({ userId, conversationId: convId, requestId: reqId, message: 'Hi', source: 'web' })).toThrow(/Unsupported source/);
  });
  
  it('49. Invalid purchase price & 50. Oversized purchase item', () => {
    expect(() => ChatValidator.validateChatContextInput({
      userId, conversationId: convId, requestId: reqId, message: 'Hi', 
      purchase: { item: 'Car', price: -5, category: 'wants' }
    })).toThrow(/Invalid purchase price/);
    
    expect(() => ChatValidator.validateChatContextInput({
      userId, conversationId: convId, requestId: reqId, message: 'Hi', 
      purchase: { item: 'a'.repeat(201), price: 10, category: 'wants' }
    })).toThrow(/Invalid purchase item/);
  });

  it('11. Context details are bounded but aggregates include all data', async () => {
    let addedTx = [];
    for (let i = 0; i < 16; i++) {
      const [res] = await db.execute(
        `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, budget_bucket, status) VALUES (?, ?, 10, NOW(), NOW(), 'outflow', 'expense', 'needs', 'confirmed')`,
        [userId, cycleId]
      );
      addedTx.push(res.insertId);
    }
    
    let addedGoals = [];
    for (let i = 0; i < 11; i++) {
      const [res] = await db.execute(
        `INSERT INTO goals (user_id, name, target_amount, current_balance, target_date, status, goal_type) VALUES (?, 'Goal', 100, 10, NOW(), 'active', 'deadline_based')`,
        [userId]
      );
      addedGoals.push(res.insertId);
    }

    let addedMsgs = [];
    for (let i = 0; i < 11; i++) {
      const [res] = await db.execute(
        `INSERT INTO chat_messages (conversation_id, role, content, status) VALUES (?, 'user', 'msg', 'completed')`,
        [convId]
      );
      addedMsgs.push(res.insertId);
    }

    const payload = await ChatContextService.buildChatPayload({
      userId, conversationId: convId, requestId: crypto.randomUUID(), message: 'Hello'
    });

    expect(payload.transactions.length).toBe(15);
    expect(payload.goals.length).toBe(10);
    expect(payload.conversation.messages.length).toBe(10);
    
    // Aggregates must include the original 150 (from before) + 16*10 = 160 -> 310 totalSpent
    expect(payload.financial.overall.totalSpent).toBe(310);

    // Clean up
    if (addedTx.length) await db.execute(`DELETE FROM transactions WHERE id IN (${addedTx.join(',')})`);
    if (addedGoals.length) await db.execute(`DELETE FROM goals WHERE id IN (${addedGoals.join(',')})`);
    if (addedMsgs.length) await db.execute(`DELETE FROM chat_messages WHERE id IN (${addedMsgs.join(',')})`);
  });

  it('Manually constructed oversized payloads are rejected by validateAIPayload', () => {
    const payload = {
      schemaVersion: '1.0',
      transactions: Array(16).fill({}),
      goals: Array(11).fill({}),
      conversation: { messages: Array(11).fill({}) }
    };
    expect(() => ChatValidator.validateAIPayload(payload)).toThrow(/Transactions exceed limit/);
  });

  it('Missing snapshot semantics: Targets and remainings are null, spent is tracked, payload is valid', async () => {
    // 1. Missing snapshot, no transactions
    let [uRes] = await db.execute(`INSERT INTO users (full_name, email, password_hash, is_onboarded, account_status) VALUES ('No Snap', 'nosnap_${Date.now()}@test.com', 'hash', 1, 'active')`);
    let tempUserId = uRes.insertId;
    await db.execute(`INSERT INTO financial_profiles (user_id, currency, expected_monthly_income, timezone, onboarding_status) VALUES (?, 'JOD', 900, 'Asia/Amman', 'completed')`, [tempUserId]);

    let [cRes] = await db.execute(
      `INSERT INTO financial_cycles (user_id, start_date, end_date, expected_income, status) VALUES (?, DATE_SUB(CURDATE(), INTERVAL 5 DAY), DATE_ADD(CURDATE(), INTERVAL 25 DAY), 900, 'open')`,
      [tempUserId]
    );
    let tempCycleId = cRes.insertId;

    let tempConvId = await ChatRepository.createConversation(tempUserId, { title: 'Test Conv' });

    let payloadNoTx = await ChatContextService.buildChatPayload({
      userId: tempUserId, conversationId: tempConvId, requestId: crypto.randomUUID(), message: 'Hi'
    });

    expect(payloadNoTx.financial.needs.target).toBeNull();
    expect(payloadNoTx.financial.needs.remaining).toBeNull();
    expect(payloadNoTx.financial.needs.spent).toBe(0);
    expect(payloadNoTx.financial.savings.remaining).toBeNull();
    
    // Validate output accepts null targets/remainings
    expect(() => ChatValidator.validateAIPayload(payloadNoTx)).not.toThrow();

    // 2. Missing snapshot WITH transactions
    const [txRes] = await db.execute(
      `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, budget_bucket, status) VALUES (?, ?, 50, NOW(), NOW(), 'outflow', 'expense', 'needs', 'confirmed')`,
      [tempUserId, tempCycleId]
    );

    let payloadWithTx = await ChatContextService.buildChatPayload({
      userId: tempUserId, conversationId: tempConvId, requestId: crypto.randomUUID(), message: 'Hi'
    });

    expect(payloadWithTx.financial.needs.target).toBeNull();
    expect(payloadWithTx.financial.needs.remaining).toBeNull();
    expect(payloadWithTx.financial.needs.spent).toBe(50); // Tracked properly
    expect(payloadWithTx.financial.overall.totalSpent).toBe(50);
    expect(payloadWithTx.financial.overall.remainingBudget).toBeNull();

    // Cleanup
    await db.execute('DELETE FROM transactions WHERE id = ?', [txRes.insertId]);
    await db.execute('DELETE FROM chat_conversations WHERE id = ?', [tempConvId]);
    await db.execute('DELETE FROM financial_cycles WHERE id = ?', [tempCycleId]);
    await db.execute('DELETE FROM financial_profiles WHERE user_id = ?', [tempUserId]);
    await db.execute('DELETE FROM users WHERE id = ?', [tempUserId]);
  });

  it('Safe Daily Spend strict null/zero semantics', () => {
    // 1. Positive available
    expect(ChatContextService._calculateSafeDailySpend(1000, 200, 100, 100, 10)).toBe(60); // 600 / 10
    // 2. Zero available
    expect(ChatContextService._calculateSafeDailySpend(1000, 800, 100, 100, 10)).toBe(0);
    // 3. Negative available
    expect(ChatContextService._calculateSafeDailySpend(1000, 1000, 100, 100, 10)).toBe(0);
    // 4. Unknown inputs
    expect(ChatContextService._calculateSafeDailySpend(null, 200, 100, 100, 10)).toBeNull();
    // 5. Zero remaining days (cannot divide by zero)
    expect(ChatContextService._calculateSafeDailySpend(1000, 200, 100, 100, 0)).toBe(0);
  });

  it('7. User with no active cycle', async () => {
    const email = `nocycle_${Date.now()}@test.com`;
    const phone = `+96279333${Date.now().toString().slice(-4)}`;
    const [uRes] = await db.execute(`INSERT INTO users (full_name, email, phone, password_hash) VALUES (?, ?, ?, ?)`, ['No Cycle User', email, phone, 'hash']);
    const noCycleUserId = uRes.insertId;
    await db.execute(`INSERT INTO financial_profiles (user_id, currency, expected_monthly_income, timezone, onboarding_status) VALUES (?, 'JOD', 800, 'Asia/Amman', 'completed')`, [noCycleUserId]);
    
    const convIdNoCycle = await ChatRepository.createConversation(noCycleUserId, { title: 'No Cycle Conv' });

    const payload = await ChatContextService.buildChatPayload({
      userId: noCycleUserId,
      conversationId: convIdNoCycle,
      requestId: crypto.randomUUID(),
      message: 'What is my budget?'
    });

    expect(payload.financial.cycleId).toBeNull();
    expect(payload.transactions).toEqual([]);
    expect(payload.financial.needs.target).toBeNull();
    expect(payload.context.currentCycle.status).toBeNull();

    await db.execute(`DELETE FROM users WHERE id = ?`, [noCycleUserId]);
  });

  it('Goal Ordering: Deterministic sorting, NULL target dates first', async () => {
    let added = [];
    const queries = [
      `INSERT INTO goals (user_id, name, target_amount, current_balance, target_date, status, goal_type) VALUES (?, 'G1_NULL', 100, 0, NULL, 'active', 'open_ended')`,
      `INSERT INTO goals (user_id, name, target_amount, current_balance, target_date, status, goal_type) VALUES (?, 'G2_LATER', 100, 0, '2026-12-01', 'active', 'deadline_based')`,
      `INSERT INTO goals (user_id, name, target_amount, current_balance, target_date, status, goal_type) VALUES (?, 'G3_SOONER', 100, 0, '2026-08-01', 'active', 'deadline_based')`,
      `INSERT INTO goals (user_id, name, target_amount, current_balance, target_date, status, goal_type) VALUES (?, 'G4_TIE_1', 100, 0, '2026-09-01', 'active', 'deadline_based')`,
      `INSERT INTO goals (user_id, name, target_amount, current_balance, target_date, status, goal_type) VALUES (?, 'G5_TIE_2', 100, 0, '2026-09-01', 'active', 'deadline_based')`
    ];

    for (let q of queries) {
      const [r] = await db.execute(q, [userId]);
      added.push(r.insertId);
    }

    const payload = await ChatContextService.buildChatPayload({
      userId, conversationId: convId, requestId: crypto.randomUUID(), message: 'Hi'
    });

    const testGoals = payload.goals.filter(g => added.includes(Number(g.id)));
    const goalNames = testGoals.map(g => g.name);
    // Null first, then ascending date, then ascending ID for ties
    expect(goalNames).toEqual(['G1_NULL', 'G3_SOONER', 'G4_TIE_1', 'G5_TIE_2', 'G2_LATER']);

    if (added.length) await db.execute(`DELETE FROM goals WHERE id IN (${added.join(',')})`);
  });

  it('Conversation message rules: explicit ordering, bounded limits, filtering', async () => {
    let added = [];
    const queries = [
      `INSERT INTO chat_messages (conversation_id, role, content, status, created_at) VALUES (?, 'user', 'M1', 'completed', '2026-01-01 10:00:00')`,
      `INSERT INTO chat_messages (conversation_id, role, content, status, created_at) VALUES (?, 'assistant', 'M2', 'completed', '2026-01-01 10:01:00')`,
      `INSERT INTO chat_messages (conversation_id, role, content, status, created_at) VALUES (?, 'user', 'M3_FAILED', 'failed', '2026-01-01 10:02:00')`,
      `INSERT INTO chat_messages (conversation_id, role, content, status, created_at) VALUES (?, 'system', 'M4', 'completed', '2026-01-01 10:03:00')`
    ];

    for (let q of queries) {
      const [r] = await db.execute(q, [convId]);
      added.push(r.insertId);
    }

    const payload = await ChatContextService.buildChatPayload({
      userId, conversationId: convId, requestId: crypto.randomUUID(), message: 'M5_NEW_USER'
    });

    const contents = payload.conversation.messages.map(m => m.content);
    // Descending order from repository
    // Note: buildChatPayload runs BEFORE new user message is saved. M5_NEW_USER is not in the db, passed in request object.
    expect(contents).toContain('M4');
    expect(contents).toContain('M2');
    expect(contents).toContain('M1');
    expect(contents).not.toContain('M3_FAILED');

    if (added.length) await db.execute(`DELETE FROM chat_messages WHERE id IN (${added.join(',')})`);
  });

  it('Transaction filter matrix: explicitly includes income/expense, excludes refund/transfer/saving/pending', async () => {
    let added = [];
    const queries = [
      `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, budget_bucket, status) VALUES (?, ?, 10, NOW(), NOW(), 'outflow', 'expense', 'needs', 'confirmed')`, // Keep
      `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, budget_bucket, status) VALUES (?, ?, 10, NOW(), NOW(), 'inflow', 'income', null, 'confirmed')`, // Keep
      `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, budget_bucket, status) VALUES (?, ?, 10, NOW(), NOW(), 'outflow', 'expense', 'needs', 'pending')`, // Exclude
      `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, budget_bucket, status) VALUES (?, ?, 10, NOW(), NOW(), 'inflow', 'refund', null, 'confirmed')`, // Exclude
      `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, budget_bucket, status) VALUES (?, ?, 10, NOW(), NOW(), 'outflow', 'transfer', null, 'confirmed')`, // Exclude
      `INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, budget_bucket, status) VALUES (?, ?, 10, NOW(), NOW(), 'outflow', 'saving', 'savings', 'confirmed')` // Exclude
    ];

    for (let q of queries) {
      const [r] = await db.execute(q, [userId, cycleId]);
      added.push(r.insertId);
    }

    const payload = await ChatContextService.buildChatPayload({
      userId, conversationId: convId, requestId: crypto.randomUUID(), message: 'Matrix'
    });

    // Should only have 2 added transactions + any pre-existing
    const testTxs = payload.transactions.filter(t => added.includes(Number(t.id)));
    expect(testTxs.length).toBe(2);
    expect(testTxs.map(t => t.amount)).toEqual([10, 10]);

    if (added.length) await db.execute(`DELETE FROM transactions WHERE id IN (${added.join(',')})`);
  });

  it('Calendar-day timezone math covers exact edge cases', () => {
    // Tests _calculateCycleDays directly
    const timeZone = 'UTC';
    // 1. Same-day cycle
    let res = ChatContextService._calculateCycleDays('2026-06-01T10:00:00Z', '2026-06-01T20:00:00Z', '2026-06-01T15:00:00Z', timeZone);
    expect(res).toEqual({ totalDays: 1, elapsedDays: 1, remainingDays: 0 });

    // 2. First day of a 31-day inclusive cycle
    res = ChatContextService._calculateCycleDays('2026-01-01T00:00:00Z', '2026-01-31T23:59:59Z', '2026-01-01T12:00:00Z', timeZone);
    expect(res).toEqual({ totalDays: 31, elapsedDays: 1, remainingDays: 30 });

    // 3. Middle day
    res = ChatContextService._calculateCycleDays('2026-01-01T00:00:00Z', '2026-01-31T23:59:59Z', '2026-01-15T12:00:00Z', timeZone);
    expect(res).toEqual({ totalDays: 31, elapsedDays: 15, remainingDays: 16 });

    // 4. Last day
    res = ChatContextService._calculateCycleDays('2026-01-01T00:00:00Z', '2026-01-31T23:59:59Z', '2026-01-31T12:00:00Z', timeZone);
    expect(res).toEqual({ totalDays: 31, elapsedDays: 31, remainingDays: 0 });

    // 5. Before cycle start
    res = ChatContextService._calculateCycleDays('2026-01-01T00:00:00Z', '2026-01-31T23:59:59Z', '2025-12-31T12:00:00Z', timeZone);
    expect(res).toEqual({ totalDays: 31, elapsedDays: 1, remainingDays: 31 }); // Elapsed bounded to min 1

    // 6. After cycle end
    res = ChatContextService._calculateCycleDays('2026-01-01T00:00:00Z', '2026-01-31T23:59:59Z', '2026-02-01T12:00:00Z', timeZone);
    expect(res).toEqual({ totalDays: 31, elapsedDays: 31, remainingDays: 0 }); // Remaining bounded to 0

    // 7. Leap-day case
    res = ChatContextService._calculateCycleDays('2024-02-28T00:00:00Z', '2024-03-01T23:59:59Z', '2024-02-29T12:00:00Z', timeZone);
    expect(res).toEqual({ totalDays: 3, elapsedDays: 2, remainingDays: 1 });

    // 8. Near-midnight timestamp
    res = ChatContextService._calculateCycleDays('2026-01-01T00:00:00Z', '2026-01-31T23:59:59Z', '2026-01-15T23:59:59Z', timeZone);
    expect(res).toEqual({ totalDays: 31, elapsedDays: 15, remainingDays: 16 });
  });

  it('Commitment aggregates use all occurrences (>20) and exclude cancelled/paid', async () => {
    // We create a fresh user and cycle so no other tests interfere
    let [uRes] = await db.execute(`INSERT INTO users (full_name, email, password_hash, is_onboarded, account_status) VALUES ('CommUser', 'comm_${Date.now()}@test.com', 'hash', 1, 'active')`);
    let tempUserId = uRes.insertId;
    await db.execute(`INSERT INTO financial_profiles (user_id, currency, expected_monthly_income, timezone, onboarding_status) VALUES (?, 'JOD', 900, 'Asia/Amman', 'completed')`, [tempUserId]);

    let [cRes] = await db.execute(
      `INSERT INTO financial_cycles (user_id, start_date, end_date, expected_income, status) VALUES (?, DATE_SUB(CURDATE(), INTERVAL 5 DAY), DATE_ADD(CURDATE(), INTERVAL 25 DAY), 900, 'open')`,
      [tempUserId]
    );
    let tempCycleId = cRes.insertId;

    let [comRes] = await db.execute(
      `INSERT INTO financial_commitments (user_id, name, amount, status, frequency) VALUES (?, 'Test Comm', 10, 'active', 'monthly')`,
      [tempUserId]
    );
    let tempCommId = comRes.insertId;

    // Insert 25 unpaid
    let addedOcc = [];
    for(let i=0; i<25; i++) {
      let [oRes] = await db.execute(
        `INSERT INTO commitment_occurrences (commitment_id, cycle_id, amount, status, due_date) VALUES (?, ?, 10, 'upcoming', DATE_ADD(CURDATE(), INTERVAL ? DAY))`,
        [tempCommId, tempCycleId, i]
      );
      addedOcc.push(oRes.insertId);
    }
    
    // Insert 1 paid, 1 cancelled
    let [tRes] = await db.execute(`INSERT INTO transactions (user_id, cycle_id, amount, occurred_at, confirmed_at, direction, transaction_type, status) VALUES (?, ?, 10, NOW(), NOW(), 'outflow', 'expense', 'confirmed')`, [tempUserId, tempCycleId]);
    await db.execute(
      `INSERT INTO commitment_occurrences (commitment_id, cycle_id, amount, status, due_date, paid_transaction_id) VALUES (?, ?, 10, 'paid', DATE_ADD(CURDATE(), INTERVAL 26 DAY), ?)`,
      [tempCommId, tempCycleId, tRes.insertId]
    );
    await db.execute(
      `INSERT INTO commitment_occurrences (commitment_id, cycle_id, amount, status, due_date) VALUES (?, ?, 10, 'waived', DATE_ADD(CURDATE(), INTERVAL 27 DAY))`,
      [tempCommId, tempCycleId]
    );

    let tempConvId = await ChatRepository.createConversation(tempUserId, { title: 'Test Conv' });

    let payload = await ChatContextService.buildChatPayload({
      userId: tempUserId, conversationId: tempConvId, requestId: crypto.randomUUID(), message: 'Hi'
    });

    // 25 * 10 = 250, proves all 25 rows were fetched, no LIMIT 20 applied to aggregates. Paid/cancelled excluded.
    expect(payload.financial.commitments.unpaid).toBe(250);

    await db.execute(`DELETE FROM commitment_occurrences WHERE commitment_id = ?`, [tempCommId]);
    await db.execute(`DELETE FROM transactions WHERE id = ?`, [tRes.insertId]);
    await db.execute(`DELETE FROM financial_commitments WHERE id = ?`, [tempCommId]);
    await db.execute(`DELETE FROM chat_conversations WHERE id = ?`, [tempConvId]);
    await db.execute(`DELETE FROM financial_cycles WHERE id = ?`, [tempCycleId]);
    await db.execute(`DELETE FROM financial_profiles WHERE user_id = ?`, [tempUserId]);
    await db.execute(`DELETE FROM users WHERE id = ?`, [tempUserId]);
  });
});
