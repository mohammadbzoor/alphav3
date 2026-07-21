const axios = require('axios');
const FormData = require('form-data');

class N8nService {
  static async forwardToWebhook(file, type) {
    const WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;

    console.log('WEBHOOK URL:', WEBHOOK_URL);
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

        return response.data;
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
