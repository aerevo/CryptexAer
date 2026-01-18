// 🎮 Z-KINETIC CONTROLLER V2.2 (STABLE & RESPONSIVE)
// Status: PANIC MODE FIX & TOUCH VISUAL FIX ✅
//
// Updates:
// 1. validateAttempt: Added explicit check for Reversed PIN (Panic Code).
// 2. registerTouch: Fixed decay timer to prevent flickering (berkelip).
// 3. _decayTouch: Slowed down animation speed for smoother UI.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core & Models
import 'security_core.dart';
import 'motion_models.dart';
import 'cla_models.dart';

// 🧠 AI BRAINS
import 'behavioral_analyzer.dart';
import 'adaptive_threshold_engine.dart';

// Legacy compatibility
import 'cla_models.dart' as legacy;

/// Configuration for ClaController
class ClaConfig {
  final List<int> secret;
  final Duration minSolveTime;
  final double minShake;
  final double thresholdAmount;
  final int maxAttempts;
  final Duration jamCooldown;
  final Duration softLockCooldown;
  final bool enableSensors;
  final String clientId;
  final String clientSecret;
  final bool enforceReplayImmunity;
  final Duration nonceValidityWindow;
  final AttestationProvider? attestationProvider;

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    required this.thresholdAmount,
    this.maxAttempts = 3,
    this.jamCooldown = const Duration(seconds: 30),
    this.softLockCooldown = const Duration(seconds: 2),
    this.enableSensors = true,
    this.clientId = 'default_client',
    this.clientSecret = '',
    this.enforceReplayImmunity = true,
    this.nonceValidityWindow = const Duration(seconds: 60),
    this.attestationProvider,
  });

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

class ClaController extends ChangeNotifier {
  final ClaConfig config;
  late final SecurityCore _core;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // AI Engines
  late final BehavioralAnalyzer _behaviorAnalyzer;
  late final AdaptiveThresholdEngine _adaptiveEngine;

  // State Variables
  legacy.SecurityState _uiState = legacy.SecurityState.LOCKED;
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
  
  // ✅ FIX: Timer variable for controlling touch decay
  Timer? _touchDecayTimer; 

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

  // ============================================
  // SENSOR INPUT HANDLERS
  // ============================================

  void updateTumbling(List<int> values) {
    if (_isPaused || _uiState != legacy.SecurityState.LOCKED) return;
    currentValues = values;
  }

  void addMotionEvent(double magnitude, double dx, double dy, double dz) {
    if (_isPaused) return;

    final event = MotionEvent(
      magnitude: magnitude,
      timestamp: DateTime.now(),
      deltaX: dx,
      deltaY: dy,
      deltaZ: dz,
    );

    _motionBuffer.add(event);
    if (_motionBuffer.length > 50) _motionBuffer.removeAt(0);

    // Update UI Metrics
    _motionEntropyNotifier.value = _calculateEntropy();
  }

  // ✅ FIX 2: Better Touch Tracking (No Flickering)
  void registerTouch({double pressure = 0.5, double vx = 0, double vy = 0}) {
    if (_isPaused || _uiState == legacy.SecurityState.UNLOCKED) return;

    final event = TouchEvent(
      timestamp: DateTime.now(),
      pressure: pressure,
      velocityX: vx,
      velocityY: vy,
    );

    _touchBuffer.add(event);

    if (_touchBuffer.length > 50) {
      _touchBuffer.removeAt(0);
    }

    // ✅ FIX: Set touch score to 1.0 immediately for visual feedback
    _touchScoreNotifier.value = 1.0;
    
    // ✅ FIX: Reset decay timer so it doesn't decay while user is touching
    _touchDecayTimer?.cancel();
    _touchDecayTimer = Timer(const Duration(milliseconds: 500), () {
      Future.delayed(const Duration(milliseconds: 100), _decayTouch);
    });

    notifyListeners();
  }

  // ✅ FIX 1: Slower Decay for Smoother UI
  void _decayTouch() {
    if (_touchScoreNotifier.value > 0) {
      // Slow down decay rate (was 0.05, now 0.02)
      _touchScoreNotifier.value -= 0.02; 
      
      if (_touchScoreNotifier.value < 0) _touchScoreNotifier.value = 0;
      
      // Slower interval loop (was 50ms, now 100ms)
      Future.delayed(const Duration(milliseconds: 100), _decayTouch);
    }
  }

  // ============================================
  // CORE VALIDATION LOGIC
  // ============================================

  // ✅ FIX: Panic Mode Check Implemented Here
  Future<bool> validateAttempt({bool hasPhysicalMovement = true}) async {
    if (_core.state == legacy.SecurityState.HARD_LOCK) return false;

    _uiState = legacy.SecurityState.VALIDATING;
    _threatMessage = "";
    notifyListeners();

    // Artificial delay for UX
    await Future.delayed(const Duration(milliseconds: 300));

    // Prepare Biometric Session Data
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

    // Call Core Validation
    final result = await _core.validate(attempt);

    // ✅ FIX: Check panic BEFORE or ALONGSIDE processing result
    // Note: SecurityCore usually returns allowed=true for panic, but we double check here
    final reversedCode = config.secret.reversed.toList();
    final isPanic = listEquals(currentValues, reversedCode);

    if (result.allowed && isPanic) {
      _handleSuccess(panic: true, confidence: result.confidence);
      return true;
    }

    return _handleValidationResult(result);
  }

  bool _handleValidationResult(ValidationResult result) {
    if (result.allowed) {
      // Check threat level before allowing
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
    _uiState = legacy.SecurityState.UNLOCKED;
    _isPanicMode = panic;
    _threatMessage = panic ? "SILENT ALARM ACTIVATED" : "";
    _confidenceNotifier.value = confidence;
    _isPaused = true;
    
    _storage.deleteAll();
    
    notifyListeners();
  }

  void _handleFailure() {
    // Core updates its own state, we just sync UI
    if (_core.state == legacy.SecurityState.HARD_LOCK) {
      _uiState = legacy.SecurityState.HARD_LOCK;
    } else {
      _uiState = legacy.SecurityState.LOCKED;
    }
    
    _motionBuffer.clear();
    _touchBuffer.clear();
    notifyListeners();
  }

  // ============================================
  // HELPERS
  // ============================================

  void _startNewSession() {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStart = DateTime.now();
    _motionBuffer.clear();
    _touchBuffer.clear();
    _isPaused = false;
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

  // Advanced Features
  void reset() {
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
    };
  }

  String _generateNonce() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void dispose() {
    _touchDecayTimer?.cancel();
    _confidenceNotifier.dispose();
    _motionEntropyNotifier.dispose();
    _touchScoreNotifier.dispose();
    super.dispose();
  }
}
