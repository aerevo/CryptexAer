import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC SDK v5.0 - ENVELOPE VALIDATOR EDITION
// [+] Replace RawBehaviourData → EnvelopeValidator (math-based)
// [+] Zero behavioral data stored atau dihantar ke server
// [+] Server terima envelopeScore (0.0–1.0) sahaja
// [+] Envelope boleh dikemaskini tanpa redeploy (JSON config)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC GLOBAL CONFIG (IMMUTABLE SINGLETON)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKinetic {
  static late final String _appId;
  static late final String _serverUrl;
  static bool _isInitialized = false;

  static void initialize({
    required String appId,
    String? customServerUrl,
  }) {
    if (_isInitialized) {
      debugPrint('⚠️ ZKinetic: Sudah diinisialisasi. Panggilan ini diabaikan.');
      return;
    }
    _appId     = appId;
    _serverUrl = customServerUrl ?? 'https://zticketapp-dxtcyy6wma-as.a.run.app';
    _isInitialized = true;
    debugPrint('✅ ZKinetic: Initialized. appId=$appId | server=$_serverUrl');
  }

  static String get appId {
    if (!_isInitialized) throw StateError('🛑 ZKinetic: Panggil ZKinetic.initialize() dahulu!');
    return _appId;
  }

  static String get serverUrl {
    if (!_isInitialized) throw StateError('🛑 ZKinetic: Panggil ZKinetic.initialize() dahulu!');
    return _serverUrl;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// IMAGE / WHEEL CONFIG
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticConfig {
  static const double imageWidth3  = 712.0;
  static const double imageHeight3 = 600.0;

  static const List<List<double>> coords3 = [
    [165, 155, 257, 380],
    [309, 155, 402, 380],
    [457, 155, 546, 381],
  ];

  static const List<double> btnCoords3 = [122, 435, 603, 546];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ENVELOPE VALIDATOR
//
// Menggantikan RawBehaviourData sepenuhnya.
// Prinsip: input masuk → bandingkan dengan zon matematik → pass/fail
//          Data pengguna TIDAK disimpan. TIDAK dihantar ke server.
//          Server hanya terima envelopeScore (0.0–1.0).
//
// Envelope boleh dikemaskini dari luar tanpa tukar kod:
//   EnvelopeValidator.loadConfig(jsonString);
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _EnvelopeRange {
  final double min;
  final double max;
  const _EnvelopeRange(this.min, this.max);
}

class EnvelopeValidator {
  // ── Default envelope — Tuan boleh override via loadConfig() ──
  static Map<String, _EnvelopeRange> _envelope = {
    'solveTimeMs'   : const _EnvelopeRange(1500,  120000),  // 1.5s – 2min
    'touchCount'    : const _EnvelopeRange(1,     30),      // bilangan sentuhan
    'velMin'        : const _EnvelopeRange(80,    2200),    // px/s — ada velocity dalam julat manusia
    'velCV'         : const _EnvelopeRange(0.03,  0.90),    // coefficient of variation — bukan seragam
    'microPauses'   : const _EnvelopeRange(0,     15),      // natural hesitations
  };

  static const double _humanThreshold = 0.60; // 60% checks mesti lulus

  final List<double> _velocities = [];
  final List<int>    _touchTimes = [];
  DateTime? _start;

  /// Mula sesi baru — buang semua data lama
  void start() {
    _velocities.clear();
    _touchTimes.clear();
    _start = DateTime.now();
  }

  /// Rekod velocity — dipanggil semasa scroll, TIDAK disimpan selepas validate
  void addVelocity(double v) {
    _velocities.add(v.abs());
    if (_velocities.length > 30) _velocities.removeAt(0);
  }

  /// Rekod masa sentuhan — hanya timestamp relatif, bukan absolut
  void addTouch() {
    if (_start == null) return;
    _touchTimes.add(DateTime.now().difference(_start!).inMilliseconds);
    if (_touchTimes.length > 20) _touchTimes.removeAt(0);
  }

  /// Validate dan buang semua data — kembalikan score sahaja
  EnvelopeResult validate() {
    if (_start == null) return const EnvelopeResult(0.0, false);

    final solveMs = DateTime.now().difference(_start!).inMilliseconds.toDouble();
    int passed = 0;
    int total  = 0;

    // ── Check 1: Masa penyelesaian ──────────────────────────────
    total++;
    if (_inRange('solveTimeMs', solveMs)) passed++;

    // ── Check 2: Bilangan sentuhan ──────────────────────────────
    total++;
    if (_touchTimes.length >= _envelope['touchCount']!.min.toInt()) passed++;

    if (_velocities.isNotEmpty) {
      // ── Check 3: Ada velocity dalam julat manusia ─────────────
      total++;
      if (_velocities.any((v) => _inRange('velMin', v))) passed++;

      // ── Check 4: Variance velocity (bukan bot linear) ─────────
      if (_velocities.length >= 3) {
        total++;
        final mean = _velocities.reduce((a, b) => a + b) / _velocities.length;
        if (mean > 0) {
          final cv = _velocities
              .map((v) => (v - mean).abs())
              .reduce((a, b) => a + b) / _velocities.length / mean;
          if (_inRange('velCV', cv)) passed++;
        }
      }

      // ── Check 5: Micro-pauses (jeda semula jadi) ──────────────
      if (_velocities.length >= 4) {
        total++;
        int pauses = 0;
        for (int i = 1; i < _velocities.length; i++) {
          if (_velocities[i] < _velocities[i - 1] * 0.3) pauses++;
        }
        if (_inRange('microPauses', pauses.toDouble())) passed++;
      }
    }

    // ── Buang semua data selepas validate ─────────────────────
    _velocities.clear();
    _touchTimes.clear();

    final score = total > 0 ? passed / total : 0.0;
    debugPrint('🧮 EnvelopeScore: ${score.toStringAsFixed(2)} ($passed/$total checks)');
    return EnvelopeResult(score, score >= _humanThreshold);
  }

  void reset() {
    _velocities.clear();
    _touchTimes.clear();
    _start = null;
  }

  bool _inRange(String key, double val) {
    final r = _envelope[key];
    if (r == null) return false;
    return val >= r.min && val <= r.max;
  }

  /// Update envelope dari JSON config (tanpa redeploy)
  ///
  /// Format JSON:
  /// {
  ///   "solveTimeMs"  : {"min": 1500, "max": 120000},
  ///   "touchCount"   : {"min": 1,    "max": 30},
  ///   "velMin"       : {"min": 80,   "max": 2200},
  ///   "velCV"        : {"min": 0.03, "max": 0.90},
  ///   "microPauses"  : {"min": 0,    "max": 15}
  /// }
  static void loadConfig(String jsonString) {
    try {
      final Map<String, dynamic> raw = json.decode(jsonString);
      final updated = Map<String, _EnvelopeRange>.from(_envelope);
      raw.forEach((key, val) {
        if (val is Map) {
          updated[key] = _EnvelopeRange(
            (val['min'] as num).toDouble(),
            (val['max'] as num).toDouble(),
          );
        }
      });
      _envelope = updated;
      debugPrint('✅ EnvelopeValidator: Config dikemaskini (${raw.keys.join(', ')})');
    } catch (e) {
      debugPrint('⚠️ EnvelopeValidator.loadConfig error: $e');
    }
  }
}

class EnvelopeResult {
  final double score;
  final bool   isHuman;
  const EnvelopeResult(this.score, this.isHuman);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DEVICE DNA
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class DeviceDNA {
  final String model;
  final String osVersion;
  final String screenRes;

  DeviceDNA({required this.model, required this.osVersion, required this.screenRes});

  Map<String, dynamic> toJson() => {
    'model'    : model,
    'osVersion': osVersion,
    'screenRes': screenRes,
  };

  static Future<DeviceDNA> collect(BuildContext context) async {
    final deviceInfo = DeviceInfoPlugin();
    String model     = 'Unknown';
    String osVersion = 'Unknown';

    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        model     = '${info.manufacturer} ${info.model}';
        osVersion = 'Android ${info.version.release}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        model     = info.model;
        osVersion = 'iOS ${info.systemVersion}';
      }
    } catch (e) {
      debugPrint('⚠️ Device info error: $e');
    }

    final size      = MediaQuery.of(context).size;
    final ratio     = MediaQuery.of(context).devicePixelRatio;
    final screenRes = '${(size.width * ratio).toInt()}x${(size.height * ratio).toInt()}';
    return DeviceDNA(model: model, osVersion: osVersion, screenRes: screenRes);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// GESTURE AUDIT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class GestureAudit {
  final List<_ScrollEvent> _events = [];

  void recordScroll(int wheelIndex, int fromItem, int toItem, DateTime at) {
    _events.add(_ScrollEvent(wheelIndex, fromItem, toItem, at));
    if (_events.length > 50) _events.removeAt(0);
  }

  bool isTampered(List<FixedExtentScrollController> controllers) {
    for (int i = 0; i < controllers.length; i++) {
      if (!controllers[i].hasClients) continue;
      final digit       = (controllers[i].selectedItem % 10 + 10) % 10;
      final wheelEvents = _events.where((e) => e.wheelIndex == i).toList();
      if (digit != 0 && wheelEvents.isEmpty) return true;
    }
    return false;
  }

  void clear() => _events.clear();
}

class _ScrollEvent {
  final int      wheelIndex, fromItem, toItem;
  final DateTime at;
  _ScrollEvent(this.wheelIndex, this.fromItem, this.toItem, this.at);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DEVICE INTEGRITY CHECK
//
// Semak sama ada device rooted/jailbroken atau dalam developer mode
// sebelum bootstrap dibenarkan.
//
// pubspec.yaml — tambah dependency:
//   flutter_jailbreak_detection: ^1.10.0
//
// iOS — tambah dalam Info.plist (kalau perlu LSApplicationQueriesSchemes)
// Android — tiada setup tambahan diperlukan
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class DeviceIntegrity {
  /// Return true = device SELAMAT, false = device terkompromi
  static Future<DeviceIntegrityResult> check() async {
    bool isJailbroken   = false;
    bool isDeveloperMode = false;

    try {
      isJailbroken    = await FlutterJailbreakDetection.jailbroken;
      isDeveloperMode = await FlutterJailbreakDetection.developerMode;
    } catch (e) {
      // Kalau plugin gagal (emulator lama, platform luar biasa),
      // fail-safe: anggap terkompromi
      debugPrint('⚠️ DeviceIntegrity check error: $e');
      return DeviceIntegrityResult(
        isClean      : false,
        reason       : 'integrity_check_failed',
        isJailbroken : false,
        isDeveloperMode: true,
      );
    }

    final isClean = !isJailbroken && !isDeveloperMode;

    if (!isClean) {
      debugPrint('🚨 DeviceIntegrity: jailbroken=$isJailbroken | devMode=$isDeveloperMode');
    } else {
      debugPrint('✅ DeviceIntegrity: Device bersih');
    }

    return DeviceIntegrityResult(
      isClean       : isClean,
      reason        : isJailbroken ? 'rooted_or_jailbroken'
                    : isDeveloperMode ? 'developer_mode_active'
                    : null,
      isJailbroken  : isJailbroken,
      isDeveloperMode: isDeveloperMode,
    );
  }
}

class DeviceIntegrityResult {
  final bool    isClean;
  final String? reason;
  final bool    isJailbroken;
  final bool    isDeveloperMode;

  const DeviceIntegrityResult({
    required this.isClean,
    required this.isJailbroken,
    required this.isDeveloperMode,
    this.reason,
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WIDGET CONTROLLER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WidgetController {
  static const _storage = FlutterSecureStorage();

  String get _serverUrl => ZKinetic.serverUrl;
  String get _appId     => ZKinetic.appId;

  String? _sessionToken;
  String? _currentNonce;

  final ValueNotifier<List<int>> challengeCode    = ValueNotifier([]);
  final ValueNotifier<int>       randomizeTrigger = ValueNotifier(0);
  final GestureAudit             gestureAudit     = GestureAudit();
  final EnvelopeValidator        _envelope        = EnvelopeValidator();

  final ValueNotifier<bool> motionLatched  = ValueNotifier(false);
  final ValueNotifier<bool> touchLatched   = ValueNotifier(false);
  final ValueNotifier<bool> patternLatched = ValueNotifier(false);

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double   _lastMagnitude  = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer?   _decayTimer;
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);

  WidgetController() {
    _initSensors();
    _startDecayTimer();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final delta     = (magnitude - _lastMagnitude).abs();
      if (delta > 0.3) {
        motionScore.value   = (delta / 3.0).clamp(0.0, 1.0);
        motionLatched.value = true;
        _lastMotionTime     = DateTime.now();
      }
      _lastMagnitude = magnitude;
    });
  }

  void _startDecayTimer() {
    _decayTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (DateTime.now().difference(_lastMotionTime).inMilliseconds > 500) {
        motionScore.value = (motionScore.value - 0.05).clamp(0.0, 1.0);
      }
    });
  }

  String _hmacSign(String data) {
    final key  = utf8.encode(_appId);
    final body = utf8.encode(data);
    return Hmac(sha256, key).convert(body).toString();
  }

  // ── BOOTSTRAP ──────────────────────────────────────────────
  Future<bool> bootstrap() async {
    // ── Semak integriti device sebelum apa-apa ─────────────
    final integrity = await DeviceIntegrity.check();
    if (!integrity.isClean) {
      debugPrint('🚨 Bootstrap ditolak — device terkompromi (${integrity.reason})');
      return false;
    }

    try {
      final cached = await _storage.read(key: 'zk_token_$_appId');
      final expiry = await _storage.read(key: 'zk_expiry_$_appId');

      if (cached != null && expiry != null) {
        final exp = int.tryParse(expiry) ?? 0;
        if (DateTime.now().millisecondsSinceEpoch < exp) {
          _sessionToken = cached;
          debugPrint('✅ Token reused dari secure storage');
          return true;
        }
      }

      final deviceInfo = DeviceInfoPlugin();
      String deviceId  = 'unknown';
      String platform  = 'unknown';

      try {
        if (Platform.isAndroid) {
          final info = await deviceInfo.androidInfo;
          deviceId = info.id;
          platform = 'android';
        } else if (Platform.isIOS) {
          final info = await deviceInfo.iosInfo;
          deviceId = info.identifierForVendor ?? 'unknown';
          platform = 'ios';
        }
      } catch (_) {}

      final ts        = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = _hmacSign('$_appId:$deviceId:$ts');

      final response = await http.post(
        Uri.parse('$_serverUrl/bootstrap'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'appId'    : _appId,
          'deviceId' : deviceId,
          'platform' : platform,
          'ts'       : ts,
          'signature': signature,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data  = json.decode(response.body);
        final token = data['token']  as String?;
        final expMs = data['expiry'] as int?;

        if (token != null && expMs != null) {
          await _storage.write(key: 'zk_token_$_appId',  value: token);
          await _storage.write(key: 'zk_expiry_$_appId', value: expMs.toString());
          _sessionToken = token;
          debugPrint('✅ Token baru disimpan');
          return true;
        }
      }

      debugPrint('🔒 Bootstrap gagal: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('🔒 Bootstrap error: $e');
      return false;
    }
  }

  // ── FETCH CHALLENGE ────────────────────────────────────────
  Future<bool> fetchChallenge() async {
    if (_sessionToken == null) {
      debugPrint('🔒 Tiada session token');
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/getChallenge'),
        headers: {
          'Content-Type'   : 'application/json',
          'x-session-token': _sessionToken!,
        },
        body: json.encode({}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['challengeCode'] != null && data['nonce'] != null) {
          _currentNonce       = data['nonce'];
          challengeCode.value =
              (data['challengeCode'] as List<dynamic>).map((e) => e as int).toList();
          gestureAudit.clear();
          _envelope.start(); // ← mulakan envelope timer
          return true;
        }
      }

      if (response.statusCode == 401) {
        await _storage.delete(key: 'zk_token_$_appId');
        await _storage.delete(key: 'zk_expiry_$_appId');
        _sessionToken = null;
      }

      return false;
    } catch (e) {
      debugPrint('🔒 Network error - DENY: $e');
      return false;
    }
  }

  // ── VERIFY ────────────────────────────────────────────────
  // Payload baru: envelopeScore sahaja — tiada raw behavioral data
  Future<Map<String, dynamic>> verify(
    List<int> userAnswer,
    List<FixedExtentScrollController> controllers,
    DeviceDNA deviceDNA,
  ) async {
    if (_sessionToken == null) {
      return {'allowed': false, 'error': 'Tiada sesi aktif.'};
    }
    if (challengeCode.value.isEmpty || _currentNonce == null) {
      return {'allowed': false, 'error': 'Tiada cabaran aktif.'};
    }
    if (gestureAudit.isTampered(controllers)) {
      debugPrint('🚨 Tamper detected!');
      return {'allowed': false, 'error': 'Aktiviti mencurigakan.', 'reason': 'TAMPER_DETECTED'};
    }

    // ── Validate envelope on-device, buang data ────────────
    final envResult = _envelope.validate();
    if (!envResult.isHuman) {
      debugPrint('🚨 Envelope gagal: score=${envResult.score.toStringAsFixed(2)}');
      return {'allowed': false, 'error': 'Corak tidak manusiawi.', 'reason': 'ENVELOPE_FAIL'};
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/attest'),
        headers: {
          'Content-Type'   : 'application/json',
          'x-session-token': _sessionToken!,
        },
        body: json.encode({
          'nonce'        : _currentNonce,
          'userAnswer'   : userAnswer,
          'deviceDNA'    : deviceDNA.toJson(),
          'envelopeScore': envResult.score, // ← score sahaja, bukan raw data
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) return json.decode(response.body);
      return {'allowed': false, 'error': 'Server error ${response.statusCode}.'};
    } catch (e) {
      return {'allowed': false, 'error': 'Tiada sambungan. Cuba semula.'};
    }
  }

  void registerTouch() {
    _envelope.addTouch();
    touchLatched.value = true;
  }

  void registerScroll(double velocity) {
    _envelope.addVelocity(velocity);
    patternLatched.value = true;
  }

  void randomizeWheels() => randomizeTrigger.value++;

  void dispose() {
    _accelSub?.cancel();
    _decayTimer?.cancel();
    challengeCode.dispose();
    randomizeTrigger.dispose();
    motionScore.dispose();
    motionLatched.dispose();
    touchLatched.dispose();
    patternLatched.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ANTI-SCREENSHOT — Zero package dependency
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AntiScreenshot {
  static const _ch = MethodChannel('zkinetic/security');

  static Future<void> enable() async {
    try {
      await _ch.invokeMethod('setSecureFlag', {'secure': true});
      debugPrint('🔒 Anti-screenshot: ACTIVE');
    } catch (e) {
      debugPrint('⚠️ Anti-screenshot enable error: $e');
    }
  }

  static Future<void> disable() async {
    try {
      await _ch.invokeMethod('setSecureFlag', {'secure': false});
      debugPrint('🔓 Anti-screenshot: DISABLED');
    } catch (e) {
      debugPrint('⚠️ Anti-screenshot disable error: $e');
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN WIDGET
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticWidgetProdukB extends StatefulWidget {
  final WidgetController       controller;
  final Function(bool success) onComplete;
  final VoidCallback?          onCancel;

  const ZKineticWidgetProdukB({
    super.key,
    required this.controller,
    required this.onComplete,
    this.onCancel,
  });

  @override
  State<ZKineticWidgetProdukB> createState() => _ZKineticWidgetProdukBState();
}

class _ZKineticWidgetProdukBState extends State<ZKineticWidgetProdukB> {
  bool       _loading      = true;
  bool       _networkError = false;
  DeviceDNA? _deviceDNA;

  @override
  void initState() {
    super.initState();
    _AntiScreenshot.enable();
    _initialize();
  }

  @override
  void dispose() {
    _AntiScreenshot.disable();
    super.dispose();
  }

  Future<void> _initialize() async {
    final bootstrapOk = await widget.controller.bootstrap();
    if (!bootstrapOk) {
      if (mounted) setState(() { _loading = false; _networkError = true; });
      return;
    }

    _deviceDNA = await DeviceDNA.collect(context);
    final success = await widget.controller.fetchChallenge();
    if (mounted) {
      setState(() {
        _loading      = false;
        _networkError = !success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_networkError) return _buildNetworkErrorScreen();

    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding   : const EdgeInsets.only(top: 14, bottom: 8, left: 16, right: 16),
            margin    : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color        : const Color(0xFFFF5722),
              borderRadius : BorderRadius.circular(24),
              boxShadow    : [
                BoxShadow(
                  color     : Colors.black.withOpacity(0.3),
                  blurRadius: 30, spreadRadius: 5, offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Z-KINETIC',
                  style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding   : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color       : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, color: Colors.greenAccent, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'INTELLIGENT-GRADE BIOMETRIC LOCK',
                        style: TextStyle(
                          fontSize: 8, color: Colors.white,
                          letterSpacing: 0.8, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                UltimateRGBGlitchDisplay(controller: widget.controller),
                const SizedBox(height: 8),
                const Text(
                  'Please match the code',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40.0),
                    child  : CircularProgressIndicator(color: Colors.white),
                  )
                else if (_deviceDNA != null)
                  UltimateCryptexLock(
                    controller: widget.controller,
                    deviceDNA : _deviceDNA!,
                    onSuccess : (success) => widget.onComplete(success),
                    onFail    : () => widget.onComplete(false),
                  ),
                const SizedBox(height: 10),
                _buildBiometricPanel(),
                const SizedBox(height: 6),
                if (widget.onCancel != null)
                  TextButton(
                    onPressed: widget.onCancel,
                    child    : const Text('Cancel',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkErrorScreen() {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: Container(
          margin   : const EdgeInsets.symmetric(horizontal: 32),
          padding  : const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color       : const Color(0xFF263238),
            borderRadius: BorderRadius.circular(24),
            border      : Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                'SAMBUNGAN DIPERLUKAN',
                textAlign: TextAlign.center,
                style    : TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: Colors.white, letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Z-Kinetic memerlukan sambungan internet untuk pengesahan selamat.',
                textAlign: TextAlign.center,
                style    : TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() { _loading = true; _networkError = false; });
                  await _initialize();
                },
                icon : const Icon(Icons.refresh),
                label: const Text('Cuba Semula'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding        : const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child    : const Text('Kembali', style: TextStyle(color: Colors.white54)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricPanel() {
    return Container(
      margin   : const EdgeInsets.symmetric(horizontal: 20),
      padding  : const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color       : const Color(0xFFFF5722),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIndicator(Icons.sensors,     'MOTION',  widget.controller.motionLatched),
          _buildIndicator(Icons.touch_app,   'TOUCH',   widget.controller.touchLatched),
          _buildIndicator(Icons.fingerprint, 'PATTERN', widget.controller.patternLatched),
        ],
      ),
    );
  }

  Widget _buildIndicator(IconData icon, String label, ValueNotifier<bool> notifier) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder        : (context, isActive, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children    : [
            Icon(icon, size: 20, color: isActive ? Colors.greenAccent : Colors.white30),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize  : 7,
              color     : isActive ? Colors.greenAccent : Colors.white30,
              fontWeight: FontWeight.bold, letterSpacing: 0.5,
            )),
          ],
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RGB GLITCH DISPLAY
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateRGBGlitchDisplay extends StatefulWidget {
  final WidgetController controller;
  const UltimateRGBGlitchDisplay({super.key, required this.controller});

  @override
  State<UltimateRGBGlitchDisplay> createState() => _UltimateRGBGlitchDisplayState();
}

class _UltimateRGBGlitchDisplayState extends State<UltimateRGBGlitchDisplay>
    with SingleTickerProviderStateMixin {

  Timer? _glitchTimer;
  int    _noiseSeed = DateTime.now().millisecondsSinceEpoch;
  final  Random _random = Random();

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  final List<Offset> _jitter    = List.filled(3, Offset.zero);
  final List<double> _scale     = List.filled(3, 1.0);
  final List<double> _roOffset  = List.filled(3, 0.0);
  final List<double> _coOffset  = List.filled(3, 0.0);
  final List<double> _intensity = List.filled(3, 1.0);

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync   : this,
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _glitchTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < 3; i++) {
          _jitter[i]    = Offset(
            (_random.nextDouble() - 0.5) * 5,
            (_random.nextDouble() - 0.5) * 5,
          );
          _scale[i]     = 0.93 + _random.nextDouble() * 0.14;
          _roOffset[i]  = (_random.nextDouble() - 0.5) * 6;
          _coOffset[i]  = (_random.nextDouble() - 0.5) * 5;
          _intensity[i] = 0.75 + _random.nextDouble() * 0.25;
        }
        _noiseSeed = DateTime.now().millisecondsSinceEpoch;
      });
    });
  }

  @override
  void dispose() {
    _glitchTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder  : (context, child) {
        final t = _pulseAnim.value;
        final borderColor = Color.lerp(
          const Color(0xFFFF8C00).withOpacity(0.55),
          const Color(0xFFFFC800).withOpacity(0.85),
          t,
        )!;
        final glow1Opacity = 0.4  + 0.3  * t;
        final glow2Opacity = 0.2  + 0.2  * t;
        final blur1        = 18.0 + 12.0 * t;
        final blur2        = 35.0 + 25.0 * t;

        return Container(
          height    : 46,
          margin    : const EdgeInsets.symmetric(horizontal: -14),
          decoration: BoxDecoration(
            color        : const Color(0xFF3E2723),
            borderRadius : BorderRadius.circular(12),
            border       : Border.all(color: borderColor, width: 1.5),
            boxShadow    : [
              BoxShadow(
                color     : const Color(0xFFFF6400).withOpacity(glow1Opacity),
                blurRadius: blur1,
              ),
              BoxShadow(
                color     : const Color(0xFFFF3C00).withOpacity(glow2Opacity),
                blurRadius: blur2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ValueListenableBuilder<List<int>>(
        valueListenable: widget.controller.challengeCode,
        builder        : (context, code, _) {
          if (code.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children : [
                Positioned.fill(child: CustomPaint(painter: _NoisePainter(seed: _noiseSeed))),
                Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    for (int i = 0; i < code.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      _buildGlitchDigit('${code[i]}', i),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlitchDigit(String digit, int idx) {
    final p  = _intensity[idx];
    final ro = _roOffset[idx];
    final co = _coOffset[idx];

    return Transform.translate(
      offset: _jitter[idx],
      child : Transform.scale(
        scale: _scale[idx],
        child: SizedBox(
          width : 28, height: 50,
          child : Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize  : 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
                color     : Colors.white,
                shadows   : [
                  Shadow(
                    offset    : Offset(ro, 0),
                    color     : const Color(0xFFFF1E50).withOpacity(0.7 * p),
                    blurRadius: 0,
                  ),
                  Shadow(
                    offset    : Offset(-co, 0),
                    color     : const Color(0xFF00DCFF).withOpacity(0.65 * p),
                    blurRadius: 0,
                  ),
                  Shadow(
                    color     : Colors.white.withOpacity(0.9 * p),
                    blurRadius: 6 + _random.nextDouble() * 5,
                  ),
                  Shadow(
                    color     : const Color(0xFFFF8C00).withOpacity(0.8 * p),
                    blurRadius: 12 + _random.nextDouble() * 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final int seed;
  _NoisePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng       = Random(seed);
    final linePaint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 40; i++) {
      linePaint.color       = Colors.white.withOpacity(rng.nextDouble() * 0.1 + 0.02);
      linePaint.strokeWidth = rng.nextDouble() * 1.2 + 0.3;
      canvas.drawLine(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        linePaint,
      );
    }

    for (int g = 0; g < 4; g++) {
      final tp = TextPainter(
        text: TextSpan(
          text : rng.nextInt(10).toString(),
          style: TextStyle(
            fontSize  : 16 + rng.nextDouble() * 12,
            color     : Colors.white.withOpacity(rng.nextDouble() * 0.07 + 0.02),
            fontWeight: FontWeight.w900,
            fontFamily: 'Courier',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height));
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int d = 0; d < 20; d++) {
      dotPaint.color = Colors.white.withOpacity(rng.nextDouble() * 0.05 + 0.01);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.2 + 0.2,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_NoisePainter old) => old.seed != seed;
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = Colors.white.withOpacity(0.018)
      ..strokeWidth = 1.0
      ..style       = PaintingStyle.stroke;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => false;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CRYPTEX LOCK
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateCryptexLock extends StatefulWidget {
  final WidgetController controller;
  final DeviceDNA        deviceDNA;
  final Function(bool)   onSuccess;
  final VoidCallback     onFail;

  const UltimateCryptexLock({
    super.key,
    required this.controller,
    required this.deviceDNA,
    required this.onSuccess,
    required this.onFail,
  });

  @override
  State<UltimateCryptexLock> createState() => _UltimateCryptexLockState();
}

class _UltimateCryptexLockState extends State<UltimateCryptexLock>
    with TickerProviderStateMixin {

  static const double             imageWidth   = ZKineticConfig.imageWidth3;
  static const double             imageHeight  = ZKineticConfig.imageHeight3;
  static const List<List<double>> wheelCoords  = ZKineticConfig.coords3;
  static const List<double>       buttonCoords = ZKineticConfig.btnCoords3;

  late List<FixedExtentScrollController> _scrollControllers;
  final List<int> _prevItems = [0, 0, 0];
  DateTime? _lastScrollTime;

  int?   _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool   _isButtonPressed = false;
  final  Random _random   = Random();

  late List<AnimationController> _textOpacityControllers;
  late List<Animation<double>>   _textOpacityAnimations;
  final List<Offset> _textDriftOffsets = [Offset.zero, Offset.zero, Offset.zero];
  Timer? _driftTimer;
  int    _percubaanSalah  = 0;

  final List<bool> _isDraggingWheel = [false, false, false];

  @override
  void initState() {
    super.initState();
    _scrollControllers = List.generate(3, (i) => FixedExtentScrollController(initialItem: 0));

    _textOpacityControllers = List.generate(3, (i) =>
      AnimationController(duration: const Duration(milliseconds: 800), vsync: this)
        ..repeat(reverse: true));

    _textOpacityAnimations = _textOpacityControllers
        .map((c) => Tween<double>(begin: 0.75, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    _startDriftTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playSlotMachineIntro());
  }

  void _startDriftTimer() {
    _driftTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          for (int i = 0; i < 3; i++) {
            _textDriftOffsets[i] = Offset(
              (_random.nextDouble() - 0.5) * 1.5,
              (_random.nextDouble() - 0.5) * 1.5,
            );
          }
        });
      }
    });
  }

  void _playSlotMachineIntro() {
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 200 + (i * 300)), () {
        if (!mounted) return;
        _scrollControllers[i].animateToItem(
          20 + _random.nextInt(10),
          duration: const Duration(milliseconds: 1200),
          curve   : Curves.elasticOut,
        );
      });
    }
  }

  @override
  void dispose() {
    for (var c in _scrollControllers) c.dispose();
    for (var c in _textOpacityControllers) c.dispose();
    _wheelActiveTimer?.cancel();
    _driftTimer?.cancel();
    super.dispose();
  }

  void _onWheelScrollStart(int index) {
    setState(() => _activeWheelIndex = index);
    _wheelActiveTimer?.cancel();
    HapticFeedback.selectionClick();
    widget.controller.registerTouch();
  }

  void _onWheelScrollUpdate(int index) {
    final now = DateTime.now();
    if (_lastScrollTime != null) {
      final deltaMs = now.difference(_lastScrollTime!).inMilliseconds;
      if (deltaMs > 0) widget.controller.registerScroll(100.0 / deltaMs);
    }
    _lastScrollTime = now;
  }

  void _onItemChanged(int index, int newItem) {
    widget.controller.gestureAudit.recordScroll(index, _prevItems[index], newItem, DateTime.now());
    _prevItems[index] = newItem;
    HapticFeedback.selectionClick();
  }

  void _onWheelScrollEnd(int index) {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _activeWheelIndex = null);
    });
  }

  Future<void> _onButtonTap() async {
    setState(() => _isButtonPressed = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _isButtonPressed = false);

    final userAnswer = <int>[];
    for (var c in _scrollControllers) {
      userAnswer.add((c.selectedItem % 10 + 10) % 10);
    }

    final result = await widget.controller.verify(
      userAnswer, _scrollControllers, widget.deviceDNA,
    );

    if (result['allowed'] == true) {
      _percubaanSalah = 0;
      widget.onSuccess(true);
    } else {
      setState(() { _percubaanSalah++; });

      if (_percubaanSalah >= 3) {
        _percubaanSalah = 0;
        widget.onFail();
      } else {
        final bakiNyawa = 3 - _percubaanSalah;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Akses Ditolak! Padanan kod salah. Baki peluang: $bakiNyawa',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange.shade800,
            duration       : const Duration(seconds: 2),
            behavior       : SnackBarBehavior.floating,
          ),
        );
        HapticFeedback.heavyImpact();
        _playSlotMachineIntro();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit  : BoxFit.contain,
      child: SizedBox(
        width : imageWidth,
        height: imageHeight,
        child : Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                'https://z-kinetic.web.app/z_wheel3.png',
                fit: BoxFit.fill,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFFFF5722),
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.wifi_off, color: Colors.grey, size: 40),
                  );
                },
              ),
            ),
            for (int i = 0; i < 3; i++) _buildWheel(i),
            _buildGlowingButton(),
          ],
        ),
      ),
    );
  }

  void _snapWithMomentum(int index, double velocity) {
    final ctrl = _scrollControllers[index];
    if (!ctrl.hasClients) return;

    final coords      = wheelCoords[index];
    final itemExtent  = (coords[3] - coords[1]) * 0.40;
    final momentumItems = (velocity * 0.25 / itemExtent).round();
    final targetItem    = ctrl.selectedItem - momentumItems;
    final itemDistance  = (ctrl.selectedItem - targetItem).abs();
    final duration      = Duration(milliseconds: (200 + itemDistance * 40).clamp(200, 550));

    ctrl.animateToItem(targetItem, duration: duration, curve: Curves.decelerate);
  }

  Widget _buildWheel(int index) {
    final coords     = wheelCoords[index];
    final double left       = coords[0];
    final double top        = coords[1];
    final double width      = coords[2] - coords[0];
    final double height     = coords[3] - coords[1];
    final isActive          = _activeWheelIndex == index;
    final double itemExtent = height * 0.40;

    return Positioned(
      left: left, top: top, width: width, height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onVerticalDragStart: (details) {
          _isDraggingWheel[index] = true;
          _onWheelScrollStart(index);
        },

        onVerticalDragUpdate: (details) {
          if (!_isDraggingWheel[index]) return;

          final lp = details.localPosition;
          if (lp.dx < 0 || lp.dx > width || lp.dy < 0 || lp.dy > height) {
            _isDraggingWheel[index] = false;
            _snapWithMomentum(index, 0);
            _onWheelScrollEnd(index);
            return;
          }

          final ctrl = _scrollControllers[index];
          if (ctrl.hasClients) {
            ctrl.jumpTo(
              (ctrl.offset - details.delta.dy).clamp(0.0, double.infinity),
            );
          }
          _onWheelScrollUpdate(index);
        },

        onVerticalDragEnd: (details) {
          if (!_isDraggingWheel[index]) return;
          _isDraggingWheel[index] = false;
          _snapWithMomentum(index, details.primaryVelocity ?? 0);
          _onWheelScrollEnd(index);
        },

        onVerticalDragCancel: () {
          _isDraggingWheel[index] = false;
          _snapWithMomentum(index, 0);
          _onWheelScrollEnd(index);
        },

        child: ListWheelScrollView.useDelegate(
          controller          : _scrollControllers[index],
          itemExtent          : itemExtent,
          perspective         : 0.001,
          diameterRatio       : 1.5,
          physics             : const NeverScrollableScrollPhysics(),
          onSelectedItemChanged: (item) => _onItemChanged(index, item),
          childDelegate       : ListWheelChildBuilderDelegate(
            builder: (context, idx) {
              final displayNumber = (idx % 10 + 10) % 10;
              return Center(
                child: AnimatedBuilder(
                  animation: _textOpacityAnimations[index],
                  builder  : (context, child) {
                    return Transform.translate(
                      offset: isActive ? Offset.zero : _textDriftOffsets[index],
                      child : Opacity(
                        opacity: isActive ? 1.0 : _textOpacityAnimations[index].value,
                        child  : Text(
                          '$displayNumber',
                          style: TextStyle(
                            fontSize  : height * 0.30,
                            fontWeight: FontWeight.w900,
                            color     : isActive ? const Color(0xFFFF5722) : const Color(0xFF263238),
                            height    : 1.0,
                            shadows   : isActive
                                ? [Shadow(color: const Color(0xFFFF5722).withOpacity(0.8), blurRadius: 20)]
                                : [const Shadow(offset: Offset(1, 1), color: Colors.black26, blurRadius: 2)],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGlowingButton() {
    return Positioned(
      left  : buttonCoords[0],
      top   : buttonCoords[1],
      width : buttonCoords[2] - buttonCoords[0],
      height: buttonCoords[3] - buttonCoords[1],
      child : GestureDetector(
        onTap: _onButtonTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color       : Colors.transparent,
            boxShadow   : _isButtonPressed
                ? []
                : [BoxShadow(
                    color      : const Color(0xFFFF5722).withOpacity(0.5),
                    blurRadius : 20, spreadRadius: 2,
                  )],
          ),
        ),
      ),
    );
  }
}
