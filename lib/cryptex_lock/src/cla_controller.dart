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
  static const double ELECTRONIC_NOISE_FLOOR = 0.12; // High-pass filter threshold

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
  // 🐕 SECURITY WATCHDOG - Root/Debug Detection
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
    
    // Warning for USB debugging in production builds
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
  // 💾 PERSISTENT MEMORY - State Management
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
  // 🧬 BIOMETRIC PROCESSING - Advanced Pattern Recognition
  // ═══════════════════════════════════════════════════════════
  
  void updateWheel(int index, int value) {
    if (_state == SecurityState.HARD_LOCK || 
        _state == SecurityState.VALIDATING ||
        _state == SecurityState.ROOT_WARNING) return;
        
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
    }
  }

  /// Receives motion data from UI sensors
  void registerShake(double magnitude, {double dx = 0, double dy = 0, double dz = 0}) {
    // High-pass filter: Ignore electronic noise below threshold
    if (magnitude < ELECTRONIC_NOISE_FLOOR) return;
    
    final now = DateTime.now();
    
    // Add to motion history
    final event = MotionEvent(
      magnitude: magnitude,
      timestamp: now,
      deltaX: dx,
      deltaY: dy,
      deltaZ: dz,
    );
    
    _motionHistory.add(event);
    _magnitudeBuffer.add(magnitude);
    
    // Maintain sliding window
    if (_motionHistory.length > MAX_HISTORY_SIZE) {
      _motionHistory.removeAt(0);
    }
    if (_magnitudeBuffer.length > MAX_HISTORY_SIZE) {
      _magnitudeBuffer.removeAt(0);
    }
    
    // Pattern fingerprinting for bot detection
    String pattern = _quantizePattern(dx, dy, dz);
    _patternFrequency[pattern] = (_patternFrequency[pattern] ?? 0) + 1;
    
    // Calculate unique pattern diversity
    _uniquePatternCount = _patternFrequency.keys.length;
    
    // Accumulate for legacy threshold check
    _accumulatedShake += magnitude;
    
    // Calculate real-time statistics
    _calculateBiometricStats();
  }

  /// Quantizes motion vector into discrete pattern bucket
  String _quantizePattern(double dx, double dy, double dz) {
    int qx = (dx * 10).round();
    int qy = (dy * 10).round();
    int qz = (dz * 10).round();
    return '$qx:$qy:$qz';
  }

  /// Computes advanced biometric statistics
  void _calculateBiometricStats() {
    if (_magnitudeBuffer.length < 5) return;
    
    // Calculate variance (humans have inconsistent tremors)
    double mean = _magnitudeBuffer.reduce((a, b) => a + b) / _magnitudeBuffer.length;
    double variance = _magnitudeBuffer
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / _magnitudeBuffer.length;
    _frequencyVariance = sqrt(variance);
    
    // Calculate Shannon entropy of patterns (randomness measure)
    int totalPatterns = _patternFrequency.values.reduce((a, b) => a + b);
    _entropy = 0.0;
    
    for (var count in _patternFrequency.values) {
      double p = count / totalPatterns;
      if (p > 0) {
        _entropy -= p * (log(p) / log(2));
      }
    }
  }

  /// Generates comprehensive biometric signature
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
  // 🤖 ANTI-BOT VALIDATION - Multi-Layer Defense
  // ═══════════════════════════════════════════════════════════
  
  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    // Layer 1: Sensor enablement check
    if (config.enableSensors) {
      final signature = _generateSignature();
      double humanConfidence = signature.humanConfidence;
      
      // Layer 2: Zero-motion detection (emulator)
      if (_accumulatedShake < 0.1 && !hasPhysicalMovement) {
        _threatMessage = "🤖 STATIC DEVICE DETECTED";
        await _handleFailure(isBotSuspected: true);
        return;
      }
      
      // Layer 3: Pattern repetition detection (recorded loop)
      if (_isRepeatingPattern()) {
        _threatMessage = "🔄 LOOP PATTERN DETECTED";
        await _handleFailure(isBotSuspected: true);
        return;
      }
      
      // Layer 4: Biometric confidence threshold
      if (humanConfidence < config.botDetectionSensitivity) {
        _threatMessage = "⚠️ LOW BIOMETRIC CONFIDENCE (${(humanConfidence * 100).toStringAsFixed(0)}%)";
        await _handleFailure(isBotSuspected: true);
        return;
      }
      
      // Layer 5: Time-based analysis (too fast = bot)
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      if (sessionDuration < config.minSolveTime) {
        _threatMessage = "⏱️ IMPOSSIBLY FAST INPUT";
        await _handleFailure(isBotSuspected: true);
        return;
      }
    }

    // Final: Code validation
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

  /// Detects if motion pattern is suspiciously repetitive
  bool _isRepeatingPattern() {
    if (_motionHistory.length < 10) return false;
    
    int repeats = 0;
    int checkSize = min(5, _motionHistory.length ~/ 2);
    
    for (int i = _motionHistory.length - 1; i >= checkSize; i--) {
      if (_motionHistory[i].isSimilarTo(_motionHistory[i - checkSize], threshold: 0.03)) {
        repeats++;
      }
    }
    
    // If >60% of recent movements are identical, flag as loop
    return repeats > (_motionHistory.length * 0.6);
  }

  Future<void> _handleFailure({bool isBotSuspected = false}) async {
    _failedAttempts++;
    await _saveStateToMemory();

    if (isBotSuspected) {
      // Instant lockout for bot behavior
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
  // 📊 UTILITY GETTERS
  // ═══════════════════════════════════════════════════════════
  
  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) return currentValues[index];
    return 0;
  }

  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
  }
  
  double get biometricScore {
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
