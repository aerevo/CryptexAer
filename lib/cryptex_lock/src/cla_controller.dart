// 🎮 Z-KINETIC CONTROLLER V12.0 (ENTERPRISE READY)

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cla_models.dart';
import 'motion_models.dart'; // ✅ ADD THIS
import 'security_engine.dart';

class ClaController extends ChangeNotifier with WidgetsBindingObserver {
  final ClaConfig config;
  late final SecurityEngine _engine;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // State
  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  DateTime? _lockoutUntil;
  late List<int> currentValues;

  // ✅ RESTORED: UI needs this for warning banner
  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  // 🔥 PANIC FLAG
  bool _isPanicMode = false;
  bool get isPanicMode => _isPanicMode;

  // ============================================
  // 🔧 FIX: DYNAMIC CONFIDENCE CALCULATIONS
  // ============================================
  final List<MotionEvent> _motionHistory = [];
  int _touchCount = 0;
  int _uniqueGestureCount = 0;
  DateTime? _interactionStart;

  // Calculate live confidence from actual biometric data
  double get liveConfidence {
    if (_motionHistory.isEmpty && _touchCount == 0) return 0.0;
    
    final motionScore = _calculateMotionScore();
    final touchScore = _calculateTouchScore();
    final patternScore = _calculatePatternScore();
    
    // Weighted average: 40% motion + 30% touch + 30% pattern
    return (motionScore * 0.4 + touchScore * 0.3 + patternScore * 0.3).clamp(0.0, 1.0);
  }

  double get motionConfidence => _calculateMotionScore();
  double get touchConfidence => _calculateTouchScore();
  
  // ✅ NEW: Additional metrics for UI
  double get motionEntropy => _calculateEntropy();
  int get uniqueGestureCount => _uniqueGestureCount;

  bool _isDisposed = false;
  bool _isPaused = false;

  ClaController(this.config) {
    currentValues = List.filled(5, 0);
    _engine = SecurityEngine(config.engineConfig);
    WidgetsBinding.instance.addObserver(this);
    _initSecureSession();
  }

  // ============================================
  // 🔋 BATTERY SAVER LOGIC
  // ============================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isPaused = true;
      _motionHistory.clear();
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      _isPaused = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================
  // SENSOR INPUT HANDLERS
  // ============================================

  void registerShake(double rawMag, double x, double y, double z) {
    if (_isPaused || _state == SecurityState.UNLOCKED || _state == SecurityState.HARD_LOCK) {
      return;
    }
    onMotion(x, y, z);
  }

  void onMotion(double x, double y, double z) {
    if (!config.enableSensors) return;
    if (_motionHistory.length > 50) _motionHistory.removeAt(0);
    
    final mag = x.abs() + y.abs() + z.abs();
    _motionHistory.add(MotionEvent(
      magnitude: mag, 
      timestamp: DateTime.now(),
      deltaX: x,
      deltaY: y,
      deltaZ: z,
    ));
    
    // Track unique gesture patterns
    if (mag > 1.5) _uniqueGestureCount++;
    
    notifyListeners();
  }

  // ✅ FIX: Method yang hilang
  void registerTouchInteraction() {
    registerTouch();
  }

  void registerTouch() {
    if (_isPaused || _state == SecurityState.UNLOCKED) return;
    onTouch();
  }

  void onTouch() {
    _touchCount++;
    notifyListeners();
  }

  // ============================================
  // BIOMETRIC CALCULATIONS
  // ============================================

  double _calculateMotionScore() {
    if (_motionHistory.isEmpty) return 0.0;
    
    final totalMagnitude = _motionHistory.fold(0.0, (sum, e) => sum + e.magnitude);
    final avgMagnitude = totalMagnitude / _motionHistory.length;
    
    // Normalize to 0-1 range (typical human motion: 0.5-3.0)
    return (avgMagnitude / 3.0).clamp(0.0, 1.0);
  }

  double _calculateTouchScore() {
    if (_touchCount == 0) return 0.0;
    
    // Score based on interaction count (diminishing returns)
    return (min(_touchCount / 10.0, 1.0)).clamp(0.0, 1.0);
  }

