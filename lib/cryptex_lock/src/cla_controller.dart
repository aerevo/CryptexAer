import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // WAJIB ADA
import 'cla_config.dart';
import 'cla_models.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  // State Machine
  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  // Ingatan Dosa
  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;
  
  DateTime? _lockoutUntil;
  List<int> currentValues = [1, 1, 1, 1, 1];

  // Kunci Memori (Database Key)
  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  ClaController(this.config) {
    _loadStateFromMemory(); // BACA MEMORI BILA MULA
  }

  // --- 1. MEMORI KEKAL (PERSISTENCE) ---
  
  Future<void> _loadStateFromMemory() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Ambil rekod dosa lama
    _failedAttempts = prefs.getInt(KEY_ATTEMPTS) ?? 0;
    
    // 2. Ambil rekod hukuman (jika ada)
    final lockTimestamp = prefs.getInt(KEY_LOCKOUT);
    if (lockTimestamp != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockTimestamp);
      
      // Jika masih dalam tempoh hukuman, terus set HARD_LOCK
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
      } else {
        // Hukuman dah tamat semasa app tutup
        _clearMemory(); 
      }
    }
    notifyListeners();
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
  }

  void updateWheel(int index, int value) {
    if (_state == SecurityState.HARD_LOCK || _state == SecurityState.VALIDATING) return;
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
    }
  }

  // --- 2. ENJIN VALIDASI ---

  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    // Semak status denda
    if (_state == SecurityState.HARD_LOCK) {
      if (_lockoutUntil != null && DateTime.now().isAfter(_lockoutUntil!)) {
        await _clearMemory(); // Bebas dari penjara
        notifyListeners();
      } else {
        return; // Masih dalam penjara
      }
    }

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    // ATURAN 1: HONEYPOT (MAUT)
    if (currentValues.contains(0)) {
      await _triggerHardLock(); 
      return;
    }

    // ATURAN 2: SENSOR FIZIKAL (MAUT)
    if (!hasPhysicalMovement) {
      await _triggerHardLock();
      return;
    }

    // ATURAN 3: KOD RAHSIA
    if (_isCodeCorrect()) {
      // BERJAYA
      await _clearMemory(); // Bersihkan rekod dosa
      _state = SecurityState.UNLOCKED;
      notifyListeners();
    } else {
      // GAGAL
      await _handleFailure();
    }
  }

  Future<void> _handleFailure() async {
    _failedAttempts++;
    await _saveStateToMemory(); // SIMPAN DOSA SEGERA

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
    await _saveStateToMemory(); // SIMPAN HUKUMAN SEGERA
    notifyListeners();
  }

  bool _isCodeCorrect() {
    if (currentValues.length != config.secret.length) return false;
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }

  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds;
  }
}
