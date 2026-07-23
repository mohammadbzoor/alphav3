const { AppError } = require('./app-error');

function isTransactionCandidate(obj) {
    if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return false;
    
    // amount exists, is numeric/numeric string, finite, > 0
    if (obj.amount === undefined || obj.amount === null) return false;
    const numAmount = Number(obj.amount);
    if (isNaN(numAmount) || !isFinite(numAmount) || numAmount <= 0) return false;

    // At least one other transaction field
    const recognizedFields = ['description', 'date', 'transactionDate', 'bucket', 'category', 'paymentMethod', 'payment_method', 'confidence', 'sourceType', 'source_type', 'transactionType', 'transaction_type'];
    for (const field of recognizedFields) {
        if (obj[field] !== undefined) {
            return true;
        }
    }
    return false;
}

function normalizeReceiptAnalysisResponse(value, depth = 0) {
    if (depth > 3) {
        throw new AppError('The receipt analysis response could not be processed.', 502, 'RECEIPT_ANALYSIS_INVALID_RESPONSE');
    }

    // 1. Axios response
    if (value && value.status && value.headers && value.config && value.data !== undefined) {
        return normalizeReceiptAnalysisResponse(value.data, depth + 1);
    }

    // 2. Buffer
    if (Buffer.isBuffer(value)) {
        return normalizeReceiptAnalysisResponse(value.toString('utf8'), depth + 1);
    }

    // 3. String
    if (typeof value === 'string') {
        let trimmed = value.trim();
        if (trimmed.charCodeAt(0) === 0xFEFF) {
            trimmed = trimmed.slice(1);
        }
        if (trimmed.startsWith('```json')) {
            const endIdx = trimmed.lastIndexOf('```');
            if (endIdx > 7) trimmed = trimmed.substring(7, endIdx).trim();
        } else if (trimmed.startsWith('```')) {
            const endIdx = trimmed.lastIndexOf('```');
            if (endIdx > 3) trimmed = trimmed.substring(3, endIdx).trim();
        }
        
        let parsed;
        try {
            parsed = JSON.parse(trimmed);
        } catch (e) {
            throw new AppError('The receipt analysis response could not be processed.', 502, 'RECEIPT_ANALYSIS_INVALID_RESPONSE');
        }
        return normalizeReceiptAnalysisResponse(parsed, depth + 1);
    }

    // 4. Array
    if (Array.isArray(value)) {
        if (value.length > 0 && value[0] && typeof value[0] === 'object' && !Array.isArray(value[0])) {
            const first = value[0];
            if (first.output !== undefined) return normalizeReceiptAnalysisResponse(first.output, depth + 1);
            if (first.data !== undefined) return normalizeReceiptAnalysisResponse(first.data, depth + 1);
            if (first.result !== undefined) return normalizeReceiptAnalysisResponse(first.result, depth + 1);
        }
        // Keep it if it's an array
        return value;
    }

    // 5-8. Object with envelope
    if (value && typeof value === 'object') {
        if (value.transactions !== undefined) return normalizeReceiptAnalysisResponse(value.transactions, depth + 1);
        if (value.data !== undefined) return normalizeReceiptAnalysisResponse(value.data, depth + 1);
        if (value.output !== undefined) return normalizeReceiptAnalysisResponse(value.output, depth + 1);
        if (value.result !== undefined) return normalizeReceiptAnalysisResponse(value.result, depth + 1);

        // 9. Direct single transaction object
        if (isTransactionCandidate(value)) {
            return [value];
        }
    }

    // 10. Unsupported
    throw new AppError('The receipt analysis response could not be processed.', 502, 'RECEIPT_ANALYSIS_INVALID_RESPONSE');
}

module.exports = { normalizeReceiptAnalysisResponse, isTransactionCandidate };
