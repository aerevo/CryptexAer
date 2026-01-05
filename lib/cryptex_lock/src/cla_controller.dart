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
  
  // ═══════════════════════════════════════════════════════════
  // 🖐️ HYBRID ENGINE (TOUCH + MOTION)
  // ═══════════════════════════════════════════════════════════
  
  // 1. TOUCH METRICS (80% WEIGHT)
  final List<int> _scrollTimestamps = []; // Rekod masa setiap sentuhan
  int _interactionCount = 0;
  
  // 2. MOTION METRICS (20% WEIGHT)
  double _accumulatedMotion = 0.0;
  bool _hasLivingSensor = false; // Sensor hidup atau mati (Emulator = Mati)
  
  // Live Confidence (Gabungan Touch + Motion)
  double _liveConfidence = 0.0;
  double get liveConfidence => _liveConfidence;

  // ═══════════════════════════════════════════════════════════
  
  static const String KEY_ATTEMPTS = 'cla_failed_attempts';
  static const String KEY_LOCKOUT = 'cla_lockout_timestamp';

  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  ClaController(this.config) {
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    _initSecurityProtocol();
  }

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
      _threatMessage = "CRITICAL: ROOT ACCESS DETECTED";
      _state = SecurityState.ROOT_WARNING;
      notifyListeners();
      return; 
    }
    await _loadStateFromMemory();
  }
  
  void userAcceptsRisk() {
    _state = SecurityState.LOCKED;
    notifyListeners();
    _loadStateFromMemory();
  }

  // ═══════════════════════════════════════════════════════════
  // 🧠 THE HYBRID BRAIN
  // ═══════════════════════════════════════════════════════════

  // Dipanggil bila roda dipusing (Input Manusia)
  void registerScrollInteraction() {
    if (_state != SecurityState.LOCKED) return;
    
    int now = DateTime.now().millisecondsSinceEpoch;
    _scrollTimestamps.add(now);
    _interactionCount++;
    
    // Limit sejarah (untuk jimat memori)
    if (_scrollTimestamps.length > 20) _scrollTimestamps.removeAt(0);
    
    _calculateHybridScore();
  }

  // Dipanggil oleh sensor (Check denyut nadi device)
  void registerMotionActivity(double magnitude) {
    if (_state != SecurityState.LOCKED) return;
    
    // Mudah je: Kalau ada gerak sikit (> 0.05), device ni HIDUP.
    // Emulator biasanya 0.000000.
    if (magnitude > 0.05) {
      _accumulatedMotion += magnitude;
      _hasLivingSensor = true;
    }
    
    // Kita update score, tapi sensor cuma sumbang sikit je.
    // Jangan bagi dia kuasa penuh sampai meter menggila.
    if (_interactionCount > 0) { // Cuma update kalau user dah mula tekan
       _calculateHybridScore();
    }
  }

  void _calculateHybridScore() {
    // 1. TOUCH SCORE (80%)
    // Manusia perlukan sekurang-kurangnya 3-5 interaksi untuk nampak "Real"
    double touchScore = (_interactionCount / 5.0).clamp(0.0, 1.0);
    
    // Analisis Masa (Manusia tak konsisten)
    if (_scrollTimestamps.length >= 3) {
      // Kalau user tekan terlalu laju (< 50ms beza), itu BOT.
      int lastDelta = _scrollTimestamps.last - _scrollTimestamps[_scrollTimestamps.length-2];
      if (lastDelta < 50) {
        touchScore = 0.0; // PENALTI BOT
      }
    }

    // 2. SENSOR SCORE (20%)
    // Kalau sensor hidup, bagi markah penuh 1.0 untuk bahagian ni.
    // Kalau mati (0.0), bagi 0.
    double sensorScore = _hasLivingSensor ? 1.0 : 0.0;
    
    // 3. FINAL FORMULA (WEIGHTED AVERAGE)
    // Touch = 0.8, Sensor = 0.2
    _liveConfidence = (touchScore * 0.8) + (sensorScore * 0.2);
    
    // Notify UI (untuk gerakkan bar)
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 CORE LOGIC
  // ═══════════════════════════════════════════════════════════

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
    if (_state != SecurityState.LOCKED) return;
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      notifyListeners();
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
    _interactionCount = 0;
    _scrollTimestamps.clear();
    _accumulatedMotion = 0;
    _hasLivingSensor = false;
    _liveConfidence = 0.0;
    _lockoutUntil = null;
    _state = SecurityState.LOCKED;
  }
  
  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600)); 

    // 1. HYBRID CHECK
    // Score mesti > 50% untuk lulus.
    // Bermaksud: Mesti ada sentuhan manusia yang cukup DAN sensor hidup.
    if (_liveConfidence < 0.5) {
       ClaAudit.log('REJECTED: Low Hybrid Score ($_liveConfidence)');
       await _handleFailure();
       return;
    }

    // 2. CODE CHECK
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
      
      Future.delayed(config.softLockCooldown, () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
          _threatMessage = "";
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
    return _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
  }
}

class ClaAudit {
  static void log(String msg) {
    if (kDebugMode) print("[CRYPTEX AUDIT] $msg");
  }
}
