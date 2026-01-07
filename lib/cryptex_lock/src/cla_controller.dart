/*
 * PROJECT: CryptexLock Security Suite
 * ENGINE: CLASSIC MOTION (Accelerometer Driven)
 * FILTER: DSP ENABLED (No Jitter)
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'cla_models.dart';

// SERVER SECURITY IMPORTS
import 'security/models/secure_payload.dart';
import 'security/services/mirror_service.dart';
import 'security/services/device_fingerprint.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  DateTime? _lockoutUntil;
  late List<int> currentValues;
  
  // FIXED: MISSING KEYS RESTORED
  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  // ═══════════════════════════════════════════════════════════
  // 📡 DSP ENGINE (PENAPIS GEGARAN)
  // ═══════════════════════════════════════════════════════════
  // Ini rahsia supaya sensor tak gila (0-19).
  
  final List<double> _rawBuffer = []; 
  static const int BUFFER_SIZE = 10;     // Purata 10 frame (Smooth)
  static const double NOISE_GATE = 0.3;  // Abaikan getaran meja (<0.3)
  static const double SMOOTHING = 0.1;   // Gerakan bar macam air (Liquid)
  static const double MAX_SHAKE = 8.0;   // Nilai gegaran maksimum untuk 100%
  
  double _internalSmoothedValue = 0.0;   // Nilai yang dah bersih

  // ═══════════════════════════════════════════════════════════
  // 🧬 METRICS
  // ═══════════════════════════════════════════════════════════
  
  final List<MotionEvent> _motionHistory = [];
  double _entropy = 0.0;
  double _variance = 0.0;
  
  // UI SCORES
  double _motionConfidence = 0.0; // Bar Besar (Utama)
  double _touchConfidence = 0.0;  // Meter Kecil (Secondary)
  int _touchCount = 0;

  double get motionConfidence => _motionConfidence;
  double get touchConfidence => _touchConfidence;
  
  String _threatMessage = "";
  String get threatMessage => _threatMessage;
  
  late MirrorService _mirrorService;

  ClaController(this.config) {
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    
    if (config.hasServerValidation) {
      _mirrorService = MirrorService(
        endpoint: config.securityConfig!.serverEndpoint,
        timeout: config.securityConfig!.serverTimeout,
      );
    }
    _initSecurityProtocol();
  }

  Future<void> _initSecurityProtocol() async {
    bool isRooted = false;
    try {
      isRooted = await FlutterJailbreakDetection.jailbroken;
    } catch (e) { /* Ignore */ }

    if (isRooted) {
      _threatMessage = "CRITICAL: K9 WATCHDOG ALERT";
      _state = SecurityState.ROOT_WARNING;
      notifyListeners();
      return;
    }
    await _loadState();
  }
  
  void userAcceptsRisk() {
    _state = SecurityState.LOCKED;
    notifyListeners();
    _loadState();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎛️ INPUT LOGIC (ACCELEROMETER IS KING)
  // ═══════════════════════════════════════════════════════════

  // 1. SENSOR INPUT (UTAMA - MENGGERAKKAN BAR BESAR)
  void registerShake(double rawMagnitude, double dx, dy, dz) {
    if (_state != SecurityState.LOCKED) return;

    // A. NOISE GATE (Buang sampah)
    double cleanMag = rawMagnitude;
    if (cleanMag < NOISE_GATE) cleanMag = 0.0;

    // B. ROLLING AVERAGE (Buang spike)
    _rawBuffer.add(cleanMag);
    if (_rawBuffer.length > BUFFER_SIZE) _rawBuffer.removeAt(0);
    double averageMag = _rawBuffer.reduce((a, b) => a + b) / _rawBuffer.length;

    // C. SMOOTHING (Absorber)
    _internalSmoothedValue = (_internalSmoothedValue * (1 - SMOOTHING)) + (averageMag * SMOOTHING);

    // D. UPDATE UI (Normalize 0.0 - 1.0)
    // Kalau gegaran cecah 8.0, bar penuh.
    _motionConfidence = (_internalSmoothedValue / MAX_SHAKE).clamp(0.0, 1.0);

    // E. REKOD SEJARAH (Untuk Server)
    if (_internalSmoothedValue > 0.1) {
       _addToHistory(_internalSmoothedValue, dx, dy, dz);
    }
    
    notifyListeners(); 
  }

  // 2. TOUCH INPUT (SECONDARY - METER KECIL)
  void registerTouch() {
    if (_state != SecurityState.LOCKED) return;
    _touchCount++;
    // Meter kecil naik cepat sikit
    _touchConfidence = (_touchCount / 5.0).clamp(0.0, 1.0);
    notifyListeners();
  }

  void _addToHistory(double mag, double dx, dy, dz) {
     if (_motionHistory.length >= 50) _motionHistory.removeAt(0);
     
     _motionHistory.add(MotionEvent(
       magnitude: mag,
       timestamp: DateTime.now(),
       deltaX: dx, deltaY: dy, deltaZ: dz
     ));
     
     // Kira matematik server (Variance/Entropy)
     _calculateMetrics();
  }

  void _calculateMetrics() {
     if (_motionHistory.isEmpty) return;
     
     // Variance Logic
     double mean = _motionHistory.map((e) => e.magnitude).reduce((a,b)=>a+b) / _motionHistory.length;
     // Fixed: Cast pow result to double
     double sumSquaredDiff = _motionHistory.map((e) => pow(e.magnitude - mean, 2).toDouble()).reduce((a,b)=>a+b);
     _variance = sumSquaredDiff / _motionHistory.length;
     
     // Entropy Logic
     Map<String, int> freq = {};
     for (var m in _motionHistory) {
       String key = "${m.magnitude.toStringAsFixed(1)}";
       freq[key] = (freq[key] ?? 0) + 1;
     }
     
     _entropy = 0.0;
     int total = _motionHistory.length;
     freq.forEach((k, v) {
       double p = v / total;
       if (p > 0) _entropy -= p * log(p);
     });
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 VALIDATION
  // ═══════════════════════════════════════════════════════════

  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));

    // CHECK 1: DEAD CHECK
    // Mesti ada pergerakan ATAU sentuhan. Kalau kaku 100%, reject.
    if (_motionConfidence < 0.05 && _touchConfidence < 0.1) {
       await _fail(bot: true, msg: "NO ACTIVITY DETECTED");
       return;
    }

    // CHECK 2: CODE VALIDATION
    if (!_isCodeCorrect()) {
      await _fail(bot: false, msg: "INVALID PASSCODE");
      return;
    }

    // CHECK 3: SERVER VALIDATION (INTEGRATED)
    if (config.hasServerValidation) {
      try {
        final deviceId = await DeviceFingerprint.getDeviceId();
        final nonce = DeviceFingerprint.generateNonce();
        final secretStr = await DeviceFingerprint.getDeviceSecret();
        
        // Zero-Knowledge Proof
        final zkProof = ZeroKnowledgeProof.generate(
          userCode: currentValues,
          nonce: nonce,
          deviceSecret: secretStr,
        );

        final payload = SecurePayload(
          deviceId: deviceId,
          appSignature: await DeviceFingerprint.getAppSignature(),
          nonce: nonce,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          entropy: _entropy, 
          averageMagnitude: _internalSmoothedValue,
          frequencyVariance: _variance,
          uniqueGestureCount: _touchCount,
          interactionTimeMs: 2000,
          zkProof: zkProof,
          motionSignature: MotionSignature.generate(
            entropy: _entropy,
            variance: _variance,
            gestureCount: _touchCount,
          ), 
          tremorHz: 10.0,
        );

        final verdict = await _mirrorService.verify(payload);
        if (!verdict.allowed) {
          await _fail(bot: true, msg: "SERVER DENIED: ${verdict.reason}");
          return;
        }
      } catch (e) {
        if (!config.securityConfig!.allowOfflineFallback) {
           await _fail(bot: false, msg: "SERVER UNREACHABLE");
           return;
        }
      }
    }

    // UNLOCK SUCCESS
    await _clearMemory();
    _state = SecurityState.UNLOCKED;
    _threatMessage = "";
    notifyListeners();
  }

  Future<void> _fail({required bool bot, required String msg}) async {
    _failedAttempts++;
    _threatMessage = msg;
    if (bot || _failedAttempts >= config.maxAttempts) {
      _state = SecurityState.HARD_LOCK;
      _lockoutUntil = DateTime.now().add(config.jamCooldown);
    } else {
      _state = SecurityState.SOFT_LOCK;
      Future.delayed(config.softLockCooldown, () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
          _threatMessage = "";
          notifyListeners();
        }
      });
    }
    await _saveState();
    notifyListeners();
  }

  bool _isCodeCorrect() {
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }
  
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt(KEY_ATTEMPTS) ?? 0;
    final lockTs = prefs.getInt(KEY_LOCKOUT);
    if (lockTs != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockTs);
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
        notifyListeners();
      }
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(KEY_ATTEMPTS, _failedAttempts);
    if (_lockoutUntil != null) {
      await prefs.setInt(KEY_LOCKOUT, _lockoutUntil!.millisecondsSinceEpoch);
    }
  }

  Future<void> _clearMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(KEY_ATTEMPTS);
    await prefs.remove(KEY_LOCKOUT);
    _failedAttempts = 0;
    _internalSmoothedValue = 0;
    _motionHistory.clear();
    _touchCount = 0;
    _motionConfidence = 0.0;
    _touchConfidence = 0.0;
    _lockoutUntil = null;
    _state = SecurityState.LOCKED;
  }

  void updateWheel(int index, int value) {
    if (_state != SecurityState.LOCKED) return;
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      notifyListeners();
    }
  }

  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) return currentValues[index];
    return 0;
  }

  int get remainingLockoutSeconds =>
      _lockoutUntil == null ? 0 : _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
}
