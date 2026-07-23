const { ChallengeService } = require('../services/challenge.service');
const { AppError } = require('../middleware/error.middleware');

class ChallengeController {
  static async getChallenges(req, res) {
    const userId = req.user.id;
    const data = await ChallengeService.getChallenges(userId);
    res.json({ success: true, data });
  }

  static async getAvailableChallenges(req, res) {
    const userId = req.user.id;
    const data = await ChallengeService.getAvailableChallenges(userId);
    res.json({ success: true, data });
  }

  static async getCurrentChallenges(req, res) {
    const userId = req.user.id;
    const data = await ChallengeService.getCurrentChallenges(userId);
    res.json({ success: true, data });
  }

  static async getCompletedChallenges(req, res) {
    const userId = req.user.id;
    const data = await ChallengeService.getCompletedChallenges(userId);
    res.json({ success: true, data });
  }

  static async getChallengeById(req, res) {
    const userId = req.user.id;
    const { id } = req.params;
    const data = await ChallengeService.getChallengeById(userId, id);
    res.json({ success: true, data });
  }

  static async acceptChallenge(req, res) {
    const userId = req.user.id;
    let { templateId } = req.params;
    if (templateId.startsWith('temp_')) {
      templateId = templateId.replace('temp_', '');
    }
    const { cycleId } = req.body;

    const data = await ChallengeService.acceptChallenge(userId, templateId, cycleId);
    res.json({ success: true, data });
  }

  static async cancelChallenge(req, res) {
    const userId = req.user.id;
    const { id } = req.params;
    
    await ChallengeService.cancelChallenge(userId, id);
    res.json({ success: true, message: 'Challenge cancelled successfully' });
  }
}

module.exports = { ChallengeController };
