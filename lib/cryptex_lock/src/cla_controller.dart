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
  double _accumulatedShake = 0; // Sensor Data Staging

  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  Timer? _botTimer;
  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  ClaController(this.config) {
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    _initSecurityProtocol();
  }

  // --- 1. ANJING PENJAGA (Diaktifkan) ---
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
      _threatMessage = "PERANTI ROOT DIKESAN";
      _state = SecurityState.ROOT_WARNING;
      notifyListeners();
      return; 
    }
    
    // Kita warning je kalau debug, jangan block terus masa development
    if (isUsbDebug && !kDebugMode) {
      _threatMessage = "USB DEBUGGING AKTIF";
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

  // --- 2. MEMORI (Persistent Storage) ---
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
    if (_state == SecurityState.HARD_LOCK || 
        _state == SecurityState.VALIDATING ||
        _state == SecurityState.ROOT_WARNING) return;
        
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
    }
  }

  // Terima data dari Widget (Telinga)
  void registerShake(double val) {
    _accumulatedShake += val;
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
  }
  
  // --- 3. VALIDATION LOGIC (Complex) ---
  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500)); // Suspense effect

    // LOGIK SENSOR CANGGIH
    if (config.enableSensors) {
      // Kalau sensor kata 0.0 (Emulator) ATAU UI kata tak ada movement
      if (!hasPhysicalMovement && _accumulatedShake < 0.1) {
         // Bot Detected!
         await _handleFailure();
         return;
      }
    }

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
      Future.delayed(const Duration(seconds: 2), () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
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
    return _lockoutUntil!.difference(DateTime.now()).inSeconds;
  }
}
