// 🎮 Z-KINETIC CONTROLLER V3.3 (MEMORY SAFE - FIXED ✅)
// Status: PRODUCTION READY
// Location: lib/cryptex_lock/src/cla_controller_v2.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'security_core.dart';
import 'motion_models.dart';
import 'cla_models.dart';

import 'package:z_kinetic_pro/services/firebase_blackbox_client.dart';
import 'package:z_kinetic_pro/cryptex_lock/src/security/services/device_fingerprint.dart';

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

class ClaController extends ChangeNotifier {
  final ClaConfig config;
  late final SecurityCore _core;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FirebaseBlackBoxClient _blackBox = FirebaseBlackBoxClient();

  // State Variables
  SecurityState _uiState = SecurityState.LOCKED;
  bool _isPanicMode = false;
  String _threatMessage = "";
  String _currentSessionId = "";
  int _failedAttempts = 0;

  // ✅ NEW: Trigger for Random Wheel Rotation
  final ValueNotifier<bool> _shouldRandomizeWheels = ValueNotifier(false);
  ValueNotifier<bool> get shouldRandomizeWheels => _shouldRandomizeWheels;

  // Analysis Buffers
  final List<TouchEvent> _touchBuffer = [];
  final List<MotionEvent> _motionBuffer = [];

  // Public Notifiers for UI visualization
  final ValueNotifier<double> _touchScoreNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _motionEntropyNotifier = ValueNotifier(0.0);

  // Safety Flags
  bool _isDisposed = false;

  // Getters
  SecurityState get state => _uiState;
  bool get isPanicMode => _isPanicMode;
  String get threatMessage => _threatMessage;

  ValueNotifier<double> get touchScore => _touchScoreNotifier;
  ValueNotifier<double> get motionEntropyNotifier => _motionEntropyNotifier;

  // Computed getters for snapshot
  double get liveConfidence => _touchScoreNotifier.value;
  double get motionEntropy => _motionEntropyNotifier.value;
  int get failedAttempts => _failedAttempts;

  // Constructor
  ClaController({required this.config}) {
    _core = SecurityCore(config.toCoreConfig());
    _startNewSession();
  }

  // Lifecycle Methods
  void onInteractionStart() {
    if (_isDisposed) return;
    _uiState = SecurityState.LOCKED;
    notifyListeners();
  }

  // ✅ FIXED: Touch Registration
  void registerTouch(Offset position, double pressure, DateTime timestamp) {
    if (_isDisposed) return;
    
    _touchBuffer.add(TouchEvent(
      timestamp: timestamp,
      pressure: pressure,
      x: position.dx,
      y: position.dy,
      velocityX: 0,
      velocityY: 0,
    ));

    // Simple confidence simulation for UI feedback
    if (_touchBuffer.length > 2) {
      _touchScoreNotifier.value = (_touchBuffer.length / 15).clamp(0.0, 1.0);
    }
  }

  // ✅ FIXED: Motion Registration
  void registerMotion(double x, double y, double z, DateTime timestamp) {
    if (_isDisposed) return;
    
    final magnitude = sqrt(x * x + y * y + z * z);
    
    _motionBuffer.add(MotionEvent(
      magnitude: magnitude,
      timestamp: timestamp,
      deltaX: x,
      deltaY: y,
      deltaZ: z,
    ));

    // Update entropy every few frames
    if (_motionBuffer.length % 5 == 0) {
      _motionEntropyNotifier.value = _calculateEntropy();
    }
  }

  // ✅ FIXED: Main Verification Logic
  Future<ValidationResult> verify(List<int> inputCode) async {
    if (_isDisposed) {
      return ValidationResult(
        allowed: false,
        newState: SecurityState.LOCKED,
        threatLevel: ThreatLevel.HIGH_RISK,
        reason: 'CONTROLLER_DISPOSED',
        confidence: 0.0,
      );
    }

    // 1. Check Panic Mode (Reverse Code Logic)
    String inputStr = inputCode.join();
    String secretStr = config.secret.join();
    String reversedSecret = secretStr.split('').reversed.join();

    if (inputStr == reversedSecret) {
      _isPanicMode = true;
      _triggerSuccess();
      return ValidationResult.success(confidence: 1.0, isPanicMode: true);
    }

    // 2. Create BiometricData
    final biometricData = BiometricData(
      motionEvents: List.from(_motionBuffer),
      touchEvents: List.from(_touchBuffer),
      entropy: _calculateEntropy(),
    );

    // 3. Create ValidationAttempt
    final attempt = ValidationAttempt(
      attemptId: _generateNonce(),
      inputCode: inputCode,
      biometricData: biometricData,
      hasPhysicalMovement: _motionBuffer.isNotEmpty,
      timestamp: DateTime.now(),
    );

    // 4. Core Verification via SecurityCore
    final result = await _core.validate(attempt);

    if (result.allowed) {
      _triggerSuccess();
    } else {
      _failedAttempts++;
      _handleFailure();
    }

    return result;
  }

  void _triggerSuccess() {
    _uiState = SecurityState.UNLOCKED;
    notifyListeners();
  }

  void _handleFailure() {
    if (_isDisposed) return;

    if (_core.state == SecurityState.HARD_LOCK) {
      _uiState = SecurityState.HARD_LOCK;
      _threatMessage = "SYSTEM LOCKED: TOO MANY ATTEMPTS";
    } else {
      _uiState = SecurityState.LOCKED;
    }

    // ✅ TRIGGER RANDOM WHEELS
    _shouldRandomizeWheels.value = !_shouldRandomizeWheels.value;

    // Clear buffers for next attempt
    _motionBuffer.clear();
    _touchBuffer.clear();

    // Reset visual scores
    _touchScoreNotifier.value = 0.0;

    notifyListeners();
  }

  // Helper: Calculate Entropy
  double _calculateEntropy() {
    if (_motionBuffer.isEmpty) return 0.0;

    Map<int, int> distribution = {};
    int total = _motionBuffer.length;

    // Categorize Z-axis movement into buckets
    for (var m in _motionBuffer) {
      int bucket = (m.deltaZ * 10).round();
      distribution[bucket] = (distribution[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    distribution.forEach((_, count) {
      double probability = count / total;
      if (probability > 0) {
        entropy += probability * (1 - probability);
      }
    });

    return (entropy / 0.25).clamp(0.0, 1.0);
  }

  // Session Management
  void _startNewSession() {
    _currentSessionId = _generateNonce();
    _failedAttempts = 0;
  }

  String _generateNonce() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Public Reset
  void reset() {
    if (_isDisposed) return;

    _core.reset();
    _uiState = SecurityState.LOCKED;
    _isPanicMode = false;
    _threatMessage = "";
    _touchScoreNotifier.value = 0.0;
    _motionEntropyNotifier.value = 0.0;
    _startNewSession();
    notifyListeners();
  }

  // Snapshot for Analytics
  Map<String, dynamic> getSessionSnapshot() {
    return {
      'session_id': _currentSessionId,
      'motion_events': _motionBuffer.length,
      'touch_events': _touchBuffer.length,
      'confidence': liveConfidence,
      'entropy': motionEntropy,
      'state': _uiState.toString(),
      'failed_attempts': failedAttempts,
    };
  }

  @override
  void dispose() {
    _shouldRandomizeWheels.dispose();
    _isDisposed = true;
    _touchScoreNotifier.dispose();
    _motionEntropyNotifier.dispose();
    super.dispose();
  }
}
