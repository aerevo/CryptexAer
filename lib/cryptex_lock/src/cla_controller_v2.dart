// 🎮 Z-KINETIC CONTROLLER V3.2 (FIREBASE BLACK BOX)
// Status: BUILD ERRORS FIXED ✅

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core & Models
import 'security_core.dart';
import 'motion_models.dart';
import 'cla_models.dart';

// 🔥 FIREBASE BLACK BOX (FIXED PATHS!)
import '../../services/firebase_blackbox_client.dart';
import '../../models/blackbox_verdict.dart';
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

  SecurityState _uiState = SecurityState.LOCKED;
  List<int> currentValues = [0, 0, 0, 0, 0];
  String _currentSessionId = '';
  DateTime? _sessionStart;

  final List<MotionEvent> _motionBuffer = [];
  final List<TouchEvent> _touchBuffer = [];

  // 👇 TAMBAH DI SINI 👇
  List<MotionEvent> get motionBuffer => List.unmodifiable(_motionBuffer);
  List<TouchEvent> get touchBuffer => List.unmodifiable(_touchBuffer);
  // 👆 TAMBAH DI SINI 👆
  
  final ValueNotifier<double> _confidenceNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _motionEntropyNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _touchScoreNotifier = ValueNotifier(0.0);

  String _threatMessage = "";
  bool _isPanicMode = false;
  bool _isPaused = false;
  Timer? _touchDecayTimer;
  bool _isDisposed = false;

  ClaController(this.config) {
    _core = SecurityCore(config.toCoreConfig());
    _startNewSession();
  }

  SecurityState get state => _uiState;
  int get failedAttempts => _core.failedAttempts;
  bool get isPanicMode => _isPanicMode;
  String get threatMessage => _threatMessage;
  ValueNotifier<double> get confidenceNotifier => _confidenceNotifier;
  ValueNotifier<double> get motionEntropyNotifier => _motionEntropyNotifier;
  ValueNotifier<double> get touchScoreNotifier => _touchScoreNotifier;
  double get liveConfidence => _confidenceNotifier.value;
  double get motionEntropy => _motionEntropyNotifier.value;
  int get remainingLockoutSeconds => _core.remainingLockoutSeconds;

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
    if (_isDisposed || _isPaused || _uiState == SecurityState.UNLOCKED) return;
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
    if (_isDisposed || _isPaused || _uiState == SecurityState.UNLOCKED) return;
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
    if (_isDisposed || _core.state == SecurityState.HARD_LOCK) return false;
    _uiState = SecurityState.VALIDATING;
    _threatMessage = "";
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

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

    try {
      final deviceId = await DeviceFingerprint.getDeviceId();
      final nonce = _generateNonce();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final verdict = await _blackBox.analyze(
        deviceId: deviceId,
        biometric: bioSession!,
        sessionId: _currentSessionId,
        nonce: nonce,
        timestamp: timestamp,
      );

      if (verdict.allowed) {
        final reversedCode = config.secret.reversed.toList();
        final isPanic = _listEquals(currentValues, reversedCode);
        _handleSuccess(panic: isPanic, confidence: verdict.confidence);
        return true;
      } else {
        _threatMessage = verdict.reason ?? 'Verification failed';
        _handleFailure();
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Firebase error: $e');
      _threatMessage = "Server unreachable";
      _handleFailure();
      return false;
    }
  }

  void _handleSuccess({required bool panic, required double confidence}) {
    if (_isDisposed) return;
    _uiState = SecurityState.UNLOCKED;
    _isPanicMode = panic;
    _threatMessage = panic ? "SILENT ALARM ACTIVATED" : "";
    _confidenceNotifier.value = confidence;
    _isPaused = true;
    _storage.deleteAll();
    notifyListeners();
  }

  void _handleFailure() {
    if (_isDisposed) return;
    if (_core.state == SecurityState.HARD_LOCK) {
      _uiState = SecurityState.HARD_LOCK;
    } else {
      _uiState = SecurityState.LOCKED;
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

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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
    if (_isDisposed) return;
    _isDisposed = true;
    _touchDecayTimer?.cancel();
    _motionBuffer.clear();
    _touchBuffer.clear();
    currentValues.clear();
    _confidenceNotifier.dispose();
    _motionEntropyNotifier.dispose();
    _touchScoreNotifier.dispose();
    _core.reset();
    _storage.deleteAll();
    super.dispose();
  }
}
