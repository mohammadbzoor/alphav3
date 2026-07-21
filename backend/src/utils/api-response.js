const sendResponse = (res, statusCode, success, message, data = null, meta = null) => {
  res.status(statusCode).json({
    success,
    message,
    data,
    meta
  });
};

module.exports = { sendResponse };
