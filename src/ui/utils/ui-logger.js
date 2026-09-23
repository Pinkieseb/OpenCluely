const path = require('path');

let logger;
try {
  logger = require('../core/logger').createServiceLogger('UI');
} catch (error) {
  logger = {
    info: console.log,
    warn: console.warn,
    error: console.error,
    debug: console.log,
  };
}

module.exports = logger;
