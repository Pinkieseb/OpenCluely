class SpeechAzureService {
  constructor() {
    this.speechConfig = null;
    this.recognizer = null;
  }

  _initializeAzureClient() {
    // Handling setup, PushAudioInputStream, callbacks
  }
}

module.exports = new SpeechAzureService();
