// 🎮 Z-KINETIC CONTROLLER V2.0 (PRODUCTION ARCHITECTURE)
// Status: BRIDGE TO HEADLESS CORE ✅
// 
// PURPOSE: Adapter between Flutter UI and headless SecurityCore
// - Maintains existing API (backward compatible)
// - Delegates security logic to SecurityCore
// - Manages Flutter-specific concerns (notifications, lifecycle)
// - Collects biometric data from sensors
//
// MIGRATION PATH:
// Old: UI → ClaController → SecurityEngine
// New: UI → ClaControllerV2 → SecurityCore (headless)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// New headless core
import 'security_core.dart';
import 'motion_models.dart';

// Legacy models (for backward compatibility)
import 'cla_models.dart' as legacy;

/// Configuration for ClaController (Flutter-specific wrapper)
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

  // Advanced options
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

  /// Convert to SecurityCoreConfig
  SecurityCoreConfig toCoreConfig() {
    return SecurityCoreConfig(
      expectedCode: secret,
      maxAttemptAge: minSolveTime,
      maxFailedAttempts: maxAttempts,
      lockoutDuration: jamCooldown,
      minConfidence: 0.30,
      botThreshold: 0.40,
      minEntropy: 0.15,
      enforceReplayImmunity: enforceReplayImmunity,
      nonceValidityWindow: nonceValidityWindow,
      attestationProvider: attestationProvider,
    );
  }
}

/// Flutter adapter for SecurityCore
class ClaController extends ChangeNotifier with WidgetsBindingObserver {
  final ClaConfig config;
  late final SecurityCore _core;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Flutter-specific state
  legacy.SecurityState _uiState = legacy.SecurityState.LOCKED;
  legacy.SecurityState get state => _uiState;

  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  bool _isPanicMode = false;
  bool get isPanicMode => _isPanicMode;

  // Biometric data collection
  final List<MotionEvent> _motionBuffer = [];
  final List<TouchEvent> _touchBuffer = [];
  DateTime? _sessionStart;
  String? _currentSessionId;

  // UI wheel state (Flutter-specific)
  late List<int> currentValues;

  // Lifecycle management
  bool _isDisposed = false;
  bool _isPaused = false;

  ClaController(this.config) {
    // Initialize headless core
    _core = SecurityCore(config.toCoreConfig());
    
    currentValues = List.filled(5, 0);
    WidgetsBinding.instance.addObserver(this);
    _initSecureSession();
  }

  // ============================================
  // LIFECYCLE MANAGEMENT
  // ============================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isPaused = true;
      _flushSession(); // Save any pending biometric data
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      _isPaused = false;
      _startNewSession();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _flushSession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================
  // SESSION MANAGEMENT
  // ============================================

  void _initSecureSession() {
    _storage.deleteAll();
    _startNewSession();
  }

  void _startNewSession() {
    _sessionStart = DateTime.now();
    _currentSessionId = _generateSessionId();
    _motionBuffer.clear();
    _touchBuffer.clear();
  }

  void _flushSession() {
    // In production, could save session data for analytics
    _motionBuffer.clear();
    _touchBuffer.clear();
  }

  String _generateSessionId() {
    return 'SESSION-${DateTime.now().millisecondsSinceEpoch}';
  }

  // ============================================
  // BIOMETRIC DATA COLLECTION (From Sensors)
  // ============================================

  /// Register motion sensor data
  void registerShake(double rawMag, double x, double y, double z) {
    if (_isPaused || _uiState == legacy.SecurityState.UNLOCKED) return;
    if (!config.enableSensors) return;

    final event = MotionEvent(
      magnitude: rawMag,
      timestamp: DateTime.now(),
      deltaX: x,
      deltaY: y,
      deltaZ: z,
    );

    _motionBuffer.add(event);
    
    // Keep buffer size manageable
    if (_motionBuffer.length > 100) {
      _motionBuffer.removeAt(0);
    }

    notifyListeners();
  }

  /// Register touch interaction
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

