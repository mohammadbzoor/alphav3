const axios = require('axios');
const FormData = require('form-data');

class N8nService {
  static async forwardToWebhook(file, type) {
    const WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;

    let host = 'unknown';
    try {
      if (WEBHOOK_URL) host = new URL(WEBHOOK_URL).host;
    } catch (e) {}

    console.log('N8N webhook configured=true');
    console.log('N8N webhook host=' + host);
    console.log('TYPE:', type);

    if (!WEBHOOK_URL) {
      throw new Error('N8N_WEBHOOK_URL is not defined in environment variables');
    }

    if (!file || !file.buffer) {
      throw new Error('No file provided or file buffer is missing');
    }

    console.log('BUFFER SIZE:', file.buffer.length);

    const form = new FormData();
    // Use 'file' as the field name, provide the buffer, and pass original name and mime type
    form.append('file', file.buffer, {
      filename: file.originalname || 'upload.jpg',
      contentType: file.mimetype || 'application/octet-stream'
    });
    form.append('type', type); // 'image' or 'voice'

    // Configure retry logic
    const maxRetries = 2;
    let attempt = 0;

    while (attempt <= maxRetries) {
      try {
        const response = await axios.post(WEBHOOK_URL, form, {
          headers: {
            ...form.getHeaders()
          },
          timeout: 60000, // 60 seconds timeout
          maxBodyLength: Infinity,
          maxContentLength: Infinity
        });

        const rawData = response.data;
        const typeOfData = typeof rawData;
        const isArray = Array.isArray(rawData);
        const isBuffer = Buffer.isBuffer(rawData);

        let rootKeys = '';
        if (rawData && typeOfData === 'object' && !isArray && !isBuffer) {
          rootKeys = Object.keys(rawData).join(',');
        }

        let outputType = 'undefined';
        let dataType = 'undefined';
        if (rawData && typeOfData === 'object') {
          if (isArray && rawData.length > 0) {
            outputType = typeof rawData[0].output;
            dataType = typeof rawData[0].data;
          } else if (!isArray && !isBuffer) {
            outputType = typeof rawData.output;
            dataType = typeof rawData.data;
          }
        }

        let strContent = '';
        if (typeOfData === 'string') {
          strContent = rawData;
        } else if (isBuffer) {
          strContent = rawData.toString('utf8');
        } else if (rawData && typeof rawData.output === 'string') {
          strContent = rawData.output;
        } else if (isArray && rawData.length > 0 && typeof rawData[0].output === 'string') {
          strContent = rawData[0].output;
        } else if (rawData && typeof rawData.data === 'string') {
          strContent = rawData.data;
        } else if (isArray && rawData.length > 0 && typeof rawData[0].data === 'string') {
          strContent = rawData[0].data;
        }

        const containsMarkdownFence = strContent.includes('```json') || strContent.includes('```');

        const { isTransactionCandidate } = require('../utils/n8n-response.helper');
        const isCandidate = isTransactionCandidate(rawData);

        let length = 'undefined';
        if (isBuffer) length = rawData.length;
        else if (typeOfData === 'string') length = rawData.length;
        else if (isArray) length = rawData.length;
        else if (typeOfData === 'object') length = 'not_applicable';

        let transactionCount = 'undefined';
        if (isArray) {
            transactionCount = rawData.length;
        }

        console.log(`N8N statusCode=${response.status}`);
        console.log(`N8N contentType=${response.headers['content-type']}`);
        console.log(`N8N responseRuntimeType=${typeOfData}${isBuffer ? ' (Buffer)' : ''}${isArray ? ' (Array)' : ''}`);
        console.log(`N8N responseLength=${length}`);
        console.log(`N8N rootIsList=${isArray}`);
        console.log(`N8N rootIsMap=${typeOfData === 'object' && !isArray && !isBuffer}`);
        console.log(`N8N rootKeys=${rootKeys}`);
        console.log(`N8N outputType=${outputType}`);
        console.log(`N8N dataType=${dataType}`);
        console.log(`N8N transactionCount=${transactionCount}`);
        console.log(`N8N containsMarkdownFence=${containsMarkdownFence}`);
        console.log(`N8N directTransactionCandidate=${isCandidate}`);

        return rawData;
      } catch (error) {
        attempt++;
        console.error(`N8n Webhook Error (Attempt ${attempt}):`, error.message);

        if (error.response) {
          console.error('Webhook Response Data:', error.response.data);
          console.error('Webhook Response Status:', error.response.status);
        }

        if (attempt > maxRetries) {
          const err = new Error('Failed to process file with AI after multiple attempts.');
          err.statusCode = 502; // Bad Gateway
          throw err;
        }

        // Wait before retrying (exponential backoff: 1s, 2s)
        await new Promise(resolve => setTimeout(resolve, attempt * 1000));
      }
    }
  }
}

module.exports = { N8nService };
