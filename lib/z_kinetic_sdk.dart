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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC SDK v6.0 - ZERO-TRUST EDITION (FLUTTER)
// [+] Gantikan EnvelopeValidator → TelemetryCollector (Server-Side Physics)
// [+] Kumpul titik mentah {x, y, t} dan hantar ke server
// [+] envelopeScore kekal sebagai fallback
// [+] UI & Widget Dipulihkan Sepenuhnya
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC GLOBAL CONFIG (IMMUTABLE SINGLETON)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKinetic {
  static late final String _appId;
  static late final String _serverUrl;
  static late final String _imageUrl;
  static bool _isInitialized = false;

  static void initialize({
    required String appId,
    String? customServerUrl,
    String? customImageUrl,
  }) {
    if (_isInitialized) {
      debugPrint('⚠️ ZKinetic: Sudah diinisialisasi. Panggilan ini diabaikan.');
      return;
    }
    _appId     = appId;
    _serverUrl = customServerUrl ?? 'https://zticketapp-dxtcyy6wma-as.a.run.app';
    _imageUrl  = customImageUrl  ?? 'https://z-kinetic.web.app/sdk/z_wheel3.png';
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

  static String get imageUrl {
    if (!_isInitialized) throw StateError('🛑 ZKinetic: Panggil ZKinetic.initialize() dahulu!');
    return _imageUrl;
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
// TELEMETRY COLLECTOR (v6.0)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TPoint {
  final int x, y, t;
  const _TPoint(this.x, this.y, this.t);
  Map<String, int> toJson() => {'x': x, 'y': y, 't': t};
}

class TelemetryCollector {
  final List<_TPoint> _points  = [];
  int                 _touches = 0;
  DateTime?           _start;

  static const int _maxPoints = 200;

  void start() {
    _points.clear();
    _touches = 0;
    _start   = DateTime.now();
  }

  void recordTouch() { _touches++; }

  void recordMove(double x, double y) {
    if (_start == null || _points.length >= _maxPoints) return;
    _points.add(_TPoint(x.round(), y.round(), DateTime.now().millisecondsSinceEpoch));
  }

  double _fallbackScore() {
    if (_points.length < 3 || _start == null) return 0.5;
    final solveMs = DateTime.now().difference(_start!).inMilliseconds;
    final vels = <double>[];
    for (int i = 1; i < _points.length; i++) {
      final dt = _points[i].t - _points[i-1].t;
      if (dt <= 0 || dt >= 2000) continue;
      final dx = (_points[i].x - _points[i-1].x).toDouble();
      final dy = (_points[i].y - _points[i-1].y).toDouble();
      vels.add((sqrt(dx*dx + dy*dy) / dt) * 1000);
    }
    final vAvg = vels.isEmpty ? 0.0 : vels.reduce((a, b) => a + b) / vels.length;
    double score = 1.0;
    if (solveMs < 800 || solveMs > 120000) score -= 0.3;
    if (vAvg < 50 || vAvg > 3500) score -= 0.3;
    if (_touches < 1) score -= 0.2;
    return score.clamp(0.0, 1.0);
  }

  Map<String, dynamic> getPayload() {
    final result = {
      'rawTelemetry' : _points.map((p) => p.toJson()).toList(),
      'solveTimeMs'  : _start != null ? DateTime.now().difference(_start!).inMilliseconds : 0,
      'touchCount'   : _touches,
      'envelopeScore': _fallbackScore(),
    };
    _points.clear();
    _touches = 0;
    return result;
  }

  void reset() { _points.clear(); _touches = 0; _start = null; }

  static void loadConfig(String _) {
    debugPrint('ℹ️ TelemetryCollector: server kira sendiri dalam v6.0');
  }
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
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class DeviceIntegrity {
  static Future<DeviceIntegrityResult> check() async {
    final deviceInfo = DeviceInfoPlugin();
    bool isEmulator  = false;
    bool isSuspect   = false;
    String reason    = '';

    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        if (!info.isPhysicalDevice) {
          isEmulator = true;
          reason     = 'android_emulator';
        }
        final fp = (info.fingerprint).toLowerCase();
        if (!isEmulator &&
            (fp.contains('generic') ||
             fp.contains('unknown') ||
             fp.contains('sdk_gphone') ||
             fp.contains('emulator') ||
             fp.contains('vbox') ||
             fp.contains('test-keys'))) {
          isSuspect = true;
          reason    = 'suspicious_build_fingerprint';
        }
        final model = (info.model).toLowerCase();
        if (!isEmulator && !isSuspect &&
            (model.contains('sdk') ||
             model.contains('emulator') ||
             model.contains('android sdk'))) {
          isSuspect = true;
          reason    = 'suspicious_device_model';
        }
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        if (!info.isPhysicalDevice) {
          isEmulator = true;
          reason     = 'ios_simulator';
        }
      }
    } catch (e) {
      debugPrint('⚠️ DeviceIntegrity check error: $e');
      return DeviceIntegrityResult(
        isClean   : true,
        reason    : null,
        isEmulator: false,
        isSuspect : false,
      );
    }

    final isClean = !isEmulator && !isSuspect;
    return DeviceIntegrityResult(
      isClean   : isClean,
      reason    : isClean ? null : reason,
      isEmulator: isEmulator,
      isSuspect : isSuspect,
    );
  }
}

class DeviceIntegrityResult {
  final bool    isClean;
  final String? reason;
  final bool    isEmulator;
  final bool    isSuspect;

  const DeviceIntegrityResult({
    required this.isClean,
    required this.isEmulator,
    required this.isSuspect,
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
  final TelemetryCollector       _telemetry       = TelemetryCollector();

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

  Future<bool> bootstrap() async {
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
          _currentNonce = data['nonce'];
          challengeCode.value = (data['challengeCode'] as List<dynamic>).map((e) => e as int).toList();
          gestureAudit.clear();
          _telemetry.start();
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

    final telPayload = _telemetry.getPayload();

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
          'rawTelemetry' : telPayload['rawTelemetry'],
          'solveTimeMs'  : telPayload['solveTimeMs'],
          'touchCount'   : telPayload['touchCount'],
          'envelopeScore': telPayload['envelopeScore'],
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) return json.decode(response.body);
      return {'allowed': false, 'error': 'Server error ${response.statusCode}.'};
    } catch (e) {
      return {'allowed': false, 'error': 'Tiada sambungan. Cuba semula.'};
    }
  }

  void registerTouch() {
    _telemetry.recordTouch();
    touchLatched.value = true;
  }

  // ✅ PERBAIKAN MATEMATIK: Terima Posisi Mutlak (Offset), Bukan Kelajuan (Velocity)
  void registerScroll(double offsetPixels) {
    _telemetry.recordMove(0, offsetPixels);
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
// ANTI-SCREENSHOT
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
// UI: WIDGET PRODUK B (WHEEL OVERLAY)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticWidgetProdukB extends StatefulWidget {
  final WidgetController controller;
  final Function(bool) onComplete;
  final VoidCallback onCancel;

  const ZKineticWidgetProdukB({
    super.key,
    required this.controller,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<ZKineticWidgetProdukB> createState() => _ZKineticWidgetProdukBState();
}

class _ZKineticWidgetProdukBState extends State<ZKineticWidgetProdukB> with TickerProviderStateMixin {
  int _uiState = 0; // 0=Loading, 1=Main UI, 2=Verifying, 3=Success, 4=Fail
  String _errorMsg = '';
  late DeviceDNA _dna;

  final List<FixedExtentScrollController> _wheelControllers = [
    FixedExtentScrollController(initialItem: 10),
    FixedExtentScrollController(initialItem: 10),
    FixedExtentScrollController(initialItem: 10),
  ];

  @override
  void initState() {
    super.initState();
    _AntiScreenshot.enable();
    _initFlow();
  }

  @override
  void dispose() {
    _AntiScreenshot.disable();
    for (var c in _wheelControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initFlow() async {
    setState(() => _uiState = 0);
    _dna = await DeviceDNA.collect(context);
    bool ok = await widget.controller.bootstrap();
    if (!ok) {
      setState(() { _uiState = 4; _errorMsg = 'Sistem Keselamatan Gagal Dimuatkan.'; });
      return;
    }
    ok = await widget.controller.fetchChallenge();
    if (!ok) {
      setState(() { _uiState = 4; _errorMsg = 'Ralat Rangkaian / Challenge Gagal.'; });
      return;
    }
    if (mounted) setState(() => _uiState = 1);
  }

  Future<void> _submit() async {
    setState(() => _uiState = 2);
    List<int> answers = _wheelControllers.map((c) => (c.selectedItem % 10 + 10) % 10).toList();
    
    final res = await widget.controller.verify(answers, _wheelControllers, _dna);
    
    if (res['allowed'] == true) {
      setState(() => _uiState = 3);
      await Future.delayed(const Duration(milliseconds: 1800));
      widget.onComplete(true);
    } else {
      setState(() {
        _uiState = 4;
        _errorMsg = res['error'] ?? 'Akses Disekat.';
      });
      await Future.delayed(const Duration(milliseconds: 2000));
      widget.onComplete(false);
    }
  }

  bool _onScrollNotification(ScrollNotification notification, int index) {
    if (notification is ScrollUpdateNotification) {
      widget.controller.registerTouch();
      // ✅ Pembaikan v6: Hantar Scroll Offset (Piksel Mutlak)
      widget.controller.registerScroll(notification.metrics.pixels);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: widget.onCancel,
            child: Container(color: Colors.black.withOpacity(0.85)),
          ),
          Center(
            child: Container(
              width: 340,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
              ),
              child: _buildStateContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_uiState) {
      case 0:
        return const Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.blueAccent),
              SizedBox(height: 20),
              Text('Mengesahkan Persekitaran...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      case 1:
        return _buildBiometricPanel();
      case 2:
        return const Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.greenAccent),
              SizedBox(height: 20),
              Text('Menganalisis Biometrik...', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case 3:
        return Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70, height: 70,
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.black, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('PENGESAHAN BERJAYA', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              const Text('Identiti manusia disahkan.\nMeneruskan transaksi...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      case 4:
      default:
        return Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 60),
              const SizedBox(height: 20),
              const Text('AKSES DISEKAT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                onPressed: widget.onCancel,
                child: const Text('TUTUP', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
    }
  }

  Widget _buildBiometricPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: widget.onCancel,
            ),
          ],
        ),
        const Text('PENGESAHAN BIOMETRIK', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 5),
        const Text('Putar roda untuk memadankan kod di bawah.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 20),
        
        ValueListenableBuilder<List<int>>(
          valueListenable: widget.controller.challengeCode,
          builder: (context, codeList, _) {
            if (codeList.isEmpty) return const SizedBox(height: 40);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: codeList.map((c) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155))
                ),
                child: Text('$c', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              )).toList(),
            );
          }
        ),

        const SizedBox(height: 20),
        Container(
          height: 150,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
            boxShadow: const [BoxShadow(color: Colors.black87, inset: true, blurRadius: 10)],
          ),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) => Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notif) => _onScrollNotification(notif, index),
                    child: ListWheelScrollView.useDelegate(
                      controller: _wheelControllers[index],
                      itemExtent: 50,
                      physics: const FixedExtentScrollPhysics(),
                      overAndUnderCenterOpacity: 0.3,
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, i) {
                          final digit = (i % 10 + 10) % 10;
                          return Center(
                            child: Text(
                              '$digit',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )),
              ),
              Center(
                child: Container(
                  height: 2,
                  color: Colors.blueAccent.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('SAHKAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
