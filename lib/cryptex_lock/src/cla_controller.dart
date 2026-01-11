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

  double get motionConfidence => _motionConfidence;
  double get touchConfidence => _touchConfidence;
  
  // FIX 1: Panggil getter dari variable baru engine
  double get liveConfidence => _engine.lastConfidenceScore;
  int get uniqueGestureCount => _motionHistory.length > 50 ? 10 : (_motionHistory.length / 5).floor();
  double get motionEntropy => _engine.lastEntropyScore;
  
  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  final List<MotionEvent> _motionHistory = [];

  ClaController(this.config) {
    currentValues = List.filled(5, 0);
    
    // FIX 2: Constructor dibetulkan (Buang parameter secret)
    _engine = SecurityEngine(
      const SecurityEngineConfig(
        minEntropy: 0.35,     
        minVariance: 0.02,
        minConfidence: 0.55,
      ),
      // config.secret DIBUANG
    );
    _storage = const FlutterSecureStorage();
    _initSecureStorage();
  }

  @override
  void dispose() {
    // FIX 3: Engine sekarang ada method dispose, jadi line ini valid
    _engine.dispose();
    super.dispose();
  }

  void registerShake(double magnitude, double x, double y, double z) {
    final now = DateTime.now();
    _motionHistory.add(MotionEvent(magnitude, now, x, y, z));
    if (_motionHistory.length > 50) _motionHistory.removeAt(0);

    if (magnitude > config.minShake) {
      _motionConfidence = (_motionConfidence + 0.1).clamp(0.0, 1.0);
    } else {
      _motionConfidence = (_motionConfidence - 0.05).clamp(0.0, 1.0);
    }
    
    if (_motionHistory.length % 5 == 0) _notify(); 
  }

  void registerTouch() {
    _touchCount++;
    _touchConfidence = 1.0;
  }
  
  void registerTouchInteraction() {
    registerTouch();
  }

  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.HARD_LOCK) return;
    if (_state == SecurityState.VALIDATING) return;

    _state = SecurityState.VALIDATING;
    _notify();

    // Jalankan analisis (Untuk rekod visual sahaja)
    final verdict = _engine.analyze(
      motionConfidence: _motionConfidence,
      touchConfidence: _touchConfidence,
      motionHistory: _motionHistory,
      touchCount: _touchCount,
    );
    
    await Future.delayed(const Duration(milliseconds: 300));

    print("🔐 PRIORITY CHECK: VERIFYING PASSCODE FIRST...");

    // UTAMA: Cek Password DULU (Safe-Unlock Logic)
    if (_checkCode()) {
      print("✅ PASSCODE MATCH. OVERRIDING SENSOR VERDICT.");
      _state = SecurityState.UNLOCKED;
      _notify();
      await _clearSecure();
      return; 
    }

    // Kalau password salah, baru hukum
    print("❌ PASSCODE MISMATCH. CHECKING THREAT LEVEL...");

    if (!verdict.allowed) {
      await _fail("CRITICAL: ${verdict.reason} + WRONG PIN");
    } else {
      await _fail("INCORRECT PIN");
    }
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

    if (_failedAttempts >= config.maxAttempts) {
      _state = SecurityState.HARD_LOCK;
      _lockoutUntil = DateTime.now().add(config.jamCooldown);
      await _saveSecure();
    } else {
      _state = SecurityState.SOFT_LOCK;
      Timer(const Duration(seconds: 1), () {
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

  // ================= STORAGE & INIT =================
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
      await _storage.write(
          key: _K_LOCKOUT,
          value: _lockoutUntil!.millisecondsSinceEpoch.toString());
    }
  }

  Future<void> _clearSecure() async {
    await _storage.delete(key: _K_ATTEMPTS);
    await _storage.delete(key: _K_LOCKOUT);
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  void updateWheel(int index, int val) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = val;
      _notify(); 
    }
  }

  int getInitialValue(int index) {
     if (index >= 0 && index < currentValues.length) {
       return currentValues[index];
     }
     return 0;
  }
  
  int get remainingLockoutSeconds =>
      _lockoutUntil == null
          ? 0
          : _lockoutUntil!.difference(DateTime.now()).inSeconds;
}
