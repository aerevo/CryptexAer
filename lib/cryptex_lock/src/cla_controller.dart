import 'dart:async';
import 'cla_config.dart';
import 'cla_state.dart';
import 'cla_audit.dart';

class ClaController {
  final ClaConfig config;
  final ClaState state = ClaState(); // Guna State baru (Bank Grade)
  final DateTime _startTime = DateTime.now();

  double _accumulatedShake = 0;

  ClaController(this.config);

  // --- FUNGSI YANG HILANG TADI ---
  void registerShake(double value) {
    _accumulatedShake += value.abs();
  }

  bool validateTime() =>
      DateTime.now().difference(_startTime) >= config.minSolveTime;

  bool validateShake() =>
      !config.enableSensors || _accumulatedShake >= config.minShake;

  bool validateSecret(List<int> input) =>
      input.join() == config.secret.join();

  // --- FUNGSI ATTEMPT (OTAK UTAMA) ---
  bool attempt(List<int> input) {
    if (state.jammed) return false;

    // Cek Sensor & Masa
    if (!validateTime() || !validateShake()) {
      ClaAudit.log('FAILED: Time/Shake insufficient (Shake: $_accumulatedShake)');
      state.recordFail();
      return false;
    }

    // Cek Nombor
    if (!validateSecret(input)) {
      ClaAudit.log('FAILED: Secret mismatch');
      state.recordFail();
      
      // Auto-Jam selepas 5 kali salah
      if (state.failedAttempts >= 5) {
        state.jam();
        ClaAudit.log('SYSTEM JAMMED');
      }
      return false;
    }

    ClaAudit.log('UNLOCK SUCCESS');
    state.reset();
    return true;
  }
  
  // Helper untuk reset jika perlu
  void userAcceptsRisk() {
    state.reset();
  }
}
