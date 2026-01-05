import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart'; // Anjing Penjaga
import 'cla_config.dart';
import 'cla_state.dart';
import 'cla_audit.dart';

class ClaController {
  final ClaConfig config;
  final ClaState state = ClaState();
  final DateTime _startTime = DateTime.now();

  double _accumulatedShake = 0;
  bool _isCompromised = false; // Status Root

  ClaController(this.config) {
    _initSecurity(); // Bangunkan Anjing Penjaga!
  }

  // --- ANJING PENJAGA (ROOT DETECTION) ---
  Future<void> _initSecurity() async {
    try {
      bool jailed = await FlutterJailbreakDetection.jailbroken;
      bool devMode = await FlutterJailbreakDetection.developerMode;
      
      if (jailed || devMode) {
        _isCompromised = true;
        ClaAudit.log('SECURITY ALERT: Root/Dev Mode Detected');
        state.jam(); // Terus Jammed jika Root
      }
    } catch (e) {
      if (kDebugMode) print("Security check error: $e");
    }
  }

  // --- SENSOR LOGIC ---
  void registerShake(double value) {
    if (state.jammed) return;
    _accumulatedShake += value.abs();
  }

  bool validateTime() =>
      DateTime.now().difference(_startTime) >= config.minSolveTime;

  bool validateShake() =>
      !config.enableSensors || _accumulatedShake >= config.minShake;

  bool validateSecret(List<int> input) =>
      input.join() == config.secret.join();

  // --- OTAK UTAMA ---
  bool attempt(List<int> input) {
    // 1. Cek Root Dulu
    if (_isCompromised) {
      ClaAudit.log('FAILED: Device Compromised');
      return false;
    }

    if (state.jammed) return false;

    // 2. Cek Fizikal (Masa & Gegaran)
    // ChatGPT buang ni tadi, saya masukkan balik!
    if (!validateTime() || !validateShake()) {
      ClaAudit.log('FAILED: Human Physics Check (Shake: ${_accumulatedShake.toStringAsFixed(2)})');
      state.recordFail();
      return false;
    }

    // 3. Cek Nombor
    if (!validateSecret(input)) {
      ClaAudit.log('FAILED: Wrong Code');
      state.recordFail();
      
      if (state.failedAttempts >= 5) {
        state.jam();
        ClaAudit.log('SYSTEM JAMMED: Too many attempts');
      }
      return false;
    }

    ClaAudit.log('UNLOCK SUCCESS: Verified Human');
    state.reset();
    return true;
  }
}
