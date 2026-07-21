const { asyncHandler } = require('../utils/async-handler');
const { N8nService } = require('../services/n8n.service');

class VoiceController {
  static parse = asyncHandler(async (req, res) => {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No voice audio uploaded',
        data: null,
        meta: null
      });
    }

    const n8nResponse = await N8nService.forwardToWebhook(req.file, 'voice');

    // Make sure sourceType is set to 'voice' if not provided by n8n
    if (n8nResponse && typeof n8nResponse === 'object') {
      n8nResponse.sourceType = 'voice';
    }

    res.status(200).json({
      success: true,
      message: 'Voice parsed successfully',
      data: n8nResponse,
      meta: null
    });
  });
}

module.exports = { VoiceController };
