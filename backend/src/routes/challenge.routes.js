const express = require('express');
const { ChallengeController } = require('../controllers/challenge.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../utils/async-handler');

const router = express.Router();

router.use(authenticate);

router.get('/', asyncHandler(ChallengeController.getChallenges));
router.get('/available', asyncHandler(ChallengeController.getAvailableChallenges));
router.get('/current', asyncHandler(ChallengeController.getCurrentChallenges));
router.get('/completed', asyncHandler(ChallengeController.getCompletedChallenges));
router.get('/:id', asyncHandler(ChallengeController.getChallengeById));
router.post('/:templateId/accept', asyncHandler(ChallengeController.acceptChallenge));
router.post('/:id/cancel', asyncHandler(ChallengeController.cancelChallenge));

module.exports = router;
