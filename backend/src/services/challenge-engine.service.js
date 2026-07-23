const { db } = require('../config/database');
const { ChallengeRepository } = require('../repositories/challenge.repository');
const { NotificationService } = require('./notification.service');

class ChallengeEngineService {
  // evaluateForExpense
  static async evaluateForExpense(userId, expenseData) {
    try {
      const activeChallenges = await ChallengeRepository.getActiveChallengesByMetricTypes(userId, [
        'wants_spending_limit',
        'expense_tracking_days',
        'no_spend_category'
      ]);

      if (!activeChallenges || activeChallenges.length === 0) return;

      for (const challenge of activeChallenges) {
        await this.recalculateChallenge(userId, challenge.userChallengeId);
      }
    } catch (e) {
      console.error('[ChallengeEngine] Error evaluating for expense:', e);
    }
  }

  // evaluateForExpenseDelete
  static async evaluateForExpenseDelete(userId, cycleId) {
    try {
      const activeChallenges = await ChallengeRepository.getActiveChallengesByMetricTypes(userId, [
        'wants_spending_limit',
        'expense_tracking_days',
        'no_spend_category'
      ]);

      if (!activeChallenges || activeChallenges.length === 0) return;

      for (const challenge of activeChallenges) {
        await this.recalculateChallenge(userId, challenge.userChallengeId);
      }
    } catch (e) {
      console.error('[ChallengeEngine] Error evaluating for expense delete:', e);
    }
  }

  // evaluateForGoalContribution
  static async evaluateForGoalContribution(userId, contributionData) {
    try {
      const activeChallenges = await ChallengeRepository.getActiveChallengesByMetricTypes(userId, [
        'goal_contribution_count',
        'savings_amount'
      ]);

      if (!activeChallenges || activeChallenges.length === 0) return;

      for (const challenge of activeChallenges) {
        await this.recalculateChallenge(userId, challenge.userChallengeId);
      }
    } catch (e) {
      console.error('[ChallengeEngine] Error evaluating for goal contribution:', e);
    }
  }

  // evaluateForSettlement
  static async evaluateForSettlement(userId, cycleId) {
    try {
      const activeChallenges = await ChallengeRepository.getActiveChallengesForUser(userId);
      if (!activeChallenges || activeChallenges.length === 0) return;

      for (const challenge of activeChallenges) {
        if (challenge.cycleId && challenge.cycleId.toString() !== cycleId.toString()) {
          continue; // not linked to this cycle or different cycle
        }
        
        await this.recalculateChallenge(userId, challenge.userChallengeId);

        // For wants_spending_limit, check final completion or failure
        if (challenge.metricType === 'wants_spending_limit') {
          // If already failed/completed, it would not be in active challenges, but just in case
          const current = await ChallengeRepository.getChallengeWithTemplate(challenge.userChallengeId);
          if (current && current.status === 'current') {
            if (current.currentValue <= current.targetValue) {
              await this.completeChallenge(current.userChallengeId, current.title);
            } else {
              await this.failChallenge(current.userChallengeId, current.title);
            }
          }
        }
        
        // no_spend_category final completion
        if (challenge.metricType === 'no_spend_category') {
          const current = await ChallengeRepository.getChallengeWithTemplate(challenge.userChallengeId);
          if (current && current.status === 'current') {
            // Re-eval: zero violations at end -> complete
            if (current.currentValue === 0) {
               await this.completeChallenge(current.userChallengeId, current.title);
            }
          }
        }
      }
    } catch (e) {
      console.error('[ChallengeEngine] Error evaluating for settlement:', e);
    }
  }

  // recalculateChallenge
  static async recalculateChallenge(userId, userChallengeId) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      const progressRow = await ChallengeRepository.getProgressForUpdate(conn, userChallengeId);
      if (!progressRow) {
        await conn.rollback();
        return;
      }

      const challenge = await ChallengeRepository.getChallengeWithTemplate(userChallengeId);
      if (!challenge || challenge.status !== 'current' || challenge.userId.toString() !== userId.toString()) {
        await conn.rollback();
        return;
      }

      let newCurrentValue = 0;
      let newTargetValue = challenge.targetValue;
      let newProgress = 0;
      let shouldComplete = false;
      let shouldFail = false;

