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
  
  // ═══════════════════════════════════════════════════════════
  // 📡 SIGNAL PROCESSING PIPELINE (DSP ENGINE)
  // ═══════════════════════════════════════════════════════════
  
  // Rolling average buffer (10 frames = ~160ms history)
  final List<double> _rawBuffer = [];
  static const int BUFFER_SIZE = 10;
  
  // 1. NOISE GATE: Anything below this is floor noise/static
  static const double NOISE_GATE = 0.5;
  
  // 2. SPIKE REJECTION: Ignore sudden jumps > 5x the median
  static const double SPIKE_THRESHOLD_MULTIPLIER = 5.0;
  
  // 3. SMOOTHING: 0.15 means we trust new data 15%, old data 85%
  static const double SMOOTHING_FACTOR = 0.15;
  
  // 4. NORMALIZATION: Map sensor input (0-15) to UI (0-1)
  static const double SENSOR_MAX_INPUT = 15.0;

  // Internal tracker for smoothed value
  double _internalSmoothedValue = 0.0;
  
  // ═══════════════════════════════════════════════════════════
  
  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  String _threatMessage = "";
  String get threatMessage => _threatMessage;
  
  // Live Confidence Score for UI (0.0 - 1.0 Clean)
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
  // 🎛️ THE DSP PIPELINE IMPLEMETATION
  // ═══════════════════════════════════════════════════════════

  void registerShake(double rawInput, double dx, dy, dz) {
    if (_state == SecurityState.HARD_LOCK || _state == SecurityState.ROOT_WARNING) return;

    // [STAGE 1] NOISE GATE
    // If signal is weak (table vibration), kill it instantly.
    double cleanInput = rawInput;
    if (cleanInput < NOISE_GATE) {
      cleanInput = 0.0;
    }

    // [STAGE 2] ROLLING BUFFER
    // Add to history
    _rawBuffer.add(cleanInput);
    if (_rawBuffer.length > BUFFER_SIZE) {
      _rawBuffer.removeAt(0);
    }

    // Need enough data to perform advanced filtering
    if (_rawBuffer.length < 3) return;

    // [STAGE 3] MEDIAN FILTER (Anti-Spike)
    // Sort buffer to find median (middle value)
    List<double> sorted = List.from(_rawBuffer)..sort();
    double median = sorted[sorted.length ~/ 2];
    
    // If new value is HUGE compared to median, it's a glitch (Ghost Spike). Ignore it.
    // Except if median is 0 (start of movement), then allow it.
    if (median > 0.1 && cleanInput > (median * SPIKE_THRESHOLD_MULTIPLIER)) {
      // Reject this specific sample, use median instead
      cleanInput = median;
    }

    // [STAGE 4] ROLLING AVERAGE
    // Smooth out the bumps
    double average = _rawBuffer.reduce((a, b) => a + b) / _rawBuffer.length;

    // [STAGE 5] EXPONENTIAL SMOOTHING (The "Heavy" Feel)
    // Formula: New = (Old * 0.85) + (Input * 0.15)
    _internalSmoothedValue = (_internalSmoothedValue * (1 - SMOOTHING_FACTOR)) + (average * SMOOTHING_FACTOR);

    // [STAGE 6] NORMALIZATION
    // Map 0.0 -> 15.0  TO  0.0 -> 1.0
    double normalizedScore = (_internalSmoothedValue / SENSOR_MAX_INPUT).clamp(0.0, 1.0);

    // Update Public State
    _liveConfidence = normalizedScore;
    
    // Auto-Notify logic is handled by Widget Ticker, 
    // but we notify here if specific thresholds are met for logic updates
    if (_liveConfidence > 0.01) {
       // Optional: Trigger specific logic logic
    }
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
    _internalSmoothedValue = 0;
    _rawBuffer.clear();
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
       // Human must maintain at least 20% intensity during unlock
       // Or have a history of movement. 
       if (_liveConfidence < 0.2 && _internalSmoothedValue < 1.0) {
         ClaAudit.log('FAIL: Too static. Bot or Table detected.');
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
  
  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) return currentValues[index];
    return 0;
  }

  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
  }
}

class ClaAudit {
  static void log(String msg) {
    if (kDebugMode) print("[CRYPTEX AUDIT] $msg");
  }
}
