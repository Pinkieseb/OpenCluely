const logger = require('./ui-logger');

function setupIpcListeners(callbacks = {}) {
  if (window.electronAPI) {
    if (callbacks.onCodingLanguageChanged) {
      window.electronAPI.onCodingLanguageChanged(callbacks.onCodingLanguageChanged);
      logger.info('Bound onCodingLanguageChanged');
    }
    if (callbacks.onSkillChanged) {
      window.electronAPI.onSkillChanged(callbacks.onSkillChanged);
      logger.info('Bound onSkillChanged');
    }
    // Add other generic IPC bindings here as needed
  } else {
    logger.warn('electronAPI not available in window');
  }
}

module.exports = { setupIpcListeners };