      switch (challenge.metricType) {
        case 'expense_tracking_days': {
          const [rows] = await conn.execute(`
            SELECT COUNT(DISTINCT DATE(occurred_at)) as cnt
            FROM transactions 
            WHERE user_id = ? AND transaction_type = 'expense' AND status = 'confirmed' 
            AND DATE(occurred_at) >= DATE(?) AND DATE(occurred_at) <= DATE(?)
          `, [userId, challenge.startDate, challenge.endDate]);
          
          newCurrentValue = Number(rows[0].cnt);
          newTargetValue = Number(challenge.targetValue);
          newProgress = Math.min((newCurrentValue / newTargetValue) * 100, 100);
          if (newCurrentValue >= newTargetValue) shouldComplete = true;
          break;
        }
        case 'goal_contribution_count': {
          const [rows] = await conn.execute(`
            SELECT COUNT(*) as cnt
            FROM goal_transactions 
            WHERE user_id = ? AND transaction_type = 'contribution' 
            AND created_at >= ? AND created_at <= ?
          `, [userId, challenge.startDate, challenge.endDate]);
          
          newCurrentValue = Number(rows[0].cnt);
          newTargetValue = Number(challenge.targetValue);
          newProgress = Math.min((newCurrentValue / newTargetValue) * 100, 100);
          if (newCurrentValue >= newTargetValue) shouldComplete = true;
          break;
        }
        case 'savings_amount': {
          const [rows] = await conn.execute(`
            SELECT SUM(amount) as total
            FROM goal_transactions 
            WHERE user_id = ? AND transaction_type = 'contribution' 
            AND created_at >= ? AND created_at <= ?
          `, [userId, challenge.startDate, challenge.endDate]);
          
          newCurrentValue = Number(rows[0].total) || 0;
          newTargetValue = Number(challenge.targetValue);
          newProgress = Math.min((newCurrentValue / newTargetValue) * 100, 100);
          if (newCurrentValue >= newTargetValue) shouldComplete = true;
          break;
        }
        case 'wants_spending_limit': {
          if (!challenge.cycleId) {
             console.error('[ChallengeEngine] wants_spending_limit challenge has no cycleId');
             break;
          }
          const [rows] = await conn.execute(`
            SELECT SUM(amount) as total
            FROM transactions 
            WHERE user_id = ? AND cycle_id = ? AND budget_bucket = 'wants' 
            AND transaction_type = 'expense' AND status = 'confirmed'
          `, [userId, challenge.cycleId]);
          
          newCurrentValue = Number(rows[0].total) || 0;
          
          const cycleTarget = await ChallengeRepository.getCycleWantsTarget(userId, challenge.cycleId);
          if (cycleTarget !== null) {
            newTargetValue = Number(cycleTarget);
          } else {
             // fallback to template target if null
             newTargetValue = Number(challenge.targetValue);
          }
          
          // progress inverted for wants: lower is better. 100 - (current / target) * 100
          if (newTargetValue > 0) {
            newProgress = 100 - ((newCurrentValue / newTargetValue) * 100);
            newProgress = Math.max(0, Math.min(newProgress, 100));
          } else {
            newProgress = newCurrentValue > 0 ? 0 : 100;
          }
          
          // Do not complete wants limit here. Wait for settlement/end date.
          // Failure condition: if strictly greater than target
          if (newCurrentValue > newTargetValue) {
             shouldFail = true;
          }
          break;
        }
        case 'no_spend_category': {
          const cat = challenge.conditions && challenge.conditions.category ? challenge.conditions.category.toLowerCase() : '';
          const [rows] = await conn.execute(`
            SELECT COUNT(*) as cnt
            FROM transactions 
            WHERE user_id = ? AND transaction_type = 'expense' AND status = 'confirmed'
            AND LOWER(category) = ? 
            AND DATE(occurred_at) >= DATE(?) AND DATE(occurred_at) <= DATE(?)
          `, [userId, cat, challenge.startDate, challenge.endDate]);
          
          const violations = Number(rows[0].cnt);
          newCurrentValue = violations;
          newTargetValue = 0;
          
          if (violations > 0) {
            newProgress = 0;
            shouldFail = true;
          } else {
            // elapsed progress
            const now = new Date();
            const start = new Date(challenge.startDate);
            const end = new Date(challenge.endDate);
            const totalMs = end - start;
            const elapsedMs = now - start;
            if (totalMs > 0 && elapsedMs > 0) {
              newProgress = Math.min((elapsedMs / totalMs) * 100, 99.9);
            } else {
              newProgress = 0;
            }
          }
          break;
        }
      }

