/*
 * PROJECT: CryptexLock Security Suite
 * AUTHOR: Captain Aer (Visionary)
 * LICENSE: Server-Side Public License (SSPL) Style
 * * COPYRIGHT (c) 2026 CAPTAIN AER. ALL RIGHTS RESERVED.
 * * Usage Warning:
 * This software's core biometric logic is the intellectual property of Captain Aer.
 * You may use this code for personal projects, but commercial redistribution, 
 * SaaS integration, or "white-labeling" without explicit permission is 
 * strictly prohibited and protected under international IP laws.
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'cla_models.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;
  DateTime? _lockoutUntil;
  
  late List<int> currentValues;
  
  // Advanced biometric tracking
  final List<MotionEvent> _motionHistory = [];
  final List<double> _magnitudeBuffer = [];
  double _accumulatedShake = 0;
  double _frequencyVariance = 0;
  int _uniquePatternCount = 0;
  DateTime? _sessionStartTime;
  
  // Pattern recognition state
  final Map<String, int> _patternFrequency = {};
  double _entropy = 0.0;
  
  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';
  static const int MAX_HISTORY_SIZE = 100;
  static const double ELECTRONIC_NOISE_FLOOR = 0.12; 

  Timer? _botTimer;
  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  ClaController(this.config) {
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    _sessionStartTime = DateTime.now();
    _initSecurityProtocol();
  }

  // ═══════════════════════════════════════════════════════════
  // 🐕 SECURITY WATCHDOG
  // ═══════════════════════════════════════════════════════════
  
  Future<void> _initSecurityProtocol() async {
    bool isRooted = false;
    bool isUsbDebug = false;

    try {
      isRooted = await FlutterJailbreakDetection.jailbroken;
      isUsbDebug = await FlutterJailbreakDetection.developerMode;
    } catch (e) {
      if (kDebugMode) print("Security check failed: $e");
    }

    if (isRooted) {
      _threatMessage = "⚠️ ROOTED DEVICE DETECTED";
      _state = SecurityState.ROOT_WARNING;
      notifyListeners();
      return; 
    }
    
    if (isUsbDebug && !kDebugMode) {
      _threatMessage = "⚠️ USB DEBUGGING ACTIVE";
      _state = SecurityState.ROOT_WARNING;
      notifyListeners();
      return;
    }

    await _loadStateFromMemory();
  }
  
  void userAcceptsRisk() {
    _state = SecurityState.LOCKED;
    _threatMessage = "";
    notifyListeners();
    _loadStateFromMemory();
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 PERSISTENT MEMORY
  // ═══════════════════════════════════════════════════════════
  
  Future<void> _loadStateFromMemory() async {
    if (_state == SecurityState.ROOT_WARNING) return;

    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt(KEY_ATTEMPTS) ?? 0;
    
    final lockTimestamp = prefs.getInt(KEY_LOCKOUT);
    if (lockTimestamp != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockTimestamp);
      
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
        notifyListeners();
      } else {
        await _clearMemory(); 
      }
    }
  }

  Future<void> _saveStateToMemory() async {
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
    _accumulatedShake = 0;
    _lockoutUntil = null;
    _state = SecurityState.LOCKED;
    _resetBiometricState();
  }

  void _resetBiometricState() {
    _motionHistory.clear();
    _magnitudeBuffer.clear();
    _patternFrequency.clear();
    _uniquePatternCount = 0;
    _entropy = 0.0;
    _frequencyVariance = 0.0;
    _sessionStartTime = DateTime.now();
  }

  // ═══════════════════════════════════════════════════════════
  // 🧬 BIOMETRIC PROCESSING (The "Secret Sauce")
  // ═══════════════════════════════════════════════════════════
  
  void updateWheel(int index, int value) {
    if (_state == SecurityState.HARD_LOCK || 
        _state == SecurityState.VALIDATING ||
        _state == SecurityState.ROOT_WARNING) return;
        
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
    }
  }

  void registerShake(double magnitude, double dx, double dy, double dz) {
    if (magnitude < ELECTRONIC_NOISE_FLOOR) return;
    
    final now = DateTime.now();
    
    final event = MotionEvent(
      magnitude: magnitude,
      timestamp: now,
      deltaX: dx,
      deltaY: dy,
      deltaZ: dz,
    );
    
    _motionHistory.add(event);
    _magnitudeBuffer.add(magnitude);
    
    if (_motionHistory.length > MAX_HISTORY_SIZE) {
      _motionHistory.removeAt(0);
    }
    if (_magnitudeBuffer.length > MAX_HISTORY_SIZE) {
      _magnitudeBuffer.removeAt(0);
    }
    
    String pattern = _quantizePattern(dx, dy, dz);
    _patternFrequency[pattern] = (_patternFrequency[pattern] ?? 0) + 1;
    _uniquePatternCount = _patternFrequency.keys.length;
    _accumulatedShake += magnitude;
    
    _calculateBiometricStats();
    notifyListeners(); // Ensure UI reflects real-time metrics
  }

  String _quantizePattern(double dx, double dy, double dz) {
    int qx = (dx * 10).round();
    int qy = (dy * 10).round();
    int qz = (dz * 10).round();
    return '$qx:$qy:$qz';
  }

  void _calculateBiometricStats() {
    if (_magnitudeBuffer.length < 5) return;
    
    double mean = _magnitudeBuffer.reduce((a, b) => a + b) / _magnitudeBuffer.length;
    double variance = _magnitudeBuffer
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / _magnitudeBuffer.length;
    _frequencyVariance = sqrt(variance);
    
    int totalPatterns = _patternFrequency.values.reduce((a, b) => a + b);
    _entropy = 0.0;
    
    for (var count in _patternFrequency.values) {
      double p = count / totalPatterns;
      if (p > 0) {
        _entropy -= p * (log(p) / log(2));
      }
    }
  }

  BiometricSignature _generateSignature() {
    double avgMagnitude = _magnitudeBuffer.isEmpty 
        ? 0.0 
        : _magnitudeBuffer.reduce((a, b) => a + b) / _magnitudeBuffer.length;
    
    return BiometricSignature(
      averageMagnitude: avgMagnitude,
      frequencyVariance: _frequencyVariance,
      patternEntropy: _entropy,
      uniqueGestureCount: _uniquePatternCount,
      timestamp: DateTime.now(),
      isPotentiallyHuman: avgMagnitude > 0.15 && _uniquePatternCount >= 3,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 ANTI-BOT VALIDATION
  // ═══════════════════════════════════════════════════════════
  
  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    if (config.enableSensors) {
      final signature = _generateSignature();
      double humanConfidence = signature.humanConfidence;
      
      if (_accumulatedShake < 0.1 && !hasPhysicalMovement) {
        _threatMessage = "🤖 STATIC DEVICE DETECTED";
        await _handleFailure(isBotSuspected: true);
        return;
      }
      
      if (_isRepeatingPattern()) {
        _threatMessage = "🔄 LOOP PATTERN DETECTED";
        await _handleFailure(isBotSuspected: true);
        return;
      }
      
      if (humanConfidence < config.botDetectionSensitivity) {
        _threatMessage = "⚠️ LOW BIOMETRIC CONFIDENCE (${(humanConfidence * 100).toStringAsFixed(0)}%)";
        await _handleFailure(isBotSuspected: true);
        return;
      }
      
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      if (sessionDuration < config.minSolveTime) {
        _threatMessage = "⏱️ IMPOSSIBLY FAST INPUT";
        await _handleFailure(isBotSuspected: true);
        return;
      }
    }

    if (_isCodeCorrect()) {
      await _clearMemory();
      _state = SecurityState.UNLOCKED;
      _threatMessage = "";
      notifyListeners();
    } else {
      _threatMessage = "❌ INVALID CODE";
      await _handleFailure(isBotSuspected: false);
    }
  }

  bool _isRepeatingPattern() {
    if (_motionHistory.length < 10) return false;
    
    int repeats = 0;
    int checkSize = min(5, _motionHistory.length ~/ 2);
    
    for (int i = _motionHistory.length - 1; i >= checkSize; i--) {
      if (_motionHistory[i].isSimilarTo(_motionHistory[i - checkSize], threshold: 0.03)) {
        repeats++;
      }
    }
    return repeats > (_motionHistory.length * 0.6);
  }

  Future<void> _handleFailure({bool isBotSuspected = false}) async {
    _failedAttempts++;
    await _saveStateToMemory();

    if (isBotSuspected) {
      _state = SecurityState.HARD_LOCK;
      _lockoutUntil = DateTime.now().add(config.jamCooldown);
      await _saveStateToMemory();
      notifyListeners();
    } else if (_failedAttempts >= config.maxAttempts) {
      _state = SecurityState.HARD_LOCK;
      _lockoutUntil = DateTime.now().add(config.jamCooldown);
      await _saveStateToMemory();
      notifyListeners();
    } else {
      _state = SecurityState.SOFT_LOCK;
      notifyListeners();
      
      Future.delayed(config.softLockCooldown, () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
          _threatMessage = "";
          notifyListeners();
        }
      });
    }
  }

  bool _isCodeCorrect() {
    if (currentValues.length != config.secret.length) return false;
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 GETTERS (Aligned with Cryptex UI)
  // ═══════════════════════════════════════════════════════════
  
  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) return currentValues[index];
    return 0;
  }

  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
  }
  
  double get liveConfidence {
    final sig = _generateSignature();
    return sig.humanConfidence;
  }
  
  int get uniqueGestureCount => _uniquePatternCount;
  
  double get motionEntropy => _entropy;

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}
