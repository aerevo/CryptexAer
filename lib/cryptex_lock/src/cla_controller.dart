// 🎮 Z-KINETIC CONTROLLER (SYNCED V3.0)
// Status: BUG FIXED ✅
// Role: Orchestrator. Uses 'engineConfig' correctly now.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cla_models.dart';
import 'security_engine.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;
  late final SecurityEngine _engine; // Otak
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
  double get liveConfidence => _engine.lastConfidenceScore;

  final List<MotionEvent> _motionHistory = [];
  int _touchCount = 0;
  DateTime? _interactionStart;

  ClaController(this.config) {
    currentValues = List.filled(5, 0);
    
    // ✅ FIX: Inilah puncanya dulu. Sekarang 'config.engineConfig' wujud!
    _engine = SecurityEngine(config.engineConfig);
    
    _initSecureStorage();
  }

  // --- SENSOR INPUT ---

  void onMotion(double x, double y, double z) {
    if (!config.enableSensors) return;
    
    final mag = x.abs() + y.abs() + z.abs(); // Simplified magnitude
    _motionHistory.add(MotionEvent(
      magnitude: mag, 
      timestamp: DateTime.now(),
      deltaX: x, deltaY: y, deltaZ: z
    ));
    
    // Keep clean memory
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

  // --- CORE LOGIC (UNLOCK ATTEMPT) ---

  Future<bool> attemptUnlock() async {
    // 1. Check Hard Lockout (Persistence)
    if (_state == SecurityState.HARD_LOCK) {
      if (_lockoutUntil != null && DateTime.now().isAfter(_lockoutUntil!)) {
        _resetLockout();
      } else {
        _threatMessage = "SYSTEM LOCKED";
        notifyListeners();
        return false;
      }
    }

    _state = SecurityState.VALIDATING;
    notifyListeners();

    // 2. ANALISIS BOT (ENGINE FIRST) 🛡️
    // Kita check bot DULU sebelum check password.
    final duration = DateTime.now().difference(_interactionStart ?? DateTime.now());
    
    final verdict = _engine.analyze(
      motionHistory: _motionHistory, 
      touchCount: _touchCount, 
      interactionDuration: duration
    );

    if (!verdict.allowed) {
      // 🚨 BOT DIKESAN!
      _handleBotDetection(verdict);
      return false;
    }

    // 3. PASSWORD CHECK (Jika lulus bot check)
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
    _threatMessage = "SECURITY ALERT: ${verdict.reason}";
    _state = SecurityState.SOFT_LOCK; // Kunci sekejap
    notifyListeners();
    
    // Auto-reset soft lock
    Future.delayed(config.softLockCooldown, () {
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
    _threatMessage = "INVALID CODE";
    
    if (_failedAttempts >= config.maxAttempts) {
      _triggerHardLockout();
    } else {
      _saveSecureStorage(); // Simpan attempt count
    }
    notifyListeners();
  }

  Future<void> _triggerHardLockout() async {
    _state = SecurityState.HARD_LOCK;
    _lockoutUntil = DateTime.now().add(config.jamCooldown);
    _threatMessage = "MAX ATTEMPTS REACHED";
    await _saveSecureStorage();
    notifyListeners();

    // Timer unlock
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

  // --- PERSISTENCE (SECURE STORAGE) ---

  Future<void> _initSecureStorage() async {
    final attempts = await _storage.read(key: 'cla_attempts');
    if (attempts != null) _failedAttempts = int.parse(attempts);
    
    final lockout = await _storage.read(key: 'cla_lockout');
    if (lockout != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(int.parse(lockout));
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
      } else {
        _resetLockout();
      }
    }
    notifyListeners();
  }

  Future<void> _saveSecureStorage() async {
    await _storage.write(key: 'cla_attempts', value: _failedAttempts.toString());
    if (_lockoutUntil != null) {
      await _storage.write(key: 'cla_lockout', value: _lockoutUntil!.millisecondsSinceEpoch.toString());
    }
  }

  Future<void> _clearSecureStorage() async {
    await _storage.delete(key: 'cla_attempts');
    await _storage.delete(key: 'cla_lockout');
  }
}