      await ChallengeRepository.updateProgress(userChallengeId, newCurrentValue, newTargetValue, newProgress);
      console.log(`[ChallengeEngine] Updated progress for userChallengeId=${userChallengeId}: current=${newCurrentValue}, progress=${newProgress}%`);

      await conn.commit();
      
      // Post-transaction completion/failure and notifications
      if (shouldComplete) {
         await this.completeChallenge(userChallengeId, challenge.title);
      } else if (shouldFail) {
         await this.failChallenge(userChallengeId, challenge.title);
      } else {
         await this.emitMilestoneNotifications(userId, userChallengeId, challenge.title, newProgress);
      }
      
    } catch (e) {
      if (conn) await conn.rollback();
      console.error('[ChallengeEngine] Error recalculating challenge:', e);
    } finally {
      if (conn) conn.release();
    }
  }

  static async completeChallenge(userChallengeId, title) {
     const challenge = await ChallengeRepository.getChallengeWithTemplate(userChallengeId);
     if (!challenge || challenge.status !== 'current') return;
     
     const success = await ChallengeRepository.completeChallenge(userChallengeId);
     if (success) {
        console.log(`[ChallengeEngine] Challenge completed: ${userChallengeId}`);
        // Ensure progress is 100
        await ChallengeRepository.updateProgress(userChallengeId, challenge.currentValue, challenge.targetValue, 100);
        
        // Notify
        const notifExists = await ChallengeRepository.checkDuplicateChallengeMilestone(challenge.userId, userChallengeId, 100);
        if (!notifExists) {
           await NotificationService.createNotification(challenge.userId, {
              type: 'success',
              category: 'system',
              title: 'أحسنت! تحدٍ مكتمل 🏆',
              message: `أكملت تحدي ${title} بنجاح.`,
              action_data: {
                 screen: 'challenges',
                 userChallengeId: Number(userChallengeId),
                 milestone: 100
              }
           });
        }
     }
  }

  static async failChallenge(userChallengeId, title) {
     const challenge = await ChallengeRepository.getChallengeWithTemplate(userChallengeId);
     if (!challenge || challenge.status !== 'current') return;
     
     const success = await ChallengeRepository.failChallenge(userChallengeId);
     if (success) {
        console.log(`[ChallengeEngine] Challenge failed: ${userChallengeId}`);
        // Notify
        const notifExists = await ChallengeRepository.checkDuplicateChallengeMilestone(challenge.userId, userChallengeId, -1);
        if (!notifExists) {
           await NotificationService.createNotification(challenge.userId, {
              type: 'warning',
              category: 'system',
              title: 'انتهى التحدي',
              message: `لم يتم إكمال تحدي ${title} هذه المرة.`,
              action_data: {
                 screen: 'challenges',
                 userChallengeId: Number(userChallengeId),
                 milestone: -1
              }
           });
        }
     }
  }

  static async emitMilestoneNotifications(userId, userChallengeId, title, progress) {
     let milestone = null;
     
     if (progress >= 75) {
        milestone = 75;
     } else if (progress >= 50) {
        milestone = 50;
     }
     
     if (!milestone) return;

     const notifExists = await ChallengeRepository.checkDuplicateChallengeMilestone(userId, userChallengeId, milestone);
     if (!notifExists) {
        let notifTitle, notifMessage;
        if (milestone === 75) {
           notifTitle = 'اقتربت من إكمال التحدي';
           notifMessage = `أكملت 75٪ من تحدي ${title}. بقي القليل!`;
        } else {
           notifTitle = 'نصف الطريق! 🎯';
           notifMessage = `أكملت 50٪ من تحدي ${title}. استمر!`;
        }
        
        await NotificationService.createNotification(userId, {
           type: 'info',
           category: 'system',
           title: notifTitle,
           message: notifMessage,
           action_data: {
              screen: 'challenges',
              userChallengeId: Number(userChallengeId),
              milestone: milestone
           }
        });
        console.log(`[ChallengeEngine] Milestone ${milestone}% notification sent for challenge ${userChallengeId}`);
     }
  }
}

module.exports = { ChallengeEngineService };
