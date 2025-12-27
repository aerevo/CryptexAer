import 'dart:async';
import 'dart:math'; // WAJIB
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cla_models.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  // State Machine
  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  // Memory
  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;
  DateTime? _lockoutUntil;
  
  // --- PEMBAIKAN UTAMA DI SINI ---
  // Jangan mula dengan [0,0,0,0,0].
  // Jana terus nombor rawak SEBELUM apa-apa berlaku.
  late List<int> currentValues;

  // Keys
  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  Timer? _botTimer;

  ClaController(this.config) {
    // 1. RAWAKKAN SERTA MERTA (Synchronous)
    // Ini pastikan bila UI tanya "Initial Value", nombor dah siap berterabur.
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    
    // 2. Baru panggil memori (Async)
    _loadStateFromMemory();
  }

  // --- MEMORI & STATE ---

  Future<void> _loadStateFromMemory() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt(KEY_ATTEMPTS) ?? 0;
    
    final lockTimestamp = prefs.getInt(KEY_LOCKOUT);
    if (lockTimestamp != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockTimestamp);
      
      // Semak penjara
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
        notifyListeners(); // Update UI jadi Merah
      } else {
        await _clearMemory(); 
      }
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
    _lockoutUntil = null;
    _state = SecurityState.LOCKED;
    
    // Selepas berjaya unlock, rawakkan semula untuk pusingan seterusnya
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
  }

  void updateWheel(int index, int value) {
    if (_state == SecurityState.HARD_LOCK || 
        _state == SecurityState.VALIDATING ||
        _state == SecurityState.BOT_SIMULATION) return;
        
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
    }
  }

  // --- LOGIK VALIDASI ---

  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.HARD_LOCK) {
      if (_lockoutUntil != null && DateTime.now().isAfter(_lockoutUntil!)) {
        await _clearMemory();
        notifyListeners();
      } else {
        return;
      }
    }

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    // ATURAN 1: HONEYPOT
    if (currentValues.contains(0)) {
      await _triggerHardLock(); 
      return;
    }

    // ATURAN 2: SENSOR FIZIKAL (DELTA MOVEMENT)
    if (!hasPhysicalMovement) {
      await _triggerHardLock();
      return;
    }

    // ATURAN 3: KOD RAHSIA
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
      await _triggerHardLock();
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

  Future<void> _triggerHardLock() async {
    _state = SecurityState.HARD_LOCK;
    _lockoutUntil = DateTime.now().add(config.jamCooldown);
    await _saveStateToMemory();
    notifyListeners();
  }

  bool _isCodeCorrect() {
    if (currentValues.length != config.secret.length) return false;
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }

  // Helper untuk UI dapatkan nilai awal (PENTING)
  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) {
      return currentValues[index];
    }
    return 0; // Default fallback
  }

  // --- BOT SIMULATION ---
  void startBotSimulation(VoidCallback onFinished) {
    if (_state == SecurityState.HARD_LOCK) return;
    _state = SecurityState.BOT_SIMULATION;
    notifyListeners();

    final rand = Random();
    int ticks = 0;
    
    _botTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      ticks++;
      for (int i = 0; i < currentValues.length; i++) {
        currentValues[i] = rand.nextInt(10);
      }
      notifyListeners();

      if (ticks >= 40) {
        timer.cancel();
        validateAttempt(hasPhysicalMovement: false);
      }
    });
  }

  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds;
  }
  
  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}
