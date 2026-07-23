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

    console.log(`VOICE fileExists=true`);
    console.log(`VOICE fileSize=${req.file.size}`);
    console.log(`VOICE uploadStarted`);
    console.log(`VOICE endpoint=/voice/parse`);
    console.log(`VOICE multipartField=audio`);

    const n8nResponse = await N8nService.forwardToWebhook(req.file, 'voice');

    // 1. Capture exact nested n8n structure safely
    const rootType = n8nResponse === null ? 'null' : (Array.isArray(n8nResponse) ? 'array' : typeof n8nResponse);
    console.log(`VOICE_N8N rootType=${rootType}`);
    if (rootType === 'object') {
        console.log(`VOICE_N8N rootKeys=${Object.keys(n8nResponse).join(',')}`);
        console.log(`VOICE_N8N successType=${typeof n8nResponse.success}`);
        console.log(`VOICE_N8N dataType=${typeof n8nResponse.data}`);
        if (n8nResponse.data && typeof n8nResponse.data === 'object') {
            console.log(`VOICE_N8N dataKeys=${Object.keys(n8nResponse.data).join(',')}`);
            console.log(`VOICE_N8N dataTransactionsType=${Array.isArray(n8nResponse.data.transactions) ? 'array' : typeof n8nResponse.data.transactions}`);
            if (Array.isArray(n8nResponse.data.transactions)) {
                console.log(`VOICE_N8N dataTransactionsLength=${n8nResponse.data.transactions.length}`);
            }
        }
        console.log(`VOICE_N8N metaType=${typeof n8nResponse.meta}`);
        if (n8nResponse.meta && typeof n8nResponse.meta === 'object') {
            console.log(`VOICE_N8N metaKeys=${Object.keys(n8nResponse.meta).join(',')}`);
            console.log(`VOICE_N8N metaTransactionCount=${n8nResponse.meta.transactionCount}`);
            console.log(`VOICE_N8N metaRequiresReview=${n8nResponse.meta.requiresReview}`);
        }
    }

    // 2. Fix normalization order & 3. Recognize the verified envelope
    function isTransactionCandidate(obj) {
      if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return false;
      if (obj.amount === undefined || obj.amount === null) return false;
      const numAmount = Number(obj.amount);
      if (isNaN(numAmount) || !isFinite(numAmount) || numAmount <= 0) return false;

      const recognizedFields = ['description', 'date', 'transactionDate', 'bucket', 'category', 'paymentMethod', 'confidence', 'sourceType', 'transactionType'];
      return recognizedFields.some(field => obj[field] !== undefined);
    }

    function isBackendEnvelope(value) {
      if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
      const hasData = 'data' in value;
      const hasSuccess = 'success' in value;
      const hasMeta = 'meta' in value;
      const hasMessage = 'message' in value;
      return hasData && (hasSuccess || hasMeta || hasMessage);
    }

    // We also need to extract parentSourceType and requiresReview. We can extract them as we unwrap.
    let parentSourceType = null;
    let parentRequiresReview = true; // default true for Voice AI

    function normalizeVoice(value, depth = 0) {
      if (depth > 3) {
        throw { code: 'VOICE_ANALYSIS_INVALID_RESPONSE' };
      }

      // 1. Axios-style response
      if (value && value.status && value.headers && value.config && value.data !== undefined) {
        return normalizeVoice(value.data, depth + 1);
      }

      // 2. Buffer
      if (Buffer.isBuffer(value)) {
        return normalizeVoice(value.toString('utf8'), depth + 1);
      }

      // 3. String
      if (typeof value === 'string') {
        let trimmed = value.trim();
        if (trimmed.charCodeAt(0) === 0xFEFF) trimmed = trimmed.slice(1);
        if (trimmed.startsWith('```json')) {
          const endIdx = trimmed.lastIndexOf('```');
          if (endIdx > 7) trimmed = trimmed.substring(7, endIdx).trim();
        } else if (trimmed.startsWith('```')) {
          const endIdx = trimmed.lastIndexOf('```');
          if (endIdx > 3) trimmed = trimmed.substring(3, endIdx).trim();
        }
        try {
          return normalizeVoice(JSON.parse(trimmed), depth + 1);
        } catch (e) {
          throw { code: 'VOICE_ANALYSIS_INVALID_RESPONSE' };
        }
      }

      // 4. Array
      if (Array.isArray(value)) {
        if (value.length > 0) {
          if (value.every(isTransactionCandidate)) return value;
          if (value.length === 1 && isBackendEnvelope(value[0])) return normalizeVoice(value[0], depth + 1);
          if (value.every(isBackendEnvelope)) {
            let flattened = [];
            for (const env of value) {
              if (env.data && env.data.sourceType) parentSourceType = env.data.sourceType;
              if (env.meta && env.meta.requiresReview !== undefined) parentRequiresReview = env.meta.requiresReview;
              if (env.data && Array.isArray(env.data.transactions)) {
                flattened.push(...env.data.transactions);
              }
            }
            return flattened;
          }
        }
        return value;
      }

      if (value && typeof value === 'object') {
        // Extract metadata if available
        if (value.data && value.data.sourceType) parentSourceType = value.data.sourceType;
        else if (value.sourceType) parentSourceType = value.sourceType;

        if (value.meta && typeof value.meta.requiresReview === 'boolean') {
          parentRequiresReview = value.meta.requiresReview;
        }

        // 5. Map/Object with data.transactions
        if (value.data && typeof value.data === 'object' && value.data.transactions !== undefined) {
          return normalizeVoice(value.data.transactions, depth + 1);
        }
        // 6. Map/Object with transactions
        if (value.transactions !== undefined) {
          return normalizeVoice(value.transactions, depth + 1);
        }
        // 7. Map/Object with data
        if (value.data !== undefined) {
          return normalizeVoice(value.data, depth + 1);
        }
        // 8. Map/Object with output
        if (value.output !== undefined) {
          return normalizeVoice(value.output, depth + 1);
        }
        // 9. Map/Object with result
        if (value.result !== undefined) {
          return normalizeVoice(value.result, depth + 1);
        }
        // 10. Direct transaction candidate
        if (isTransactionCandidate(value)) {
          return [value];
        }
      }

      // 11. Otherwise
      throw { code: 'VOICE_ANALYSIS_INVALID_RESPONSE' };
    }

    let normalized = [];
    try {
      normalized = normalizeVoice(n8nResponse);
    } catch (err) {
      return res.status(502).json({
        success: false,
        code: 'VOICE_ANALYSIS_INVALID_RESPONSE',
        message: 'The voice analysis response could not be processed.'
      });
    }

    // 4. Validate the extracted transaction array
    if (!Array.isArray(normalized) || normalized.length === 0) {
      return res.status(502).json({
        success: false,
        code: 'VOICE_ANALYSIS_INVALID_RESPONSE',
        message: 'The voice analysis response could not be processed.'
      });
    }

    const isValid = normalized.every(item =>
      item &&
      typeof item === 'object' &&
      !Array.isArray(item) &&
      (typeof item.amount === 'number' || typeof item.amount === 'string') &&
      parseFloat(item.amount) > 0
    );

    if (!isValid) {
      return res.status(502).json({
        success: false,
        code: 'VOICE_ANALYSIS_INVALID_RESPONSE',
        message: 'The voice analysis response could not be processed.'
      });
    }

    // 5. Normalize sourceType safely
    const transactions = normalized.map((item) => {
      const amount = typeof item.amount === 'string' ? parseFloat(item.amount) : item.amount;
      return {
        ...item,
        amount,
        sourceType: item.sourceType || item.source_type || parentSourceType || 'voice',
      };
    });

    console.log(`VOICE_CONTROLLER normalizedType=array`);
    console.log(`VOICE_CONTROLLER transactionCount=${transactions.length}`);
    console.log(`VOICE_CONTROLLER sourceType=voice`);
    console.log(`VOICE_CONTROLLER responseShape=normalized_transactions`);
    console.log(`VOICE_CONTROLLER statusCode=200`);

    // 6. Return one stable Backend contract & 7. Prevent nested double-envelope output
    return res.status(200).json({
      success: true,
      message: "Voice parsed successfully",
      data: {
        sourceType: 'voice',
        transactions
      },
      meta: {
        transactionCount: transactions.length,
        requiresReview: parentRequiresReview
      }
    });
  });
}

module.exports = { VoiceController };
