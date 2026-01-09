import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

import 'cla_models.dart';
import 'security_engine.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;
  late final SecurityEngine _engine;
  late final FlutterSecureStorage _storage;

  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  DateTime? _lockoutUntil;
  late List<int> currentValues;

  double _motionConfidence = 0.0;
  double _touchConfidence = 0.0;
  int _touchCount = 0;

  double get motionConfidence => _motionConfidence;
  double get touchConfidence => _touchConfidence;

  final List<MotionEvent> _motionHistory = [];
  String _threatMessage = "";
  String get threatMessage => _threatMessage;

  Timer? _debounce;
  static const _throttle = Duration(milliseconds: 50);

  static const _K_ATTEMPTS = 'cla_attempts';
  static const _K_LOCKOUT = 'cla_lockout';

  ClaController(this.config) {
    _engine = SecurityEngine(const SecurityEngineConfig());

    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );

    currentValues = List.generate(5, (_) => Random().nextInt(10));
    _init();
  }

  Future<void> _init() async {
    bool compromised = false;
    try {
      compromised = await FlutterJailbreakDetection.jailbroken;
    } catch (_) {}

    if (compromised) {
      _state = SecurityState.ROOT_WARNING;
      _threatMessage = "DEVICE COMPROMISED";
      _notify();
      return;
    }

    await _loadSecure();
  }

  // ================= SENSOR INPUT =================

  void registerShake(double mag, double dx, dy, dz) {
    if (_state != SecurityState.LOCKED) return;

    _motionConfidence = (mag * 4).clamp(0.0, 1.0);

    if (mag > 0.05) {
      if (_motionHistory.length > 50) _motionHistory.removeAt(0);
      _motionHistory.add(MotionEvent(
        magnitude: mag,
        timestamp: DateTime.now(),
        deltaX: dx,
        deltaY: dy,
        deltaZ: dz,
      ));
    }
    _notify();
  }

  void registerTouch() {
    if (_state != SecurityState.LOCKED) return;
    _touchCount++;
    _touchConfidence = (_touchCount / 3).clamp(0.0, 1.0);
    _notify();
  }

  // ================= VALIDATION =================

  Future<void> validateAttempt({bool hasPhysicalMovement = false}) async {
    if (_state != SecurityState.LOCKED &&
        _state != SecurityState.SOFT_LOCK) return;

    _state = SecurityState.VALIDATING;
    _notify();

    await Future.delayed(const Duration(milliseconds: 600));

    final verdict = _engine.analyze(
      motionConfidence: _motionConfidence,
      touchConfidence: _touchConfidence,
      motionHistory: _motionHistory,
      touchCount: _touchCount,
    );

    if (!verdict.allowed) {
      await _fail(verdict.reason);
      return;
    }

    if (!_checkCode()) {
      await _fail("CODE MISMATCH");
      return;
    }

    _state = SecurityState.UNLOCKED;
    _threatMessage = "";
    await _clearSecure();
    _notify();
  }

  bool _checkCode() {
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }

  // ================= OVERRIDE =================

  void userAcceptsRisk() {
    _state = SecurityState.LOCKED;
    _threatMessage = "";
    _motionConfidence = 0;
    _touchConfidence = 0;
    _touchCount = 0;
    _motionHistory.clear();
    _notify();
  }

  // ================= LOCKOUT =================

  Future<void> _fail(String reason) async {
    _failedAttempts++;
    _threatMessage = reason;

    if (_failedAttempts >= config.maxAttempts) {
      _state = SecurityState.HARD_LOCK;
      _lockoutUntil = DateTime.now().add(config.jamCooldown);
    } else {
      _state = SecurityState.SOFT_LOCK;
      Future.delayed(config.softLockCooldown, () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
          _notify();
        }
      });
    }

    await _saveSecure();
    _notify();
  }

  // ================= STORAGE =================

  Future<void> _loadSecure() async {
    final a = await _storage.read(key: _K_ATTEMPTS);
    _failedAttempts = int.tryParse(a ?? '0') ?? 0;

    final t = await _storage.read(key: _K_LOCKOUT);
    if (t != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(int.parse(t));
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
        _notify();
      }
    }
  }

  Future<void> _saveSecure() async {
    await _storage.write(key: _K_ATTEMPTS, value: '$_failedAttempts');
    if (_lockoutUntil != null) {
      await _storage.write(
          key: _K_LOCKOUT,
          value: _lockoutUntil!.millisecondsSinceEpoch.toString());
    }
  }

  Future<void> _clearSecure() async {
    await _storage.delete(key: _K_ATTEMPTS);
    await _storage.delete(key: _K_LOCKOUT);
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  // ================= UI HELPERS =================

  void updateWheel(int index, int val) {
    if (_state != SecurityState.LOCKED) return;
    currentValues[index] = val;
    _notify();
  }

  int getInitialValue(int index) => currentValues[index];

  int get remainingLockoutSeconds =>
      _lockoutUntil == null
          ? 0
          : _lockoutUntil!
              .difference(DateTime.now())
              .inSeconds
              .clamp(0, 99999);

  void _notify() {
    _debounce?.cancel();
    _debounce = Timer(_throttle, notifyListeners);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
