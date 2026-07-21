const { AppError } = require('../utils/app-error');

const errorMiddleware = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;

  console.error(err);

  if (err.code === 'ER_DUP_ENTRY') {
    const message = 'Duplicate field value entered';
    error = new AppError(message, 409, 'DUPLICATE_ENTRY');
  }

  const statusCode = error.statusCode || 500;
  const message = error.isOperational ? error.message : 'Internal Server Error';
  const code = error.code || 'INTERNAL_ERROR';

  // Mark operational errors
  const isOperational = error.isOperational || (statusCode >= 400 && statusCode < 500);

  res.status(statusCode).json({
    success: false,
    message,
    code,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
};

module.exports = { errorMiddleware };
