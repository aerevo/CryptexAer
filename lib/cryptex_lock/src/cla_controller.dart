/*
 * PROJECT: CryptexLock Security Suite
 * ENGINE: PRO MAX (Original Math + DSP Stability)
 * STATUS: FIXED BUILD ERRORS (Variables restored & Math casted)
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'cla_models.dart';

// ✨ IMPORTS DARI ZIP (Kekal Canggih)
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

  // 🛠️ FIXED: MISSING KEYS RESTORED
  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  // ═══════════════════════════════════════════════════════════
  // 📡 DSP ENGINE (Penapis Isyarat Gred Tentera)
  // ═══════════════════════════════════════════════════════════
  
  final List<double> _rawBuffer = []; // Rolling buffer untuk buang spike
  static const int BUFFER_SIZE = 10;
  static const double NOISE_GATE = 0.5; // Buang bunyi elektrik bawah 0.5
  static const double SMOOTHING = 0.15; // Kelembutan animasi
  
  double _internalSmoothedValue = 0.0;

  // ═══════════════════════════════════════════════════════════
  // 🧬 ADVANCED BIOMETRICS (Logik Asal ZIP Dikembalikan)
  // ═══════════════════════════════════════════════════════════
  
  final List<MotionEvent> _motionHistory = [];
  final Map<String, int> _patternFrequency = {};
  
  double _entropy = 0.0;     // Kekal: Ukur kerawakan pergerakan
  double _variance = 0.0;    // Kekal: Ukur robot vs manusia
  double _liveConfidence = 0.0;
  
  // Touch Metrics (Tambahan untuk kestabilan)
  int _interactionCount = 0;

  double get liveConfidence => _liveConfidence;
  String _threatMessage = "";
  String get threatMessage => _threatMessage;
  
  late MirrorService _mirrorService;

  ClaController(this.config) {
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    
    // Server Init (Dari ZIP)
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
    } catch (e) {
      // Ignore in debug
    }

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
  // 🎛️ PROCESSING PIPELINE (Jantung Utama)
  // ═══════════════════════════════════════════════════════════

  // Dipanggil dari Widget (Touch Event)
  void registerTouchInteraction() {
    if (_state != SecurityState.LOCKED) return;
    _interactionCount++;
    // Sentuhan menyumbang kepada confidence (Human Factor)
    _liveConfidence = (_liveConfidence + 0.1).clamp(0.0, 1.0);
    notifyListeners();
  }

  // Dipanggil dari Widget (Sensor Event)
  void registerShake(double rawMagnitude, double dx, dy, dz) {
    if (_state != SecurityState.LOCKED) return;

    // 1. FILTER: Noise Gate (Buang bacaan hantu < 0.5)
    double cleanMag = rawMagnitude;
    if (cleanMag < NOISE_GATE) cleanMag = 0.0;

    // 2. FILTER: Rolling Average (Buang spike 19.0)
    _rawBuffer.add(cleanMag);
    if (_rawBuffer.length > BUFFER_SIZE) _rawBuffer.removeAt(0);
    double averageMag = _rawBuffer.reduce((a, b) => a + b) / _rawBuffer.length;

    // 3. MATH: Exponential Smoothing (Absorber)
    _internalSmoothedValue = (_internalSmoothedValue * (1 - SMOOTHING)) + (averageMag * SMOOTHING);

    // 4. LOGIC ASAL (ZIP): Simpan sejarah untuk Entropy
    // Kita guna data yang SUDAH DITAPIS (_internalSmoothedValue), bukan raw.
    if (_internalSmoothedValue > 0.1) {
       _addToHistory(_internalSmoothedValue, dx, dy, dz);
    }
    
    // 5. UPDATE UI SCORE (Normalized)
    // Gabungan: Sensor Bersih (60%) + Touch (40%)
    double sensorScore = (_internalSmoothedValue / 10.0).clamp(0.0, 1.0);
    double touchScore = (_interactionCount > 3) ? 1.0 : 0.0;
    
    _liveConfidence = (sensorScore * 0.6) + (touchScore * 0.4);
    
    // Notify untuk UI update
    if (cleanMag > 0.1) notifyListeners(); 
  }

  void _addToHistory(double mag, double dx, dy, dz) {
     if (_motionHistory.length >= 50) _motionHistory.removeAt(0);
     
     _motionHistory.add(MotionEvent(
       magnitude: mag,
       timestamp: DateTime.now(),
       deltaX: dx, deltaY: dy, deltaZ: dz
     ));
     
     _calculateAdvancedBiometrics();
  }

  void _calculateAdvancedBiometrics() {
     if (_motionHistory.isEmpty) return;
     
     // 1. Calculate Variance (Robot vs Human)
     double mean = _motionHistory.map((e) => e.magnitude).reduce((a,b)=>a+b) / _motionHistory.length;
     
     // 🛠️ FIXED: CAST TO DOUBLE (dart:math pow returns num)
     double sumSquaredDiff = _motionHistory.map((e) => pow(e.magnitude - mean, 2).toDouble()).reduce((a,b)=>a+b);
     
     _variance = sumSquaredDiff / _motionHistory.length;
     
     // 2. Calculate Entropy (Randomness)
     _patternFrequency.clear();
     for (var m in _motionHistory) {
       String key = "${m.magnitude.toStringAsFixed(1)}";
       _patternFrequency[key] = (_patternFrequency[key] ?? 0) + 1;
     }
     
     _entropy = 0.0;
     int total = _motionHistory.length;
     _patternFrequency.forEach((k, v) {
       double p = v / total;
       if (p > 0) _entropy -= p * log(p);
     });
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 VALIDATION (SERVER + LOCAL)
  // ═══════════════════════════════════════════════════════════

  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    // CHECK 1: BIOMETRIC QUALITY
    if (config.enableSensors) {
       if (_variance < 0.001 && _interactionCount < 2) {
         await _fail(bot: true, msg: "BOT DETECTED: UNNATURAL MOVEMENT");
         return;
       }
    }

    // CHECK 2: CODE VALIDATION
    if (!_isCodeCorrect()) {
      await _fail(bot: false, msg: "INVALID PASSCODE");
      return;
    }

    // CHECK 3: SERVER VALIDATION (DARI ZIP)
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
          uniqueGestureCount: _interactionCount,
          interactionTimeMs: 2000,
          zkProof: zkProof,
          motionSignature: MotionSignature.generate(
            entropy: _entropy,
            variance: _variance,
            gestureCount: _interactionCount,
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
    _interactionCount = 0;
    _liveConfidence = 0.0;
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
