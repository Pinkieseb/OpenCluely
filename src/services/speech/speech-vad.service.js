class SpeechVadService {
  constructor() {
    this.vadSpeechMs = 0;
    this.vadNoiseFloor = 0;
  }

  _resetVadState() {
    // Voice activity detection state machine
  }
}

module.exports = new SpeechVadService();
