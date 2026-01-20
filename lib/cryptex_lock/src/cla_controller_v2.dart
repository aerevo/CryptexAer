// 🎮 Z-KINETIC CONTROLLER V3.1 (MEMORY LEAK FIXED)
// Status: PRODUCTION READY ✅
// Changes: Enhanced dispose() with proper cleanup

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core & Models
import 'security_core.dart';
import 'motion_models.dart';
import 'cla_models.dart';
import 'cla_constants.dart'; // Pastikan constants di-import

// 🧠 AI BRAINS
import 'behavioral_analyzer.dart';
import 'adaptive_threshold_engine.dart';

// Legacy alias
import 'cla_models.dart' as legacy;

extension ClaConfigV3Extension on ClaConfig {
  SecurityCoreConfig toCoreConfig() {
    return SecurityCoreConfig(
      expectedCode: secret,
      maxFailedAttempts: maxAttempts,
      lockoutDuration: jamCooldown,
      enforceReplayImmunity: enforceReplayImmunity,
      nonceValidityWindow: nonceValidityWindow,
      attestationProvider: attestationProvider,
    );
  }
}

class AdaptiveLearningEngine {
  double _avgMotion = 3.0;
  double _avgTouch = 8.0;
  double _stdDevMotion = 1.0;
  int _successfulUnlocks = 0;
  
  final List<double> _motionHistory = [];
  final List<double> _touchHistory = [];
  
  void learnFromSuccess(double motionScore, double touchScore) {
    _motionHistory.add(motionScore);
    _touchHistory.add(touchScore);
    
    if (_motionHistory.length > 20) {
      _motionHistory.removeAt(0);
      _touchHistory.removeAt(0);
    }
    
    if (_motionHistory.isNotEmpty) {
      _avgMotion = _motionHistory.reduce((a, b) => a + b) / _motionHistory.length;
      _avgTouch = _touchHistory.reduce((a, b) => a + b) / _touchHistory.length;
      
      final variance = _motionHistory.map((x) => pow(x - _avgMotion, 2))
          .reduce((a, b) => a + b) / _motionHistory.length;
      _stdDevMotion = sqrt(variance);
    }
    _successfulUnlocks++;
  }
  
  bool isAnomaly(double currentMotion, double currentTouch) {
    if (_successfulUnlocks < 3) return false;
    final zScore = (currentMotion - _avgMotion).abs() / (_stdDevMotion + 0.1);
    return zScore > 3.0;
  }
  
  double getMotionThreshold() {
    if (_successfulUnlocks < 5) return 2.0;
    return max(1.0, _avgMotion * 0.6);
  }
  
  double getTouchThreshold() {
    if (_successfulUnlocks < 5) return 5.0;
    return max(3.0, _avgTouch * 0.5);
  }
  
  Map<String, dynamic> getProfile() => {
    'avg_motion': _avgMotion.toStringAsFixed(2),
    'avg_touch': _avgTouch.toStringAsFixed(2),
    'std_dev': _stdDevMotion.toStringAsFixed(2),
    'unlock_count': _successfulUnlocks,
    'is_trained': _successfulUnlocks >= 5,
  };

  // ✅ NEW: Proper cleanup for AI engine
  void dispose() {
    _motionHistory.clear();
    _touchHistory.clear();
    _successfulUnlocks = 0;
    _avgMotion = 3.0;
    _avgTouch = 8.0;
    _stdDevMotion = 1.0;
    
    if (kDebugMode) {
      debugPrint('🧹 AdaptiveLearningEngine disposed');
    }
  }
}

class ClaController extends ChangeNotifier {
  final ClaConfig config;
  late final SecurityCore _core;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 🧠 AI BRAIN
  final AdaptiveLearningEngine _aiEngine = AdaptiveLearningEngine();

  // AI Engines
  late final BehavioralAnalyzer _behaviorAnalyzer;
  late final AdaptiveThresholdEngine _adaptiveEngine;