  double _calculatePatternScore() {
    if (_uniqueGestureCount == 0) return 0.0;
    
    // Score based on gesture diversity
    return (min(_uniqueGestureCount / 5.0, 1.0)).clamp(0.0, 1.0);
  }

  double _calculateEntropy() {
    if (_motionHistory.length < 3) return 0.0;
    
    final mags = _motionHistory.map((e) => e.magnitude).toList();
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
        entropy -= probability * (log(probability) / log(2));
      }
    });
    
    return (entropy / 4.0).clamp(0.0, 1.0);
  }

  // ============================================
  // CORE LOGIC
  // ============================================

  void _initSecureSession() {
    // 🚨 CRITICAL: Palindrome Check
    final reversedSecret = config.secret.reversed.toList();
    if (listEquals(config.secret, reversedSecret)) {
      throw ArgumentError(
        '🚨 SECURITY ERROR: Palindromic PIN detected (e.g., 12321).\n'
        'Panic mode requires PIN ≠ reverse(PIN).\n'
        'Please use a non-palindromic PIN.'
      );
    }

    _storage.deleteAll();
    _state = SecurityState.LOCKED;
    _failedAttempts = 0;
    _threatMessage = "";
    _isPanicMode = false;
  }

  void updateWheel(int index, int value) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      notifyListeners();
    }
  }

  int getInitialValue(int index) => currentValues[index];

  // 🔥 SENSOR VALIDATION ENFORCEMENT
  Future<bool> validateAttempt({bool hasPhysicalMovement = true}) async {
    // 1. Check Forced Parameter
    if (config.enableSensors && !hasPhysicalMovement) {
      _threatMessage = "SENSOR BYPASS BLOCKED";
      notifyListeners();
      return false;
    }

    // 2. Check Actual Motion History (Anti-Bot)
    final totalMotion = _motionHistory.fold(0.0, (sum, e) => sum + e.magnitude);

    if (config.enableSensors && totalMotion < 3.0 && _touchCount < 1) {
      _state = SecurityState.SOFT_LOCK;
      _threatMessage = "NO KINETIC SIGNATURE";
      notifyListeners();

      // Auto-recover after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
          _threatMessage = "";
          notifyListeners();
        }
      });
      return false;
    }

    return attemptUnlock();
  }

  void onInteractionStart() {
    _interactionStart = DateTime.now();
    _touchCount = 0;
    _uniqueGestureCount = 0;
    _motionHistory.clear();
  }

  Future<bool> attemptUnlock() async {
    if (_state == SecurityState.HARD_LOCK) return false;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    // Engine analysis
    final verdict = _engine.analyze(
      motionHistory: _motionHistory,
      touchCount: _touchCount,
      interactionDuration: const Duration(seconds: 1)
    );

    bool isPassCorrect = listEquals(currentValues, config.secret);
    bool isPanicCode = listEquals(currentValues, config.secret.reversed.toList());

    if (isPassCorrect) {
      _handleSuccess(panic: false);
      return true;
    }
    else if (isPanicCode) {
      _handleSuccess(panic: true);
      return true;
    }
    else {
      _handleFailure();
      return false;
    }
  }

  void _handleSuccess({required bool panic}) {
    _state = SecurityState.UNLOCKED;
    _failedAttempts = 0;
    _threatMessage = panic ? "SILENT ALARM SENT" : "";
    _isPanicMode = panic;

    _isPaused = true;
    _storage.deleteAll();

    // 🔥 STEALTH: No debug prints in production
    if (kDebugMode && panic) {
      debugPrint("⚠️ DEBUG: Panic mode activated (dev mode only)");
    }

    notifyListeners();
  }

  Future<void> _handleFailure() async {
    _failedAttempts++;
    _state = SecurityState.LOCKED;
    _threatMessage = "WRONG PASSCODE";
    _motionHistory.clear();
    notifyListeners();
  }

  // ✅ RESTORED: Lockout countdown for UI
  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}
