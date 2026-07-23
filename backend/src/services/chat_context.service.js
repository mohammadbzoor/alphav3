const { AppError } = require('../utils/app-error');
const { db } = require('../config/database');
const { ChatValidator } = require('../utils/chat_validator.util');
const { ChatContextRepository } = require('../repositories/chat_context.repository');
const { ChatRepository } = require('../repositories/chat.repository');
const { DashboardQueryService } = require('./dashboard.query.service');

const CHAT_CONTEXT_TRANSACTION_LIMIT = 15;
const CHAT_CONTEXT_MESSAGE_LIMIT = 10;
const CHAT_CONTEXT_GOAL_LIMIT = 10;
const CHAT_CONTEXT_COMMITMENT_LIMIT = 20;

class ChatContextService {
  /**
   * Constructs the complete AI payload for the given context.
   */
  static async buildChatPayload(options = {}) {
    const startBuild = Date.now();
    
    // 1. Input Validation
    const valid = ChatValidator.validateChatContextInput(options);
    const { userId, conversationId, requestId, message, intent, language, source, purchase, timestamp, excludeMessageId } = valid;
    
    const generatedAt = timestamp.toISOString();
    
    // 2. Load Core User & Profile Data
    const [user, profile] = await Promise.all([
      ChatContextRepository.getUserForChat(userId),
      ChatContextRepository.getFinancialProfileForChat(userId)
    ]);

    if (!user) {
      throw new AppError('User not found', 404, 'USER_NOT_FOUND');
    }
    if (user.account_status !== 'active') {
      throw new AppError('User account is not active', 403, 'USER_SUSPENDED');
    }
    if (!profile) {
      throw new AppError('Financial profile not found', 404, 'PROFILE_NOT_FOUND');
    }

    // 3. Conversation Ownership
    const conversation = await ChatContextRepository.getConversationForChat(conversationId, userId);
    if (!conversation) {
      throw new AppError('Conversation not found or belongs to another user', 404, 'CONVERSATION_NOT_FOUND');
    }
    if (conversation.status === 'closed') {
      throw new AppError('Conversation is closed and cannot accept new messages', 400, 'CONVERSATION_CLOSED');
    }

    // 4. Financial Calculations using Verified Dashboard Service
    const summary = await DashboardQueryService.getSummary(userId);
    
    const cycleId = summary.cycle.id || null;
    let transactions = [];
    let commitments = { monthlyTotal: 0, occurrences: [] };

    // Dashboard uses `recordedIncome` for all income in the cycle, and `expectedIncome` from cycle snapshot.
    // Rule: Monthly Income = Current cycle expected_income OR profile expected_monthly_income
    const monthlyIncome = summary.income.expected > 0 ? summary.income.expected : Number(profile.expected_monthly_income);

    // 5. Gather Specific Details 
    let activeGoals = [];
    let recentMessages = [];

    const detailsPromises = [
      ChatContextRepository.getActiveGoalsForChat(userId, CHAT_CONTEXT_GOAL_LIMIT),
      ChatRepository.getRecentConversationMessages(conversationId, userId, { limit: CHAT_CONTEXT_MESSAGE_LIMIT, excludeMessageId })
    ];

    if (cycleId) {
      detailsPromises.push(ChatContextRepository.getRecentCycleTransactionsForChat(userId, cycleId, CHAT_CONTEXT_TRANSACTION_LIMIT));
      detailsPromises.push(ChatContextRepository.getCommitmentsForChat(userId, cycleId, CHAT_CONTEXT_COMMITMENT_LIMIT));
    }

    const detailsResults = await Promise.all(detailsPromises);
    activeGoals = detailsResults[0];
    recentMessages = detailsResults[1];
    if (cycleId) {
      transactions = detailsResults[2];
      commitments = detailsResults[3];
    }

    // Missing-snapshot detection.
    let hasSnapshot = false;
    if (cycleId) {
      const [snapCheck] = await db.execute('SELECT id FROM cycle_allocation_snapshots WHERE cycle_id = ? LIMIT 1', [cycleId]);
      hasSnapshot = snapCheck.length > 0;
    }

    const needsTarget = hasSnapshot ? summary.buckets.needs.target : null;
    const wantsTarget = hasSnapshot ? summary.buckets.wants.target : null;
    const savingsTarget = hasSnapshot ? summary.buckets.savings.target : null;

    const needsRemaining = hasSnapshot ? summary.buckets.needs.remaining : null;
    const wantsRemaining = hasSnapshot ? summary.buckets.wants.remaining : null;
    const savingsRemaining = hasSnapshot && summary.buckets.savings.actual !== null ? summary.buckets.savings.remaining : null;

    // Date logic
    const cycleDates = cycleId && summary.cycle.startDate ? this._calculateCycleDays(summary.cycle.startDate, summary.cycle.endDate, generatedAt, profile.timezone) : null;
    
    const safeDailySpend = cycleDates ? this._calculateSafeDailySpend(
      monthlyIncome,
      (summary.buckets.needs.actual + summary.buckets.wants.actual),
      summary.commitments.totalReserved,
      hasSnapshot ? summary.buckets.savings.target : 0, // reserved savings
      cycleDates.remainingDays
    ) : null;

    // 6. Build the Payload
    const payload = {
      schemaVersion: "1.0",
      request: {
        id: requestId,
        text: message,
        intent,
        language,
        source,
        timestamp: generatedAt,
        timezone: profile.timezone
      },
      user: {
        id: String(user.id),
        name: user.full_name,
        currency: profile.currency,
        profile: {
          preferredLanguage: language,
          onboardingCompleted: user.is_onboarded === 1
        }
      },
        financial: {
          cycleId: cycleId ? String(cycleId) : null,
          monthlyIncome,
          needs: {
            target: cycleId ? needsTarget : null,
            spent: cycleId ? summary.buckets.needs.actual : 0,
            remaining: cycleId ? needsRemaining : null
          },
          wants: {
            target: cycleId ? wantsTarget : null,
            spent: cycleId ? summary.buckets.wants.actual : 0,
            remaining: cycleId ? wantsRemaining : null
          },
          savings: {
            target: cycleId ? savingsTarget : null,
            saved: cycleId ? summary.buckets.savings.actual : null,
            remaining: cycleId ? savingsRemaining : null
          },
          overall: {
            totalSpent: cycleId ? (summary.buckets.needs.actual + summary.buckets.wants.actual) : 0,
            remainingBudget: cycleId ? (needsRemaining !== null && wantsRemaining !== null ? needsRemaining + wantsRemaining : null) : null
          },
          analytics: {
            projectedExpenses: cycleDates ? this._calculateProjectedExpenses((summary.buckets.needs.actual + summary.buckets.wants.actual), cycleDates) : null,
            safeDailySpend
          },
          commitments: {
            monthly: commitments.monthlyTotal,
            unpaid: cycleId ? summary.commitments.totalReserved : null
          }
        },
        transactions: transactions.map(t => ({
          id: String(t.id),
          date: new Date(t.date).toISOString(),
          type: t.type,
          direction: t.direction,
          amount: Number(t.amount),
          currency: profile.currency,
          category: t.category || '',
          subcategory: null,
          description: t.description
        })),
        goals: activeGoals.map(g => ({
          id: String(g.id),
          name: g.name,
          targetAmount: Number(g.target_amount),
          savedAmount: Number(g.current_balance),
          remainingAmount: Number(g.target_amount) - Number(g.current_balance),
          plannedContribution: Number(g.planned_contribution || 0),
          targetDate: g.target_date ? new Date(g.target_date).toISOString() : null,
          status: g.status
        })),
        conversation: {
          id: String(conversation.id),
          messages: recentMessages.map(m => ({
            role: m.role,
            content: m.content,
            timestamp: new Date(m.created_at).toISOString()
          }))
        },
        context: {
          purchase,
          currentCycle: {
            status: summary.cycle.status,
            startDate: summary.cycle.startDate ? new Date(summary.cycle.startDate).toISOString() : null,
            endDate: summary.cycle.endDate ? new Date(summary.cycle.endDate).toISOString() : null,
            elapsedDays: cycleDates ? cycleDates.elapsedDays : null,
            remainingDays: cycleDates ? cycleDates.remainingDays : null,
            totalDays: cycleDates ? cycleDates.totalDays : null
          }
        },
      privacy: {
        containsFinancialData: true,
        dataScope: 'chat_context',
        generatedAt
      }
    };

    // 7. Payload Output Validation
    ChatValidator.validateAIPayload(payload);

    return payload;
  }

