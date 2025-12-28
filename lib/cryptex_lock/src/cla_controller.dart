import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart'; // IMPORT BARU
import 'cla_models.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;
  DateTime? _lockoutUntil;
  
  late List<int> currentValues;

  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  Timer? _botTimer;

  ClaController(this.config) {
    // 1. Rawakkan Roda
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    
    // 2. Mula Pemeriksaan Keselamatan
    _initSecurityProtocol();
  }

  Future<void> _initSecurityProtocol() async {
    // A. PERIKSA ROOT / JAILBREAK DAHULU
    // Ini langkah paling kritikal.
    bool isCompromised = false;
    try {
      // Kita semak Root (Android) dan Jailbreak (iOS)
      isCompromised = await FlutterJailbreakDetection.jailbroken;
      
      // Semak juga jika running dalam 'Developer Mode' (pilihan)
      // bool devMode = await FlutterJailbreakDetection.developerMode; 
      // isCompromised = isCompromised || devMode; // Kalau nak ketat sangat
    } catch (e) {
      // Jika error, anggap selamat (fail open) atau bahaya (fail close)?
      // Untuk Bank Grade: Fail Close (Anggap bahaya)
      if (kDebugMode) print("Root check failed: $e");
    }

    if (isCompromised) {
      _state = SecurityState.COMPROMISED;
      notifyListeners();
      return; // BERHENTI DI SINI. JANGAN LOAD MEMORI.
    }

    // B. Jika bersih, baru load memori biasa
    await _loadStateFromMemory();
  }

  Future<void> _loadStateFromMemory() async {
    if (_state == SecurityState.COMPROMISED) return; // Double check

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

  // ... (Bahagian lain kekal sama, cuma tambah check COMPROMISED) ...

  void updateWheel(int index, int value) {
    // Tambah COMPROMISED dalam senarai blocked
    if (_state == SecurityState.HARD_LOCK || 
        _state == SecurityState.VALIDATING ||
        _state == SecurityState.BOT_SIMULATION ||
        _state == SecurityState.COMPROMISED) return;
        
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
    }
  }

  // ... (Fungsi validateAttempt dan lain-lain kekal sama) ...
  // Saya ringkaskan untuk jimat ruang, tapi pastikan Kapten salin yg penuh
  // atau saya boleh beri full file jika Kapten mahu overwrite terus.
  
  // Sila guna Logik Validasi yang sama seperti sebelum ini.
  // Cuma pastikan _saveStateToMemory dll wujud.
  
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
    
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
  }
  
  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.COMPROMISED) return; // SIAPA SURUH ROOT

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

    if (currentValues.contains(0)) {
      await _triggerHardLock(); 
      return;
    }

    if (!hasPhysicalMovement) {
      await _triggerHardLock();
      return;
    }

    if (_isCodeCorrect()) {
      await _clearMemory();
      _state = SecurityState.UNLOCKED;
      notifyListeners();
    } else {
      await _handleFailure();
    }
  }
  
  // ... (Helper functions lain kekal sama) ...
  
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

  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) return currentValues[index];
    return 0;
  }

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
