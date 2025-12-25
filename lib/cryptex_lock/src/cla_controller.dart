import 'dart:async';
import 'cla_models.dart';

class ClaController {
  final ClaConfig config;
  late DateTime _start;
  bool _jammed = false;

  ClaController(this.config);

  void start() {
    _start = DateTime.now();
    _jammed = false;
  }

  ClaResult validate({
    required bool shakeDetected,
    required bool zeroTrapHit,
  }) {
    final elapsed = DateTime.now().difference(_start);
    if (elapsed < config.minSolveTime) return ClaResult.fail;
    if (!shakeDetected) return ClaResult.fail;
    if (zeroTrapHit) {
      _jammed = true;
      return ClaResult.jammed;
    }
    return ClaResult.success;
  }

  bool get isJammed => _jammed;
}