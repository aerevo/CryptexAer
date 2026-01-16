// 🎮 Z-KINETIC CONTROLLER V9.0 (FINAL GOLD)
// Status: PANIC MODE ENABLED 🚨
// Feature: 
// 1. Detects Reverse PIN as Panic Code.
// 2. Fakes a successful unlock.
// 3. Flags 'isPanicMode' for the UI to wipe data.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cla_models.dart';
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
  
  String _threatMessage = "";
  String get threatMessage => _threatMessage;
  
  // 🔥 PANIC FLAG
  bool _isPanicMode = false;
  bool get isPanicMode => _isPanicMode;

  // Getters UI
  double get liveConfidence => 1.0; 
  double get motionConfidence => 1.0;
  double get touchConfidence => 1.0;

  final List<MotionEvent> _motionHistory = [];
  int _touchCount = 0;
  DateTime? _interactionStart;

  bool _isDisposed = false;
  bool _isPaused = false;

  ClaController(this.config) {
    currentValues = List.filled(5, 0);
    _engine = SecurityEngine(config.engineConfig);
    WidgetsBinding.instance.addObserver(this);
    _initSecureSession();
  }

  // --- 🔋 BATTERY SAVER LOGIC ---

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

  // --- LOGIC SENSOR ---

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
    _motionHistory.add(MotionEvent(magnitude: mag, timestamp: DateTime.now()));
  }

  void registerTouch() { 
    if (_isPaused || _state == SecurityState.UNLOCKED) return;
    onTouch(); 
  }
  
  void onTouch() {
    _touchCount++;
  }

  // --- CORE LOGIC ---

  void _initSecureSession() {
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
  
  Future<bool> validateAttempt({bool hasPhysicalMovement = true}) async {
    return attemptUnlock();
  }

  void onInteractionStart() {
    _interactionStart = DateTime.now();
    _touchCount = 0;
    _motionHistory.clear();
  }

  Future<bool> attemptUnlock() async {
    if (_state == SecurityState.HARD_LOCK) return false;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    // Engine Check
    final verdict = _engine.analyze(
      motionHistory: _motionHistory, 
      touchCount: _touchCount, 
      interactionDuration: const Duration(seconds: 1)
    );

    // 1. Check Passcode Betul
    bool isPassCorrect = listEquals(currentValues, config.secret);
    
    // 2. Check Panic Code (Nombor Terbalik)
    // 🔥 PANIC LOGIC: Reverse the secret list
    bool isPanicCode = listEquals(currentValues, config.secret.reversed.toList());

    if (isPassCorrect) {
      _handleSuccess(panic: false);
      return true;
    } 
    else if (isPanicCode) {
      // 🔥 TRICK: Kalau Panic Code, kita tetap panggil SUCCESS
      // supaya perompak tak tahu. Tapi kita set flag panic.
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
    _isPanicMode = panic; // Simpan status panic untuk UI baca
    
    _isPaused = true; 
    _storage.deleteAll();
    
    if (panic) {
      debugPrint("🚨 DURESS SIGNAL TRIGGERED! FAKING SUCCESS UI.");
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
  
  int get remainingLockoutSeconds => 0; 
}
