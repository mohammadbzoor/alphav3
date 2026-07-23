const { ChallengeRepository } = require('../repositories/challenge.repository');
const { AppError } = require('../middleware/error.middleware');

class ChallengeService {
  static _mapToFlutterModel(row, isAvailable = false) {
    const daysLeft = row.endDate ? Math.max(0, Math.ceil((new Date(row.endDate) - new Date()) / (1000 * 60 * 60 * 24))) : row.totalDays;
    
    return {
      id: row.id ? String(row.id) : `temp_${row.templateId}`,
      templateId: row.templateId,
      title: row.title,
      description: row.description,
      type: row.type || 'individual',
      status: row.status || (isAvailable ? 'available' : 'current'),
      progress: row.progress ? Number(row.progress) / 100 : 0.0,
      currentValue: Number(row.currentValue || 0),
      targetValue: Number(row.targetValue || 0),
      totalDays: row.totalDays || 7,
      daysLeft: daysLeft,
      xpReward: row.xpReward || 0,
      icon: row.icon || 'star',
      isAccepted: row.isAccepted || false,
      startDate: row.startDate || null,
      endDate: row.endDate || null
    };
  }

  static async getChallenges(userId) {
    const [available, current, completed] = await Promise.all([
      ChallengeRepository.getAvailableChallenges(userId),
      ChallengeRepository.getCurrentChallenges(userId),
      ChallengeRepository.getCompletedChallenges(userId)
    ]);

    return {
      available: available.map(r => ChallengeService._mapToFlutterModel(r, true)),
      current: current.map(r => ChallengeService._mapToFlutterModel(r, false)),
      completed: completed.map(r => ChallengeService._mapToFlutterModel(r, false))
    };
  }

  static async getAvailableChallenges(userId) {
    const available = await ChallengeRepository.getAvailableChallenges(userId);
    return available.map(r => ChallengeService._mapToFlutterModel(r, true));
  }

  static async getCurrentChallenges(userId) {
    const current = await ChallengeRepository.getCurrentChallenges(userId);
    return current.map(r => ChallengeService._mapToFlutterModel(r, false));
  }

  static async getCompletedChallenges(userId) {
    const completed = await ChallengeRepository.getCompletedChallenges(userId);
    return completed.map(r => ChallengeService._mapToFlutterModel(r, false));
  }

  static async getChallengeById(userId, challengeId) {
    // This is a naive implementation just for the endpoint.
    // In a real app we'd query by ID directly.
    const current = await ChallengeRepository.getCurrentChallenges(userId);
    const challenge = current.find(c => String(c.id) === String(challengeId));
    if (challenge) return ChallengeService._mapToFlutterModel(challenge, false);

    const completed = await ChallengeRepository.getCompletedChallenges(userId);
    const compChallenge = completed.find(c => String(c.id) === String(challengeId));
    if (compChallenge) return ChallengeService._mapToFlutterModel(compChallenge, false);

    throw new AppError('Challenge not found', 404, 'NOT_FOUND');
  }

  static async acceptChallenge(userId, templateId, cycleId) {
    const template = await ChallengeRepository.getChallengeTemplate(templateId);
    if (!template) {
      throw new AppError('Challenge template not found', 404, 'NOT_FOUND');
    }
    if (!template.isActive) {
      throw new AppError('Challenge is not active', 400, 'INACTIVE_CHALLENGE');
    }

    let finalCycleId = cycleId;
    if (!finalCycleId) {
      const activeCycle = await ChallengeRepository.getActiveCycle(userId);
      if (activeCycle) {
        finalCycleId = activeCycle.id;
      }
    }

    try {
      const userChallengeId = await ChallengeRepository.acceptChallenge(
        userId,
        templateId,
        finalCycleId || null,
        template.durationDays,
        template.targetValue
      );
      
      // Return the new challenge
      const current = await ChallengeRepository.getCurrentChallenges(userId);
      const challenge = current.find(c => String(c.id) === String(userChallengeId));
      return ChallengeService._mapToFlutterModel(challenge, false);
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') {
        throw new AppError('Challenge already accepted', 409, 'ALREADY_ACCEPTED');
      }
      throw err;
    }
  }

  static async cancelChallenge(userId, userChallengeId) {
    const success = await ChallengeRepository.cancelChallenge(userId, userChallengeId);
    if (!success) {
      throw new AppError('Active challenge not found', 404, 'NOT_FOUND');
    }
    return true;
  }
}

module.exports = { ChallengeService };
