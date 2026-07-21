const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { AppError } = require('../utils/app-error');

const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new AppError('Unauthorized access', 401, 'UNAUTHORIZED'));
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, env.jwtAccessSecret || 'secret');
    req.user = { id: decoded.id };
    next();
  } catch (err) {
    return next(new AppError('Invalid or expired token', 401, 'UNAUTHORIZED'));
  }
};

module.exports = { authenticate };
