// 🎮 Z-KINETIC CONTROLLER V4.0 - THE UNBRICKER
// Status: EMERGENCY UNLOCK ✅
// Fix: Auto-clears 'Hard Lock' on startup so you can test again.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cla_models.dart';
import 'security_engine.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;
  late final SecurityEngine _engine;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // State
  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  DateTime? _lockoutUntil;
  late List<int> currentValues;
  
  // Telemetry
  String _threatMessage = "";
  String get threatMessage => _threatMessage;
  
  // Getters untuk UI Claude
  double get liveConfidence => _engine.lastConfidenceScore;
  double get motionConfidence => _engine.lastEntropyScore; 
  double get touchConfidence => _engine.lastConfidenceScore; 

  final List<MotionEvent> _motionHistory = [];
  int _touchCount = 0;
  DateTime? _interactionStart;

  ClaController(this.config) {
    currentValues = List.filled(5, 0);
    _engine = SecurityEngine(config.engineConfig);
    
    // 🔥 EMERGENCY FIX: PADAM SEMUA MEMORI LAMA (UNBRICK)
    // Ini akan membuang status "Data Breach/Lockdown" setiap kali app buka.
    _emergencyUnlock();
  }
  
  Future<void> _emergencyUnlock() async {
    await _storage.deleteAll(); // Padam rekod lockout
    _state = SecurityState.LOCKED; // Reset ke status asal
    _failedAttempts = 0;
    _threatMessage = "";
    notifyListeners();
    print("🔓 SYSTEM UNBRICKED: SECURE STORAGE CLEARED");
    
    // Init biasa
    _initSecureStorage();
  }

  // --- SENSOR INPUT ADAPTERS ---

  void registerShake(double rawMag, double x, double y, double z) {
    onMotion(x, y, z);
  }

  void registerTouch() {
    onTouch();
  }
  
  void updateWheel(int index, int value) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      notifyListeners();
    }
  }
  
  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) {
      return currentValues[index];
    }
    return 0;
  }
  
  Future<bool> validateAttempt({bool hasPhysicalMovement = true}) async {
    return attemptUnlock();
  }

  // --- INTERNAL LOGIC ---

  void onMotion(double x, double y, double z) {
    if (!config.enableSensors) return;
    
    final mag = x.abs() + y.abs() + z.abs();
    _motionHistory.add(MotionEvent(
      magnitude: mag, 
      timestamp: DateTime.now(),
      deltaX: x, deltaY: y, deltaZ: z
    ));
    
    if (_motionHistory.length > 50) _motionHistory.removeAt(0);
  }

  void onInteractionStart() {
    _interactionStart = DateTime.now();
    _touchCount = 0;
    _motionHistory.clear();
  }

  void onTouch() {
    _touchCount++;
  }

  // --- CORE LOGIC ---

  Future<bool> attemptUnlock() async {
    // Check Lockout
    if (_state == SecurityState.HARD_LOCK) {
       _threatMessage = "SYSTEM LOCKED";
       notifyListeners();
       return false;
    }

    _state = SecurityState.VALIDATING;
    notifyListeners();

    final duration = DateTime.now().difference(_interactionStart ?? DateTime.now());
    
    // Panggil Engine
    final verdict = _engine.analyze(
      motionHistory: _motionHistory, 
      touchCount: _touchCount, 
      interactionDuration: duration
    );

    if (!verdict.allowed) {
      _handleBotDetection(verdict);
      return false;
    }

    bool isPassCorrect = listEquals(currentValues, config.secret);
    
    if (isPassCorrect) {
      _handleSuccess();
      return true;
    } else {
      _handleFailure();
      return false;
    }
  }

  // --- HANDLERS ---

  void _handleBotDetection(ThreatVerdict verdict) {
    _threatMessage = "ALERT: ${verdict.reason}";
    // 🔥 FIX: Jangan hard lock terus. Soft lock 2 saat je.
    _state = SecurityState.SOFT_LOCK; 
    notifyListeners();
    
    Future.delayed(const Duration(seconds: 2), () {
      if (_state == SecurityState.SOFT_LOCK) {
        _state = SecurityState.LOCKED;
        _threatMessage = "";
        notifyListeners();
      }
    });
  }

  void _handleSuccess() {
    _state = SecurityState.UNLOCKED;
    _failedAttempts = 0;
    _threatMessage = "";
    _clearSecureStorage();
    notifyListeners();
  }

  Future<void> _handleFailure() async {
    _failedAttempts++;
    _state = SecurityState.LOCKED;
    _threatMessage = "WRONG PASSCODE";
    
    // 🔥 FIX: Naikkan limit attempt supaya Kapten tak stress masa testing
    if (_failedAttempts >= 10) { 
      _triggerHardLockout();
    } else {
      _saveSecureStorage();
    }
    notifyListeners();
  }

  Future<void> _triggerHardLockout() async {
    _state = SecurityState.HARD_LOCK;
    _lockoutUntil = DateTime.now().add(config.jamCooldown);
    _threatMessage = "SYSTEM HALTED";
    await _saveSecureStorage();
    notifyListeners();

    Timer(config.jamCooldown, () {
      if (_state == SecurityState.HARD_LOCK) {
        _resetLockout();
      }
    });
  }

  void _resetLockout() {
    _state = SecurityState.LOCKED;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _threatMessage = "";
    _clearSecureStorage();
    notifyListeners();
  }
  
  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    return max(0, _lockoutUntil!.difference(DateTime.now()).inSeconds);
  }

  // --- PERSISTENCE ---

  Future<void> _initSecureStorage() async {
    // Logik asal dikekalkan, tapi _emergencyUnlock dah padam data dulu
    final attempts = await _storage.read(key: 'cla_attempts');
    if (attempts != null) _failedAttempts = int.parse(attempts);
  }

  Future<void> _saveSecureStorage() async {
    await _storage.write(key: 'cla_attempts', value: _failedAttempts.toString());
    if (_lockoutUntil != null) {
      await _storage.write(key: 'cla_lockout', value: _lockoutUntil!.millisecondsSinceEpoch.toString());
    }
  }

  Future<void> _clearSecureStorage() async {
    await _storage.deleteAll();
  }
}
