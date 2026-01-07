/*
 * PROJECT: CryptexLock Security Suite
 * ENGINE: STABLE SENSOR + SERVER SECURITY
 * STATUS: Merged (No downgrade, No 0-19 ghost)
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'cla_models.dart';

// IMPORTS DARI ZIP (Untuk Server Security)
import 'security/models/secure_payload.dart';
import 'security/services/mirror_service.dart';
import 'security/services/device_fingerprint.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  DateTime? _lockoutUntil;
  late List<int> currentValues;

  // ═══════════════════════════════════════════════════════════
  // 🧬 DATA METRICS (Untuk dihantar ke Server)
  // ═══════════════════════════════════════════════════════════
  // Kita simpan data ini bukan untuk filter (sebab sensor dah stabil),
  // tapi untuk bina 'Payload' yang Server nak.
  
  final List<MotionEvent> _motionHistory = [];
  double _entropy = 0.0;
  double _variance = 0.0;
  double _liveConfidence = 0.0; // Score untuk UI
  int _interactionCount = 0;    // Touch counter

  double get liveConfidence => _liveConfidence;
  String _threatMessage = "";
  String get threatMessage => _threatMessage;
  
  late MirrorService _mirrorService;

  ClaController(this.config) {
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    
    // Init Server Service
    if (config.hasServerValidation) {
      _mirrorService = MirrorService(
        endpoint: config.securityConfig!.serverEndpoint,
        timeout: config.securityConfig!.serverTimeout,
      );
    }
    _initSecurityProtocol();
  }

  Future<void> _initSecurityProtocol() async {
    bool isRooted = false;
    try {
      isRooted = await FlutterJailbreakDetection.jailbroken;
    } catch (e) {
      // Ignore debug
    }

    if (isRooted) {
      _threatMessage = "CRITICAL: K9 WATCHDOG ALERT";
      _state = SecurityState.ROOT_WARNING;
      notifyListeners();
      return;
    }
    await _loadState();
  }
  
  void userAcceptsRisk() {
    _state = SecurityState.LOCKED;
    notifyListeners();
    _loadState();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎛️ INPUT HANDLERS (Stabil)
  // ═══════════════════════════════════════════════════════════

  // 1. TOUCH INPUT
  void registerTouchInteraction() {
    if (_state != SecurityState.LOCKED) return;
    _interactionCount++;
    // Logic mudah: Makin banyak sentuh, makin yakin itu manusia
    _liveConfidence = (_liveConfidence + 0.15).clamp(0.0, 1.0);
    notifyListeners();
  }

  // 2. SENSOR INPUT
  void registerShake(double rawMagnitude, double dx, dy, dz) {
    if (_state != SecurityState.LOCKED) return;

    // Simpan data untuk kiraan Entropy (Server Requirement)
    // Cuma simpan kalau ada movement sebenar (>0.1)
    if (rawMagnitude > 0.1) {
       _addToHistory(rawMagnitude, dx, dy, dz);
       
       // Update UI sikit tanda sensor hidup
       if (_liveConfidence < 1.0) {
         _liveConfidence = (_liveConfidence + 0.01).clamp(0.0, 1.0);
         notifyListeners();
       }
    }
  }

  void _addToHistory(double mag, double dx, dy, dz) {
     if (_motionHistory.length >= 50) _motionHistory.removeAt(0);
     
     _motionHistory.add(MotionEvent(
       magnitude: mag,
       timestamp: DateTime.now(),
       deltaX: dx, deltaY: dy, deltaZ: dz
     ));
     
     // Kira matematik untuk Server Payload
     _calculateMetricsForServer();
  }

  void _calculateMetricsForServer() {
     if (_motionHistory.isEmpty) return;
     
     // 1. Variance
     double mean = _motionHistory.map((e) => e.magnitude).reduce((a,b)=>a+b) / _motionHistory.length;
     double sumSquaredDiff = _motionHistory.map((e) => pow(e.magnitude - mean, 2)).reduce((a,b)=>a+b);
     _variance = sumSquaredDiff / _motionHistory.length;
     
     // 2. Entropy
     Map<String, int> freq = {};
     for (var m in _motionHistory) {
       String key = "${m.magnitude.toStringAsFixed(1)}";
       freq[key] = (freq[key] ?? 0) + 1;
     }
     
     _entropy = 0.0;
     int total = _motionHistory.length;
     freq.forEach((k, v) {
       double p = v / total;
       if (p > 0) _entropy -= p * log(p);
     });
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 VALIDATION (SERVER + LOCAL)
  // ═══════════════════════════════════════════════════════════

  Future<void> validateAttempt({required bool hasPhysicalMovement}) async {
    if (_state == SecurityState.ROOT_WARNING || _state == SecurityState.HARD_LOCK) return;

    _state = SecurityState.VALIDATING;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    // CHECK 1: CODE VALIDATION
    if (!_isCodeCorrect()) {
      await _fail(bot: false, msg: "INVALID PASSCODE");
      return;
    }

    // CHECK 2: SERVER VALIDATION (Feature ZIP)
    if (config.hasServerValidation) {
      try {
        final deviceId = await DeviceFingerprint.getDeviceId();
        final nonce = DeviceFingerprint.generateNonce();
        final secretStr = await DeviceFingerprint.getDeviceSecret();
        
        // Zero-Knowledge Proof (Hantar bukti hash sahaja)
        final zkProof = ZeroKnowledgeProof.generate(
          userCode: currentValues,
          nonce: nonce,
          deviceSecret: secretStr,
        );

        final payload = SecurePayload(
          deviceId: deviceId,
          appSignature: await DeviceFingerprint.getAppSignature(),
          nonce: nonce,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          // Data Biometrik Sebenar
          entropy: _entropy, 
          averageMagnitude: _motionHistory.isEmpty ? 0 : _motionHistory.last.magnitude,
          frequencyVariance: _variance,
          uniqueGestureCount: _interactionCount,
          interactionTimeMs: 2000,
          zkProof: zkProof,
          motionSignature: MotionSignature.generate(
            entropy: _entropy,
            variance: _variance,
            gestureCount: _interactionCount,
          ), 
          tremorHz: 10.0,
        );

        final verdict = await _mirrorService.verify(payload);
        
        if (!verdict.allowed) {
          await _fail(bot: true, msg: "SERVER DENIED: ${verdict.reason}");
          return;
        }
      } catch (e) {
        // Fallback jika server down (Ikut Config)
        if (!config.securityConfig!.allowOfflineFallback) {
           await _fail(bot: false, msg: "SERVER UNREACHABLE");
           return;
        }
      }
    }

    // SUCCESS
    await _clearMemory();
    _state = SecurityState.UNLOCKED;
    _threatMessage = "";
    notifyListeners();
  }

  Future<void> _fail({required bool bot, required String msg}) async {
    _failedAttempts++;
    _threatMessage = msg;

    if (bot || _failedAttempts >= config.maxAttempts) {
      _state = SecurityState.HARD_LOCK;
      _lockoutUntil = DateTime.now().add(config.jamCooldown);
    } else {
      _state = SecurityState.SOFT_LOCK;
      Future.delayed(config.softLockCooldown, () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
          _threatMessage = "";
          notifyListeners();
        }
      });
    }

    await _saveState();
    notifyListeners();
  }

  bool _isCodeCorrect() {
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }
  
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt(KEY_ATTEMPTS) ?? 0;
    final lockTs = prefs.getInt(KEY_LOCKOUT);
    if (lockTs != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockTs);
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
        notifyListeners();
      }
    }
  }

  Future<void> _saveState() async {
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
    _motionHistory.clear();
    _interactionCount = 0;
    _liveConfidence = 0.0;
    _lockoutUntil = null;
    _state = SecurityState.LOCKED;
  }

  void updateWheel(int index, int value) {
    if (_state != SecurityState.LOCKED) return;
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      notifyListeners();
    }
  }

  int getInitialValue(int index) {
    if (index >= 0 && index < currentValues.length) return currentValues[index];
    return 0;
  }

  int get remainingLockoutSeconds =>
      _lockoutUntil == null ? 0 : _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
}
