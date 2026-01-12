// 🎮 Z-KINETIC CONTROLLER V5.4.1 - "THE BALANCED GUARDIAN"
// Fix: Removed "CRITICAL" keyword auto-lock.
// Feature: Contextual Metrics (Tilt/Velocity) for Data Collection.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cla_models.dart';
import 'security_engine.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;
  late final SecurityEngine _engine;
  late final FlutterSecureStorage _storage;

  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  DateTime? _lockoutUntil;
  late List<int> currentValues;

  double _motionConfidence = 0.0;
  double _touchConfidence = 0.0;
  int _touchCount = 0;

  // Contextual Metrics
  final List<double> _wheelVelocities = [];
  double _lastTiltX = 0.0;
  double _lastTiltY = 0.0;
  DateTime? _lastWheelUpdateTime;

  double get motionConfidence => _motionConfidence;
  double get touchConfidence => _touchConfidence;
  
  double get liveConfidence => _engine.lastConfidenceScore;
  double get motionEntropy => _engine.lastEntropyScore;
  
  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  final List<MotionEvent> _motionHistory = [];

  ClaController(this.config) {
    currentValues = List.filled(5, 0);
    
    _engine = SecurityEngine(
      const SecurityEngineConfig(),
    );
    _storage = const FlutterSecureStorage();
    _initSecureStorage();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  void registerShake(double magnitude, double x, double y, double z) {
    final now = DateTime.now();
    _lastTiltX = x;
    _lastTiltY = y;

    _motionHistory.add(MotionEvent(
      magnitude: magnitude,
      timestamp: now,
      deltaX: x,
      deltaY: y,
      deltaZ: z,
    ));
    
    if (_motionHistory.length > 60) _motionHistory.removeAt(0);

    if (magnitude > config.minShake) {
      _motionConfidence = (_motionConfidence + 0.12).clamp(0.0, 1.0);
    } else {
      _motionConfidence = (_motionConfidence - 0.04).clamp(0.0, 1.0);
    }
    
    if (_motionHistory.length % 5 == 0) _notify(); 
  }

  void updateWheel(int index, int val) {
    if (index >= 0 && index < currentValues.length) {
      final now = DateTime.now();
      
      if (_lastWheelUpdateTime != null) {
        final diff = now.difference(_lastWheelUpdateTime!).inMilliseconds;
        if (diff > 0) {
          double velocity = 1000 / diff; 
          _wheelVelocities.add(velocity);
          if (_wheelVelocities.length > 25) _wheelVelocities.removeAt(0);
        }
      }
      
      _lastWheelUpdateTime = now;
      currentValues[index] = val;
      _touchCount++;
      _touchConfidence = 1.0;
      _notify(); 
    }
  }

  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.HARD_LOCK) return;
    if (_state == SecurityState.VALIDATING) return;

    _state = SecurityState.VALIDATING;
    _notify();

    final verdict = _engine.analyze(
      motionConfidence: _motionConfidence,
      touchConfidence: _touchConfidence,
      motionHistory: _motionHistory,
      touchCount: _touchCount,
    );
    
    await Future.delayed(const Duration(milliseconds: 400));

    // ✅ Priority 1: Password Check
    if (_checkCode()) {
      _recordBiometricProfile(verdict.allowed);
      _state = SecurityState.UNLOCKED;
      _notify();
      await _clearSecure();
      return; 
    }

    // ❌ Priority 2: Fail Handling (Safe Logic Applied)
    await _fail(verdict.allowed ? "INCORRECT PASSCODE" : "INCORRECT PASSCODE + ${verdict.reason}");
  }

  void _recordBiometricProfile(bool sensorPassed) {
    if (kDebugMode) {
      double avgVelocity = _wheelVelocities.isEmpty 
          ? 0 
          : _wheelVelocities.reduce((a, b) => a + b) / _wheelVelocities.length;

      print("\n--- 🛡️ [Z-KINETIC V5.4.1 AUDIT] ---");
      print("Status: AUTHORIZED");
      print("Sensor Match: ${sensorPassed ? 'YES' : 'NO'}");
      print("Profile Metrics:");
      print("  > Entropy:  ${_engine.lastEntropyScore.toStringAsFixed(4)}");
      print("  > Variance: ${_engine.lastVarianceScore.toStringAsFixed(4)}");
      print("  > Tremor:   ${_engine.lastTremorHz.toStringAsFixed(2)} Hz");
      print("  > Wheel Spd: ${avgVelocity.toStringAsFixed(2)} p/s");
      print("  > Tilt: X=${_lastTiltX.toStringAsFixed(2)}, Y=${_lastTiltY.toStringAsFixed(2)}");
      print("---------------------------------\n");
    }
    _wheelVelocities.clear();
  }

  bool _checkCode() {
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }

  Future<void> _fail(String reason) async {
    _failedAttempts++;
    _threatMessage = reason;
    await _saveSecure();

    // ✅ FIXED: Only lock out based on attempts count.
    if (_failedAttempts >= config.maxAttempts) {
      _state = SecurityState.HARD_LOCK;
      _lockoutUntil = DateTime.now().add(config.jamCooldown);
      await _saveSecure();
    } else {
      _state = SecurityState.SOFT_LOCK;
      Timer(const Duration(seconds: 2), () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
          _threatMessage = ""; 
          _notify();
        }
      });
    }
    _notify();
  }

  void userAcceptsRisk() {
    _state = SecurityState.LOCKED;
    _notify();
  }

  void _notify() {
    if (hasListeners) notifyListeners();
  }

  static const _K_ATTEMPTS = 'cla_attempts';
  static const _K_LOCKOUT = 'cla_lockout';

  Future<void> _initSecureStorage() async {
    final a = await _storage.read(key: _K_ATTEMPTS);
    _failedAttempts = int.tryParse(a ?? '0') ?? 0;
    final t = await _storage.read(key: _K_LOCKOUT);
    if (t != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(int.parse(t));
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
        _notify();
      } else {
        _clearSecure();
      }
    }
  }

  Future<void> _saveSecure() async {
    await _storage.write(key: _K_ATTEMPTS, value: '$_failedAttempts');
    if (_lockoutUntil != null) {
      await _storage.write(key: _K_LOCKOUT, value: _lockoutUntil!.millisecondsSinceEpoch.toString());
    }
  }

  Future<void> _clearSecure() async {
    await _storage.delete(key: _K_ATTEMPTS);
    await _storage.delete(key: _K_LOCKOUT);
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  int getInitialValue(int index) {
     if (index >= 0 && index < currentValues.length) return currentValues[index];
     return 0;
  }
  
  int get remainingLockoutSeconds =>
      _lockoutUntil == null ? 0 : _lockoutUntil!.difference(DateTime.now()).inSeconds;
}