  static _getMidnightUTC(dateStr, timeZone) {
    if (!dateStr) return null;
    const d = new Date(dateStr);
    let parts;
    try {
      parts = new Intl.DateTimeFormat('en-US', {
        timeZone,
        year: 'numeric', month: 'numeric', day: 'numeric'
      }).formatToParts(d);
    } catch(e) {
      // Fallback if timezone is invalid
      parts = new Intl.DateTimeFormat('en-US', {
        timeZone: 'UTC',
        year: 'numeric', month: 'numeric', day: 'numeric'
      }).formatToParts(d);
    }
    const y = parts.find(p => p.type === 'year').value;
    const m = parts.find(p => p.type === 'month').value;
    const day = parts.find(p => p.type === 'day').value;
    return Date.UTC(y, m - 1, day);
  }

  static _calculateCycleDays(startDate, endDate, operationTime, timeZone) {
    const startM = this._getMidnightUTC(startDate, timeZone);
    const endM = this._getMidnightUTC(endDate, timeZone);
    const nowM = this._getMidnightUTC(operationTime, timeZone);

    // Inclusive days
    const totalDays = Math.max(1, Math.round((endM - startM) / 86400000) + 1);
    const elapsedDaysRaw = Math.round((nowM - startM) / 86400000) + 1;
    const elapsedDays = Math.max(1, Math.min(totalDays, elapsedDaysRaw));
    const remainingDays = Math.max(0, Math.round((endM - nowM) / 86400000)); // Today is considered elapsed, remaining is future days. Wait, if inclusive, remaining = end - now. If now = end, remaining = 0.

    return { totalDays, elapsedDays, remainingDays };
  }

  static _calculateProjectedExpenses(totalSpent, days) {
    return (totalSpent / days.elapsedDays) * days.totalDays;
  }

  static _calculateSafeDailySpend(income, totalSpent, unpaidCommitments, reservedSavings, remainingDays) {
    if (income === null || totalSpent === null || unpaidCommitments === null || reservedSavings === null || remainingDays === null) return null;
    const available = income - totalSpent - unpaidCommitments - reservedSavings;
    if (available <= 0) return 0;
    if (remainingDays === 0) return 0;
    return available / remainingDays;
  }
}

module.exports = { ChatContextService };
