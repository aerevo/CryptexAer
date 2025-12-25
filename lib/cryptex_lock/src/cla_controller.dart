import 'dart:async';
import 'cla_models.dart';

class ClaController {
  final ClaConfig config;
  late DateTime _start;
  bool _jammed = false;
  bool _motionDetected = false;

  ClaController(this.config);

  void start() {
    _start = DateTime.now();
    _jammed = false;
    _motionDetected = false;
  }

  void registerMotion(double magnitude) {
    if (magnitude >= config.minShake) {
      _motionDetected = true;
    }
  }

  ClaResult validate(List<int> selected) {
    if (_jammed) return ClaResult.jammed;

    final elapsed = DateTime.now().difference(_start);
    if (elapsed < config.minSolveTime) return ClaResult.fail;
    if (!_motionDetected) return ClaResult.fail;

    // Zero Trap
    if (selected.contains(0)) {
      _jammed = true;
      return ClaResult.jammed;
    }

    // Kombinasi sebenar
    for (int i = 0; i < config.secret.length; i++) {
      if (selected[i] != config.secret[i]) {
        return ClaResult.fail;
      }
    }

    return ClaResult.success;
  }

  bool get isJammed => _jammed;
}
