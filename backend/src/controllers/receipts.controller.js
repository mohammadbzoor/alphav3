const { asyncHandler } = require('../utils/async-handler');
const { N8nService } = require('../services/n8n.service');
const { normalizeReceiptAnalysisResponse } = require('../utils/n8n-response.helper');
const { AppError } = require('../utils/app-error');

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

    let normalizedData;
    try {
      normalizedData = normalizeReceiptAnalysisResponse(n8nResponse);

      if (!Array.isArray(normalizedData) || normalizedData.length === 0) {
        throw { code: 'RECEIPT_ANALYSIS_INVALID_RESPONSE', message: 'Result must be a non-empty array' };
      }

      const transactions = normalizedData.map((item) => {
        if (!item || typeof item !== 'object') {
          throw new AppError('Every element must be a plain object', 502, 'RECEIPT_ANALYSIS_INVALID_RESPONSE');
        }
        const amount = Number(item.amount);
        if (isNaN(amount) || !isFinite(amount) || amount <= 0) {
          throw new AppError('Every element must have a valid positive amount', 502, 'RECEIPT_ANALYSIS_INVALID_RESPONSE');
        }
        return {
          ...item,
          sourceType: item.sourceType || item.source_type || 'image',
        };
      });

      console.log(`RECEIPT_CONTROLLER normalizedType=array`);
      console.log(`RECEIPT_CONTROLLER transactionCount=${transactions.length}`);
      console.log(`RECEIPT_CONTROLLER responseShape=normalized_transactions`);
      console.log(`RECEIPT_CONTROLLER statusCode=200`);

      return res.status(200).json({
        success: true,
        data: {
          sourceType: 'image',
          transactions: transactions
        },
        meta: {
          transactionCount: transactions.length,
          requiresReview: true
        }
      });
    } catch (err) {
      throw err;
    }
  });
}

module.exports = { ReceiptsController };