    notifyListeners();
  }

  /// Alias for backward compatibility
  void registerTouchInteraction() => registerTouch();

  /// Mark start of interaction
  void onInteractionStart() {
    _startNewSession();
  }

  // ============================================
  // UI STATE MANAGEMENT
  // ============================================

  /// Update wheel value (UI-specific)
  void updateWheel(int index, int value) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      notifyListeners();
    }
  }

  int getInitialValue(int index) => currentValues[index];

  // ============================================
  // VALIDATION (Bridge to Core)
  // ============================================

  /// Main validation entry point
  Future<bool> validateAttempt({bool hasPhysicalMovement = true}) async {
    if (_core.state == SecurityState.HARD_LOCK) return false;

    // Update UI state
    _uiState = legacy.SecurityState.VALIDATING;
    _threatMessage = "";
    notifyListeners();

    // Small delay for UI feedback
    await Future.delayed(const Duration(milliseconds: 300));

    // Build biometric session
    BiometricSession? bioSession;
    if (_motionBuffer.isNotEmpty || _touchBuffer.isNotEmpty) {
      bioSession = BiometricSession(
        sessionId: _currentSessionId ?? _generateSessionId(),
        startTime: _sessionStart ?? DateTime.now(),
        motionEvents: List.from(_motionBuffer),
        touchEvents: List.from(_touchBuffer),
        duration: DateTime.now().difference(_sessionStart ?? DateTime.now()),
      );
    }

    // Build validation attempt
    final attempt = ValidationAttempt(
      attemptId: ReplayTracker.generateNonce(),
      timestamp: DateTime.now(),
      inputCode: List.from(currentValues),
      biometricData: bioSession,
      hasPhysicalMovement: hasPhysicalMovement || _motionBuffer.isNotEmpty,
    );

    // Delegate to core
    final result = await _core.validate(attempt);

    // Process result
    return _handleValidationResult(result);
  }

  /// Process validation result from core
  bool _handleValidationResult(ValidationResult result) {
    if (result.allowed) {
      // Success handling
      final isPanic = result.metadata['panic_mode'] == true;
      _handleSuccess(panic: isPanic, confidence: result.confidence);
      return true;
    } else {
      // Failure handling
      _handleFailure(result);
      return false;
    }
  }

  void _handleSuccess({required bool panic, required double confidence}) {
    _uiState = legacy.SecurityState.UNLOCKED;
    _isPanicMode = panic;
    _threatMessage = panic ? "SILENT ALARM ACTIVATED" : "";
    _isPaused = true;
    _storage.deleteAll();

    if (kDebugMode && panic) {
      debugPrint("⚠️ DEBUG: Panic mode activated");
    }

    notifyListeners();
  }

  void _handleFailure(ValidationResult result) {
    // Map core state to UI state
    switch (result.newState) {
      case SecurityState.SOFT_LOCK:
        _uiState = legacy.SecurityState.SOFT_LOCK;
        _threatMessage = _translateReason(result.reason);
        
        // Auto-recover after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (_uiState == legacy.SecurityState.SOFT_LOCK) {
            _uiState = legacy.SecurityState.LOCKED;
            _threatMessage = "";
            notifyListeners();
          }
        });
        break;

      case SecurityState.HARD_LOCK:
        _uiState = legacy.SecurityState.HARD_LOCK;
        _threatMessage = "SYSTEM LOCKED - ${_core.remainingLockoutSeconds}s";
        break;

      default:
        _uiState = legacy.SecurityState.LOCKED;
        _threatMessage = _translateReason(result.reason);
    }

    _motionBuffer.clear();
    _touchBuffer.clear();
    notifyListeners();
  }

  String _translateReason(String reason) {
    switch (reason) {
      case 'INVALID_CODE':
        return "WRONG PASSCODE";
      case 'BOT_DETECTED':
        return "NO KINETIC SIGNATURE";
      case 'LOW_CONFIDENCE':
        return "INSUFFICIENT BIOMETRIC DATA";
      case 'REPLAY_DETECTED':
        return "REPLAY ATTACK BLOCKED";
      case 'ATTESTATION_FAILED':
        return "DEVICE VERIFICATION FAILED";
      case 'SYSTEM_LOCKED':
        return "MAXIMUM ATTEMPTS EXCEEDED";
      default:
        return reason;
    }
  }

  // ============================================
  // METRICS (For UI Display)
  // ============================================

  /// Live confidence score
  double get liveConfidence {
    if (_motionBuffer.isEmpty && _touchBuffer.isEmpty) return 0.0;
    
    final motionScore = _calculateMotionScore();
    final touchScore = _calculateTouchScore();
    final entropyScore = _calculateEntropy();
    
    return (motionScore * 0.4 + touchScore * 0.3 + entropyScore * 0.3)
        .clamp(0.0, 1.0);
  }

  double get motionConfidence => _calculateMotionScore();
  double get touchConfidence => _calculateTouchScore();
  double get motionEntropy => _calculateEntropy();
  
  int get uniqueGestureCount {
    return _motionBuffer.where((e) => e.magnitude > 1.5).length;
  }

  int get failedAttempts => _core.failedAttempts;
  int get remainingLockoutSeconds => _core.remainingLockoutSeconds;

  double _calculateMotionScore() {
    if (_motionBuffer.isEmpty) return 0.0;
    
    final totalMagnitude = _motionBuffer.fold(0.0, (sum, e) => sum + e.magnitude);
    final avgMagnitude = totalMagnitude / _motionBuffer.length;
    
    return (avgMagnitude / 3.0).clamp(0.0, 1.0);
  }

  double _calculateTouchScore() {
    if (_touchBuffer.isEmpty) return 0.0;
    
    final count = _touchBuffer.length;
    return (count / 10.0).clamp(0.0, 1.0);
  }

  double _calculateEntropy() {
    if (_motionBuffer.length < 3) return 0.0;
    
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
        // Simplified entropy calculation
        entropy += probability * (1 - probability);
      }
    });
    
    return (entropy / 0.25).clamp(0.0, 1.0); // Normalize
  }

  // ============================================
  // ADVANCED FEATURES
  // ============================================

  /// Reset controller state
  void reset() {
    _core.reset();
    _uiState = legacy.SecurityState.LOCKED;
    _isPanicMode = false;
    _threatMessage = "";
    _startNewSession();
    notifyListeners();
  }

  /// Get current session data (for debugging/analytics)
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

  /// Export session for server validation (if needed)
  BiometricSession? exportSession() {
    if (_motionBuffer.isEmpty && _touchBuffer.isEmpty) return null;

    return BiometricSession(
      sessionId: _currentSessionId ?? _generateSessionId(),
      startTime: _sessionStart ?? DateTime.now(),
      motionEvents: List.from(_motionBuffer),
      touchEvents: List.from(_touchBuffer),
      duration: DateTime.now().difference(_sessionStart ?? DateTime.now()),
    );
  }
}
