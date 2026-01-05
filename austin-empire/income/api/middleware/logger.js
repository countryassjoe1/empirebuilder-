const winston = require('winston');
const winstonLogger = winston.createLogger({
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

function logger(req, res, next) {
  winstonLogger.info(`💰 ${req.method} ${req.url} (user: ${req.user?.id ?? 'guest'})`);
  next();
}
module.exports = { logger };

// Expose the winston instance in case other modules need it
module.exports.winston = winstonLogger;
