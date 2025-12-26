import 'dart:math';

class ClaController {
  final ClaConfig config;

  bool _jammed = false;
  DateTime? _jamUntil;

  ClaController(this.config);

  bool get isJammed {
    if (_jamUntil == null) return false;
    if (DateTime.now().isAfter(_jamUntil!)) {
      _jamUntil = null;
      _jammed = false;
      return false;
    }
    return true;
  }

  void jam() {
    _jammed = true;
    _jamUntil = DateTime.now().add(config.jamCooldown);
  }

  bool validateSolveTime(Duration elapsed) {
    return elapsed >= config.minSolveTime;
  }

  bool validateShake(double avgShake) {
    return avgShake >= config.minShake;
  }

  bool shouldRequireLock(double amount) {
    return amount >= config.thresholdAmount;
  }

  int nextTrapIndex(int wheelSize) {
    final rand = Random();
    return rand.nextInt(wheelSize);
  }
}
