/*
 * PROJECT: CryptexLock Security Suite
 * ENGINE: HYBRID DSP + AAA Biometrics
 * STATUS: PRODUCTION GRADE - Sensor Stable + Time Decay Confidence
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'cla_models.dart';

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

  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  // ═══════════════════════════════════════════════════════════
  // 📡 DSP ENGINE (Sensor Signal Processing)
  // ═══════════════════════════════════════════════════════════
  
  final List<double> _rawSensorBuffer = [];
  static const int BUFFER_SIZE = 12;
  static const double NOISE_GATE = 0.8;
  static const double MAX_REASONABLE_SHAKE = 7.0;

  // ═══════════════════════════════════════════════════════════
  // 🧬 BIOMETRIC STATE (AAA Architecture)
  // ═══════════════════════════════════════════════════════════
  
  final List<MotionEvent> _motionHistory = [];
  final List<double> _magnitudeBuffer = [];
  final List<DateTime> _motionTimestamps = [];
  final Map<String, int> _patternFrequency = {};

  double _accumulatedShake = 0;
  double _frequencyVariance = 0;
  double _entropy = 0.0;
  int _uniquePatternCount = 0;

  // Session Control
  DateTime? _sessionStartTime;
  DateTime? _lastInteractionTime;
  Duration _activeInteraction = Duration.zero;

  BiometricSignature? _lastSignature;
  bool _quietSuspicion = false;

  static const int MAX_HISTORY_SIZE = 100;
  static const double ELECTRONIC_NOISE_FLOOR = 0.15;

  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  late MirrorService _mirrorService;

  ClaController(this.config) {
    final rand = Random();
    currentValues = List.generate(5, (_) => rand.nextInt(10));
    _sessionStartTime = DateTime.now();
    
    if (config.hasServerValidation) {
      _mirrorService = MirrorService(
        endpoint: config.securityConfig!.serverEndpoint,
        timeout: config.securityConfig!.serverTimeout,
      );
    }
    
    _initSecurityProtocol();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 SECURITY BOOTSTRAP
  // ═══════════════════════════════════════════════════════════

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
    _threatMessage = "";
    notifyListeners();
    _loadState();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 PUBLIC API (Widget Interface)
  // ═══════════════════════════════════════════════════════════

  int _wheelTouchCount = 0;

  /// Bridge method for legacy widget support
  void registerTouchInteraction() {
    _registerInteraction();
    _wheelTouchCount++;
    notifyListeners();
  }

  void updateWheel(int index, int value) {
    if (_state != SecurityState.LOCKED) return;
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      _registerInteraction();
      _wheelTouchCount++;
      notifyListeners();
    }
  }
  
  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) return currentValues[index];
    return 0;
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 MOTION INPUT PROCESSING (DSP + Biometric Fusion)
  // ═══════════════════════════════════════════════════════════

  void registerShake(double rawMagnitude, double dx, double dy, double dz) {
    if (_state != SecurityState.LOCKED) return;

    // STAGE 1: DSP Filtering (Hardware noise removal)
    double cleanMag = rawMagnitude.clamp(0.0, MAX_REASONABLE_SHAKE);
    if (cleanMag < NOISE_GATE) cleanMag = 0.0;

    // STAGE 2: Rolling average (spike suppression)
    _rawSensorBuffer.add(cleanMag);
    if (_rawSensorBuffer.length > BUFFER_SIZE) _rawSensorBuffer.removeAt(0);
    
    double filteredMag = _rawSensorBuffer.isEmpty ? 0.0 :
        _rawSensorBuffer.reduce((a, b) => a + b) / _rawSensorBuffer.length;

    // STAGE 3: Only process significant motion
    if (filteredMag < ELECTRONIC_NOISE_FLOOR) return;

    // STAGE 4: Biometric recording
    final now = DateTime.now();
    _registerInteraction();

    final event = MotionEvent(
      magnitude: filteredMag,
      timestamp: now,
      deltaX: dx,
      deltaY: dy,
      deltaZ: dz,
    );

    _motionHistory.add(event);
    _magnitudeBuffer.add(filteredMag);
    _motionTimestamps.add(now);

    if (_motionHistory.length > MAX_HISTORY_SIZE) {
      _motionHistory.removeAt(0);
      _magnitudeBuffer.removeAt(0);
      _motionTimestamps.removeAt(0);
    }

    _accumulatedShake += filteredMag;

    // Pattern fingerprinting
    final pattern = _quantizePattern(dx, dy, dz);
    _patternFrequency[pattern] = (_patternFrequency[pattern] ?? 0) + 1;
    _uniquePatternCount = _patternFrequency.length;

    _calculateBiometricStats();
    
    // Only notify UI on significant changes (throttle updates)
    if (_motionHistory.length % 3 == 0) {
      notifyListeners();
    }
  }

  String _quantizePattern(double dx, double dy, double dz) {
    return "${(dx * 10).round()}:${(dy * 10).round()}:${(dz * 10).round()}";
  }

  void _calculateBiometricStats() {
    if (_magnitudeBuffer.isEmpty) return;
    
    final mean = _magnitudeBuffer.reduce((a, b) => a + b) / _magnitudeBuffer.length;

    _frequencyVariance = sqrt(
      _magnitudeBuffer.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / 
      _magnitudeBuffer.length,
    );

    final total = _patternFrequency.values.fold(0, (a, b) => a + b);
    _entropy = 0.0;

    for (final count in _patternFrequency.values) {
      final p = count / total;
      if (p > 0) _entropy -= p * (log(p) / log(2));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧬 BIOMETRIC SIGNATURE GENERATION
  // ═══════════════════════════════════════════════════════════

  double _estimateTremorHz() {
    if (_motionTimestamps.length < 6) return 0.0;
    final intervals = <double>[];

    for (int i = 1; i < _motionTimestamps.length; i++) {
      intervals.add(
        _motionTimestamps[i].difference(_motionTimestamps[i - 1]).inMilliseconds / 1000.0,
      );
    }

    final avg = intervals.reduce((a, b) => a + b) / intervals.length;
    return avg <= 0 ? 0.0 : 1 / avg;
  }

  /// Time-decay function (natural confidence drop over time)
  double _decay(double raw) {
    if (_sessionStartTime == null) return raw;
    final elapsed = DateTime.now().difference(_sessionStartTime!).inMilliseconds;
    return (raw * exp(-elapsed / 5000)).clamp(0.0, 1.0);
  }

  BiometricSignature _generateSignature() {
    final avgMag = _magnitudeBuffer.isEmpty ? 0.0 :
        _magnitudeBuffer.reduce((a, b) => a + b) / _magnitudeBuffer.length;

    final tremorHz = _estimateTremorHz();
    final tremorHuman = tremorHz > 7.5 && tremorHz < 13.5;

    double score = 0.0;
    
    // Motion scoring (40% weight)
    if (avgMag > 0.2 && avgMag < 3.5) score += 0.15;
    if (_frequencyVariance > 0.12) score += 0.1;
    if (_entropy > 0.5) score += 0.1;
    if (tremorHuman) score += 0.05;
    
    // 🔥 WHEEL INTERACTION SCORING (60% weight)
    if (_wheelTouchCount > 0) score += 0.2;
    if (_wheelTouchCount > 3) score += 0.2;
    if (_wheelTouchCount > 6) score += 0.2;

    return BiometricSignature(
      averageMagnitude: avgMag,
      frequencyVariance: _frequencyVariance,
      patternEntropy: _entropy,
      uniqueGestureCount: _wheelTouchCount,
      timestamp: DateTime.now(),
      isPotentiallyHuman: score >= 0.6,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 SERVER VALIDATION
  // ═══════════════════════════════════════════════════════════

  Future<ServerVerdict> _verifyWithServer() async {
    try {
      final deviceId = await DeviceFingerprint.getDeviceId();
      final appSignature = await DeviceFingerprint.getAppSignature();
      final deviceSecret = await DeviceFingerprint.getDeviceSecret();
      final nonce = DeviceFingerprint.generateNonce();
      
      final zkProof = ZeroKnowledgeProof.generate(
        userCode: currentValues,
        nonce: nonce,
        deviceSecret: deviceSecret,
      );
      
      final motionSig = MotionSignature.generate(
        entropy: _entropy,
        variance: _frequencyVariance,
        gestureCount: _uniquePatternCount,
      );
      
      final payload = SecurePayload(
        deviceId: deviceId,
        appSignature: appSignature,
        nonce: nonce,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        entropy: _entropy,
        tremorHz: _estimateTremorHz(),
        frequencyVariance: _frequencyVariance,
        averageMagnitude: _magnitudeBuffer.isEmpty ? 0.0 :
            _magnitudeBuffer.reduce((a, b) => a + b) / _magnitudeBuffer.length,
        uniqueGestureCount: _uniquePatternCount,
        interactionTimeMs: _activeInteraction.inMilliseconds,
        zkProof: zkProof,
        motionSignature: motionSig,
      );
      
      return await _mirrorService.verify(payload);
      
    } catch (e) {
      if (kDebugMode) print('Server validation error: $e');
      
      if (config.securityConfig?.allowOfflineFallback ?? true) {
        return ServerVerdict.offlineFallback();
      } else {
        return ServerVerdict.denied('server_unavailable');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 VALIDATION PIPELINE (AAA + Server)
  // ═══════════════════════════════════════════════════════════

  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));

    // CHECK 1: Minimum interaction time
    if (_activeInteraction < config.minSolveTime) {
      await _fail(bot: true, msg: "INSUFFICIENT HUMAN INTERACTION");
      return;
    }

    // CHECK 2: Biometric quality
    final sig = _generateSignature();
    final confidence = _decay(sig.humanConfidence);

    if (_lastSignature != null) {
      final drift = (sig.patternEntropy - _lastSignature!.patternEntropy).abs() +
                    (sig.averageMagnitude - _lastSignature!.averageMagnitude).abs();

      if (drift < 0.03) {
        await _fail(bot: true, msg: "BEHAVIOR TOO CONSISTENT");
        return;
      }
    }

    _lastSignature = sig;

    if (confidence < config.botDetectionSensitivity) {
      if (confidence > config.botDetectionSensitivity - 0.05) {
        _quietSuspicion = true;
      } else {
        await _fail(bot: true, msg: "LOW BIOMETRIC CONFIDENCE");
        return;
      }
    }

    if (_quietSuspicion && confidence < config.botDetectionSensitivity + 0.1) {
      await _fail(bot: true, msg: "SILENT BOT FILTER");
      return;
    }

    // CHECK 3: Server validation
    if (config.hasServerValidation) {
      final verdict = await _verifyWithServer();
      
      if (!verdict.allowed) {
        await _fail(bot: true, msg: verdict.reason?.toUpperCase() ?? "SERVER DENIED ACCESS");
        return;
      }
    }

    // CHECK 4: Code validation
    if (!_isCodeCorrect()) {
      await _fail(bot: false, msg: "INVALID PASSCODE");
      return;
    }

    // SUCCESS
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

  // ═══════════════════════════════════════════════════════════
  // 💾 STATE PERSISTENCE
  // ═══════════════════════════════════════════════════════════
  
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt(KEY_ATTEMPTS) ?? 0;
    
    final lockTs = prefs.getInt(KEY_LOCKOUT);
    if (lockTs != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockTs);
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
        notifyListeners();
      } else {
        await _clearMemory();
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
    await prefs.clear();
    _failedAttempts = 0;
    _lockoutUntil = null;
    _resetBiometricState();
    _state = SecurityState.LOCKED;
  }

  void _resetBiometricState() {
    _motionHistory.clear();
    _magnitudeBuffer.clear();
    _motionTimestamps.clear();
    _patternFrequency.clear();
    _rawSensorBuffer.clear();
    _entropy = 0.0;
    _frequencyVariance = 0.0;
    _uniquePatternCount = 0;
    _accumulatedShake = 0;
    _quietSuspicion = false;
    _lastSignature = null;
    _activeInteraction = Duration.zero;
    _sessionStartTime = DateTime.now();
    _lastInteractionTime = null;
    _wheelTouchCount = 0;
  }

  void _registerInteraction() {
    final now = DateTime.now();
    if (_lastInteractionTime != null) {
      _activeInteraction += now.difference(_lastInteractionTime!);
    }
    _lastInteractionTime = now;
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 PUBLIC GETTERS (UI Access)
  // ═══════════════════════════════════════════════════════════

  /// Main confidence score (time-decayed, stable)
  double get liveConfidence {
    // Wheel touch contribution (immediate feedback)
    double wheelScore = (_wheelTouchCount / 10.0).clamp(0.0, 0.7);
    
    // Motion contribution
    double motionScore = _decay(_generateSignature().humanConfidence);
    
    // Combine: 60% wheel, 40% motion
    return (wheelScore * 0.6 + motionScore * 0.4).clamp(0.0, 1.0);
  }
  
  int get uniqueGestureCount => _uniquePatternCount;
  double get motionEntropy => _entropy;
  
  int get remainingLockoutSeconds =>
      _lockoutUntil == null ? 0 : 
      _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
}
