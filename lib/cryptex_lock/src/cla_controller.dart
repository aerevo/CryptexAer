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
  double _accumulatedShake = 0;
  
  // Pattern recognition state
  final Map<String, int> _patternFrequency = {};
  
  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';
  static const int MAX_HISTORY_SIZE = 100;
  static const double ELECTRONIC_NOISE_FLOOR = 0.12; // High-pass filter threshold

  String _threatMessage = "";
  String get threatMessage => _threatMessage;
  
  // Live Confidence Score for UI
  double _liveConfidence = 0.0;
  double get liveConfidence => _liveConfidence;

  ClaController(this.config) {
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    _initSecurityProtocol();
  }

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
      _threatMessage = "CRITICAL: ROOT ACCESS DETECTED";
      _state = SecurityState.ROOT_WARNING;
      notifyListeners();
      return; 
    }
    
    if (isUsbDebug && !kDebugMode) {
      _threatMessage = "WARNING: USB DEBUGGING ACTIVE";
      _state = SecurityState.ROOT_WARNING;
      notifyListeners();
    }

    await _loadStateFromMemory();
  }
  
  void userAcceptsRisk() {
    _state = SecurityState.LOCKED;
    notifyListeners();
    _loadStateFromMemory();
  }

  // ═══════════════════════════════════════════════════════════
  // 🧬 ADVANCED SENSOR LOGIC (BIO-SIGMA)
  // ═══════════════════════════════════════════════════════════

  void registerShake(double rawMagnitude, double dx, dy, dz) {
    if (_state == SecurityState.HARD_LOCK || _state == SecurityState.ROOT_WARNING) return;

    // 1. High-Pass Filter (Dead-zone for floor noise)
    if (rawMagnitude < ELECTRONIC_NOISE_FLOOR) return;

    final now = DateTime.now();
    
    // 2. Record Motion Event
    _motionHistory.add(MotionEvent(
      magnitude: rawMagnitude, 
      timestamp: now,
      deltaX: dx, deltaY: dy, deltaZ: dz
    ));
    
    // Keep buffer size managed
    if (_motionHistory.length > MAX_HISTORY_SIZE) {
      _motionHistory.removeAt(0);
    }
    
    _accumulatedShake += rawMagnitude;

    // 3. Pattern Frequency Mapping (For Entropy Calculation)
    // Quantize movement into 'buckets' to detect robotic loops
    String movementHash = "${rawMagnitude.toStringAsFixed(1)}:${dx.sign}:${dy.sign}";
    _patternFrequency[movementHash] = (_patternFrequency[movementHash] ?? 0) + 1;

    // 4. Update Live Confidence Score (For UI)
    _updateBiometricState();
  }

  void _updateBiometricState() {
    if (_motionHistory.isEmpty) return;

    // Calculate Variance (Human jitter vs Robot Smoothness)
    double mean = _accumulatedShake / _motionHistory.length;
    double variance = 0;
    for (var m in _motionHistory) {
      variance += pow(m.magnitude - mean, 2);
    }
    variance = variance / _motionHistory.length;

    // Calculate Shannon Entropy (Randomness)
    double entropy = 0;
    int totalPatterns = _motionHistory.length;
    _patternFrequency.forEach((key, count) {
      double p = count / totalPatterns;
      if (p > 0) entropy -= p * log(p); // Shannon formula
    });

    // Create Signature
    final signature = BiometricSignature(
      averageMagnitude: mean,
      frequencyVariance: variance,
      patternEntropy: entropy,
      uniqueGestureCount: _patternFrequency.length,
      timestamp: DateTime.now(),
      isPotentiallyHuman: true,
    );

    _liveConfidence = signature.humanConfidence;
    // Don't notify listeners on every sensor update to save battery/performance
    // The Widget uses Ticker for smooth animation anyway
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 CORE LOGIC
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

  void updateWheel(int index, int value) {
    if (_state != SecurityState.LOCKED) return;
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      notifyListeners();
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
    _motionHistory.clear();
    _patternFrequency.clear();
    _liveConfidence = 0.0;
    _lockoutUntil = null;
    _state = SecurityState.LOCKED;
  }
  
  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600)); // Suspense

    // 1. BIOMETRIC CHECK
    if (config.enableSensors) {
       // Check if confidence matches Human Standards
       if (_liveConfidence < config.botDetectionSensitivity) {
         ClaAudit.log('BOT DETECTED: Score $_liveConfidence < ${config.botDetectionSensitivity}');
         await _handleFailure();
         return;
       }
    }

    // 2. CODE CHECK
    if (_isCodeCorrect()) {
      await _clearMemory();
      _state = SecurityState.UNLOCKED;
      notifyListeners();
    } else {
      await _handleFailure();
    }
  }

  Future<void> _handleFailure() async {
    _failedAttempts++;
    await _saveStateToMemory();

    if (_failedAttempts >= config.maxAttempts) {
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
}

// Log kosmetik sementara
class ClaAudit {
  static void log(String msg) {
    if (kDebugMode) print("[CRYPTEX AUDIT] $msg");
  }
}
