
class ClaState {
  int failedAttempts = 0;
  DateTime? lastFail;
  bool jammed = false;

  void recordFail() {
    failedAttempts++;
    lastFail = DateTime.now();
  }

  void jam() {
    jammed = true;
  }

  void reset() {
    failedAttempts = 0;
    lastFail = null;
    jammed = false;
  }
}