  // State Variables
  legacy.SecurityState _uiState = legacy.SecurityState.LOCKED; // Guna legacy enum
  List<int> currentValues = [0, 0, 0, 0, 0];
  String _currentSessionId = '';
  DateTime? _sessionStart;

  // Data Buffers
  final List<MotionEvent> _motionBuffer = [];
  final List<TouchEvent> _touchBuffer = [];

  // UI Notifiers
  final ValueNotifier<double> _confidenceNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _motionEntropyNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _touchScoreNotifier = ValueNotifier(0.0);

  String _threatMessage = "";
  bool _isPanicMode = false;
  bool _isPaused = false;
  
  Timer? _touchDecayTimer;

  // ✅ NEW: Disposal tracking
  bool _isDisposed = false;

  ClaController(this.config) {
    _core = SecurityCore(config.toCoreConfig());
    _behaviorAnalyzer = BehavioralAnalyzer();
    _adaptiveEngine = AdaptiveThresholdEngine();
    _startNewSession();
  }

  // ============================================
  // GETTERS
  // ============================================
  legacy.SecurityState get state => _uiState;
  int get failedAttempts => _core.failedAttempts;
  bool get isPanicMode => _isPanicMode;
  String get threatMessage => _threatMessage;
  
  ValueNotifier<double> get confidenceNotifier => _confidenceNotifier;
  ValueNotifier<double> get motionEntropyNotifier => _motionEntropyNotifier;
  ValueNotifier<double> get touchScoreNotifier => _touchScoreNotifier;

  double get liveConfidence => _confidenceNotifier.value;
  double get motionEntropy => _motionEntropyNotifier.value;
  int get remainingLockoutSeconds => _core.remainingLockoutSeconds;
  
  Map<String, dynamic> get aiProfile => _aiEngine.getProfile();

  // ============================================
  // METHODS
  // ============================================

  void onInteractionStart() {
    if (_isDisposed) return;
    _startNewSession();
  }

