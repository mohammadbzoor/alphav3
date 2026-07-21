const { asyncHandler } = require('../utils/async-handler');
const { N8nService } = require('../services/n8n.service');

class ReceiptsController {
  static analyze = asyncHandler(async (req, res) => {
    console.log('FILE EXISTS:', !!req.file);
    console.log('FIELDNAME:', req.file?.fieldname);

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No receipt image uploaded',
        data: null,
        meta: null
      });
    }

    const n8nResponse = await N8nService.forwardToWebhook(req.file, 'image');

    // Make sure sourceType is set to 'image' if not provided by n8n
    if (n8nResponse && typeof n8nResponse === 'object') {
      n8nResponse.sourceType = 'image';
    }

    res.status(200).json({
      success: true,
      message: 'Receipt analyzed successfully',
      data: n8nResponse,
      meta: null
    });
  });
}

module.exports = { ReceiptsController };
