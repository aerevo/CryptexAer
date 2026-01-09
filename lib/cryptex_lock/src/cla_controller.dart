// 🔐 PROJECT Z-KINETIC V4.0 — CONTROLLER
// Bank-Grade Lock Orchestrator
// Shadow Rewrite — François

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
  late final FlutterSecureStorage _vault;

  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  int _failures = 0;
  DateTime? _lockoutUntil;

  late List<int> currentValues;

  double _motionConfidence = 0;
  double _touchConfidence = 0;
  int _touchCount = 0;

  final List<MotionEvent> _motionHistory = [];

  String _threat = '';
  String get threatMessage => _threat;

  Timer? _debounce;
  static const _tick = Duration(milliseconds: 40);

  static const _K_FAIL = 'cla_fail';
  static const _K_LOCK = 'cla_lock';

  ClaController(this.config) {
    _engine = SecurityEngine(
      config.engineConfig ?? const SecurityEngineConfig(),
    );

    _vault = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );

    currentValues = List.generate(5, (_) => Random().nextInt(10));
    _init();
  }

  Future<void> _init() async {
    final compromised =
        await FlutterJailbreakDetection.jailbroken.catchError((_) => false);

    if (compromised) {
      _state = SecurityState.ROOT_WARNING;
      _threat = 'SYSTEM_INTEGRITY_COMPROMISED';
      _notify();
      return;
    }

    await _restore();
  }

  // ─────────────────────────────────────────────
  // SENSOR INPUT
  // ─────────────────────────────────────────────
  void registerShake(double mag, double dx, double dy, double dz) {
    if (_state != SecurityState.LOCKED) return;

    _motionConfidence =
        (_motionConfidence * 0.7 + mag * 0.6).clamp(0.0, 1.0);

    if (mag > 0.04) {
      if (_motionHistory.length > 60) _motionHistory.removeAt(0);
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
    _touchConfidence =
        (_touchConfidence * 0.6 + (_touchCount / 3)).clamp(0.0, 1.0);
    _notify();
  }

  // ─────────────────────────────────────────────
  // VALIDATION
  // ─────────────────────────────────────────────
  Future<void> validateAttempt() async {
    if (_state == SecurityState.HARD_LOCK &&
        _lockoutUntil != null &&
        DateTime.now().isBefore(_lockoutUntil!)) {
      return;
    }

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

    if (!verdict.allowed || !_checkCode()) {
      await _fail(verdict.reason);
      return;
    }

    _state = SecurityState.UNLOCKED;
    _threat = '';
    await _clear();
    _notify();
  }

  bool _checkCode() {
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────
  // FAILURE / LOCKOUT
  // ─────────────────────────────────────────────
  Future<void> _fail(String reason) async {
    _failures++;
    _threat = reason;

    if (_failures >= config.maxAttempts) {
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

    await _persist();
    _notify();
  }

  // ─────────────────────────────────────────────
  // STORAGE
  // ─────────────────────────────────────────────
  Future<void> _restore() async {
    _failures = int.tryParse(await _vault.read(key: _K_FAIL) ?? '0') ?? 0;
    final ts = await _vault.read(key: _K_LOCK);
    if (ts != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(int.parse(ts));
      if (DateTime.now().isBefore(_lockoutUntil!)) {
        _state = SecurityState.HARD_LOCK;
      }
    }
  }

  Future<void> _persist() async {
    await _vault.write(key: _K_FAIL, value: '$_failures');
    if (_lockoutUntil != null) {
      await _vault.write(
        key: _K_LOCK,
        value: _lockoutUntil!.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<void> _clear() async {
    await _vault.delete(key: _K_FAIL);
    await _vault.delete(key: _K_LOCK);
    _failures = 0;
    _lockoutUntil = null;
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  void updateWheel(int i, int v) {
    if (_state != SecurityState.LOCKED) return;
    currentValues[i] = v;
    _notify();
  }

  int get remainingLockoutSeconds =>
      _lockoutUntil == null
          ? 0
          : _lockoutUntil!
              .difference(DateTime.now())
              .inSeconds
              .clamp(0, 99999);

  void _notify() {
    _debounce?.cancel();
    _debounce = Timer(_tick, notifyListeners);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