  void updateWheel(int index, int value) {
    if (_isDisposed) return;
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      notifyListeners();
    }
  }

  int getInitialValue(int index) => currentValues[index];

  void registerShake(double rawMag, double x, double y, double z) {
    if (_isDisposed || _isPaused || _uiState == legacy.SecurityState.UNLOCKED) return;
    
    final event = MotionEvent(
      magnitude: rawMag,
      timestamp: DateTime.now(),
      deltaX: x,
      deltaY: y,
      deltaZ: z,
    );

    _motionBuffer.add(event);
    if (_motionBuffer.length > 50) _motionBuffer.removeAt(0);

    _motionEntropyNotifier.value = _calculateEntropy();
  }

  void registerTouch({double pressure = 0.5, double vx = 0, double vy = 0}) {
    if (_isDisposed || _isPaused || _uiState == legacy.SecurityState.UNLOCKED) return;

    final event = TouchEvent(
      timestamp: DateTime.now(),
      pressure: pressure,
      velocityX: vx,
      velocityY: vy,
    );

    _touchBuffer.add(event);
    if (_touchBuffer.length > 50) _touchBuffer.removeAt(0);

    _touchScoreNotifier.value = 1.0;
    
    _touchDecayTimer?.cancel();
    _touchDecayTimer = Timer(const Duration(milliseconds: 500), () {
      Future.delayed(const Duration(milliseconds: 100), _decayTouch);
    });

    notifyListeners();
  }

  void _decayTouch() {
    if (_isDisposed) return;
    if (_touchScoreNotifier.value > 0) {
      _touchScoreNotifier.value -= 0.02;
      if (_touchScoreNotifier.value < 0) _touchScoreNotifier.value = 0;
      Future.delayed(const Duration(milliseconds: 100), _decayTouch);
    }
  }

  Future<bool> validateAttempt({bool hasPhysicalMovement = true}) async {
    if (_isDisposed || _core.state == legacy.SecurityState.HARD_LOCK) return false;

    _uiState = legacy.SecurityState.VALIDATING;
    _threatMessage = "";
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final motionScore = _calculateMotionScore() * 10.0;
    final touchScore = _calculateTouchScore() * 10.0;
    
    final motionThreshold = _aiEngine.getMotionThreshold();
    final touchThreshold = _aiEngine.getTouchThreshold();
    
    if (config.enableSensors && 
        (motionScore < motionThreshold || touchScore < touchThreshold)) {
      _uiState = legacy.SecurityState.SOFT_LOCK;
      _threatMessage = "INSUFFICIENT BIOMETRIC DATA (AI)";
      notifyListeners();

      Future.delayed(const Duration(seconds: 2), () {
        if (_isDisposed) return;
        if (_uiState == legacy.SecurityState.SOFT_LOCK) {
          _uiState = legacy.SecurityState.LOCKED;
          _threatMessage = "";
          notifyListeners();
        }
      });
      return false;
    }
    
    if (_aiEngine.isAnomaly(motionScore, touchScore)) {
      _threatMessage = "⚠️ UNUSUAL BEHAVIOR DETECTED";
      if (kDebugMode) debugPrint("🧠 AI: Anomaly detected (Z-score > 3.0)");
    }

    BiometricSession? bioSession;
    if (_motionBuffer.isNotEmpty || _touchBuffer.isNotEmpty) {
      bioSession = BiometricSession(
        sessionId: _currentSessionId,
        startTime: _sessionStart ?? DateTime.now(),
        motionEvents: List.from(_motionBuffer),
        touchEvents: List.from(_touchBuffer),
        duration: DateTime.now().difference(_sessionStart ?? DateTime.now()),
      );
    }

    final attempt = ValidationAttempt(
      attemptId: _generateNonce(),
      timestamp: DateTime.now(),
      inputCode: List.from(currentValues),
      biometricData: bioSession,
      hasPhysicalMovement: hasPhysicalMovement || _motionBuffer.isNotEmpty,
    );

    final result = await _core.validate(attempt);

    final reversedCode = config.secret.reversed.toList();
    final isPanic = listEquals(currentValues, reversedCode);

    if (result.allowed) {
      if (isPanic) {
        _handleSuccess(panic: true, confidence: result.confidence);
        return true;
      }
      
      _aiEngine.learnFromSuccess(motionScore, touchScore);
      
      if (kDebugMode) {
        debugPrint("🧠 AI Profile Updated: ${_aiEngine.getProfile()}");
      }
      
      _handleSuccess(panic: false, confidence: result.confidence);
      return true;
    }

    return _handleValidationResult(result);
  }

  bool _handleValidationResult(ValidationResult result) {
    if (_isDisposed) return false;
    
    if (result.allowed) {
      if (result.threatLevel == ThreatLevel.CRITICAL || result.threatLevel == ThreatLevel.HIGH_RISK) {
         _threatMessage = "SECURITY THREAT DETECTED";
         _handleFailure();
         return false;
      }
      
      _handleSuccess(
        panic: result.metadata?['isPanic'] ?? false, 
        confidence: result.confidence
      );
      return true;
    } else {
      _threatMessage = result.reason;
      if (result.reason == 'MAX_ATTEMPTS_EXCEEDED') {
        _uiState = legacy.SecurityState.HARD_LOCK;
      } else {
        _handleFailure();
      }
      return false;
    }
  }

  void _handleSuccess({required bool panic, required double confidence}) {
    if (_isDisposed) return;
    
    _uiState = legacy.SecurityState.UNLOCKED;
    _isPanicMode = panic;
    _threatMessage = panic ? "SILENT ALARM ACTIVATED" : "";
    _confidenceNotifier.value = confidence;
    _isPaused = true;
    
    _storage.deleteAll();
    notifyListeners();
  }

  void _handleFailure() {
    if (_isDisposed) return;
    
    if (_core.state == legacy.SecurityState.HARD_LOCK) {
      _uiState = legacy.SecurityState.HARD_LOCK;
    } else {
      _uiState = legacy.SecurityState.LOCKED;
    }
    
    _motionBuffer.clear();
    _touchBuffer.clear();
    notifyListeners();
  }

  void _startNewSession() {
    if (_isDisposed) return;
    
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStart = DateTime.now();
    _motionBuffer.clear();
    _touchBuffer.clear();
    _isPaused = false;
  }

  double _calculateMotionScore() {
    if (_motionBuffer.isEmpty) return 0.0;
    final totalMag = _motionBuffer.fold(0.0, (sum, e) => sum + e.magnitude);
    return (totalMag / _motionBuffer.length / 3.0).clamp(0.0, 1.0);
  }

  double _calculateTouchScore() {
    if (_touchBuffer.isEmpty) return 0.0;
    return (_touchBuffer.length / 10.0).clamp(0.0, 1.0);
  }

  double _calculateEntropy() {
    if (_motionBuffer.isEmpty) return 0.0;
    
    final mags = _motionBuffer.map((e) => e.magnitude).toList();
    final Map<int, int> distribution = {};
    
    for (var mag in mags) {
      int bucket = (mag * 10).round();
      distribution[bucket] = (distribution[bucket] ?? 0) + 1;
    }
    
    double entropy = 0.0;
    int total = mags.length;
    
    distribution.forEach((_, count) {
      double probability = count / total;
      if (probability > 0) {
        entropy += probability * (1 - probability);
      }
    });
    
    return (entropy / 0.25).clamp(0.0, 1.0);
  }

  void reset() {
    if (_isDisposed) return;
    
    _core.reset();
    _uiState = legacy.SecurityState.LOCKED;
    _isPanicMode = false;
    _threatMessage = "";
    _touchScoreNotifier.value = 0.0;
    _motionEntropyNotifier.value = 0.0;
    _startNewSession();
    notifyListeners();
  }

  Map<String, dynamic> getSessionSnapshot() {
    return {
      'session_id': _currentSessionId,
      'motion_events': _motionBuffer.length,
      'touch_events': _touchBuffer.length,
      'confidence': liveConfidence,
      'entropy': motionEntropy,
      'state': _uiState.name,
      'failed_attempts': failedAttempts,
      'ai_profile': aiProfile,
    };
  }

  String _generateNonce() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // ============================================
  // 🧹 ENHANCED DISPOSE (MEMORY LEAK FIX)
  // ============================================
  @override
  void dispose() {
    if (_isDisposed) {
      if (kDebugMode) {
        debugPrint('⚠️ ClaController already disposed');
      }
      return;
    }

    _isDisposed = true;

    // 1. Cancel all timers
    _touchDecayTimer?.cancel();
    _touchDecayTimer = null;

    // 2. Clear all buffers
    _motionBuffer.clear();
    _touchBuffer.clear();
    currentValues.clear();

    // 3. Dispose ValueNotifiers
    _confidenceNotifier.dispose();
    _motionEntropyNotifier.dispose();
    _touchScoreNotifier.dispose();

    // 4. Dispose AI Engine
    _aiEngine.dispose();

    // 5. Reset core
    _core.reset();

    // 6. Clear secure storage
    _storage.deleteAll().catchError((e) {
      if (kDebugMode) debugPrint('Storage cleanup error: $e');
    });

    // 7. Reset state variables
    _currentSessionId = '';
    _sessionStart = null;
    _threatMessage = '';
    _isPanicMode = false;
    _isPaused = false;
    _uiState = legacy.SecurityState.LOCKED;

    if (kDebugMode) {
      debugPrint('🧹 ClaController disposed successfully');
      debugPrint('   ├─ Timers: cancelled');
      debugPrint('   ├─ Buffers: cleared (${_motionBuffer.length} + ${_touchBuffer.length} events)');
      debugPrint('   ├─ Notifiers: disposed');
      debugPrint('   ├─ AI Engine: disposed');
      debugPrint('   └─ Storage: cleared');
    }

    super.dispose();
  }
}
