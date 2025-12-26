// lib/cryptex_lock/src/cla_controller.dart
import 'dart:math';
import 'cla_config.dart';

class ClaController {
  final ClaConfig config;

  bool _jammed = false;
  DateTime? _jamUntil;

  ClaController(this.config);

  /// Memeriksa status Jammed (Perangkap Bot)
  bool get isJammed {
    if (_jamUntil == null) return false;
    if (DateTime.now().isAfter(_jamUntil!)) {
      _jamUntil = null;
      _jammed = false;
      return false;
    }
    return true;
  }

  /// Mengaktifkan perangkap (Honeypot Trigger)
  void jam() {
    _jammed = true;
    _jamUntil = DateTime.now().add(config.jamCooldown);
  }

  /// Validasi masa (Time Inertia Defense)
  bool validateSolveTime(Duration elapsed) {
    return elapsed >= config.minSolveTime;
  }

  /// Validasi gegaran (Physical Presence Defense)
  bool validateShake(double avgShake) {
    return avgShake >= config.config.minShake;
  }

  /// Adakah transaksi ini cukup besar untuk memerlukan CLA?
  bool shouldRequireLock(double amount) {
    return amount >= config.thresholdAmount;
  }

  /// Logic untuk 'Zero Trap' (Rawak)
  int nextTrapIndex(int wheelSize) {
    final rand = Random();
    return rand.nextInt(wheelSize);
  }
}
