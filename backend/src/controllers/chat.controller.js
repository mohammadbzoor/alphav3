const { AppError } = require('../utils/app-error');
const { ChatService } = require('../services/chat.service');

exports.sendMessage = async (req, res, next) => {
  try {
    const userId = req.user.id; // From authMiddleware

    // The chatService will validate the body and ensure no trusted fields are injected
    const result = await ChatService.processUserMessage(userId, req.body);

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
};
