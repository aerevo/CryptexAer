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
// Z-KINETIC SDK v4.1 - PRODUCTION GRADE (OPTION B)
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
// DEVICE DNA
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class DeviceDNA {
  final String model;
  final String osVersion;
  final String screenRes;

  DeviceDNA({required this.model, required this.osVersion, required this.screenRes});

  Map<String, dynamic> toJson() => {
    'model': model,
    'osVersion': osVersion,
    'screenRes': screenRes,
  };

  static Future<DeviceDNA> collect(BuildContext context) async {
    final deviceInfo = DeviceInfoPlugin();
    String model = 'Unknown';
    String osVersion = 'Unknown';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        model = '${androidInfo.manufacturer} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        model = iosInfo.model;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      }
    } catch (e) {
      debugPrint('⚠️ Device info error: $e');
    }

    final size = MediaQuery.of(context).size;
    final ratio = MediaQuery.of(context).devicePixelRatio;
    final screenRes = '${(size.width * ratio).toInt()}x${(size.height * ratio).toInt()}';

    return DeviceDNA(model: model, osVersion: osVersion, screenRes: screenRes);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RAW BEHAVIOUR DATA
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RawBehaviourData {
  final List<int> touchTimestamps;
  final List<double> scrollVelocities;
  final int solveTimeMs;

  RawBehaviourData({
    required this.touchTimestamps,
    required this.scrollVelocities,
    required this.solveTimeMs,
  });

  Map<String, dynamic> toJson() => {
    'touchTimestamps': touchTimestamps,
    'scrollVelocities': scrollVelocities,
    'solveTimeMs': solveTimeMs,
  };
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
      final digit = (controllers[i].selectedItem % 10 + 10) % 10;
      final wheelEvents = _events.where((e) => e.wheelIndex == i).toList();
      if (digit != 0 && wheelEvents.isEmpty) return true;
    }
    return false;
  }

  void clear() => _events.clear();
}

class _ScrollEvent {
  final int wheelIndex, fromItem, toItem;
  final DateTime at;
  _ScrollEvent(this.wheelIndex, this.fromItem, this.toItem, this.at);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WIDGET CONTROLLER
// API key tak pernah duduk dalam APK.
// APK simpan appId sahaja (tak rahsia).
// Session token diambil dari server & disimpan dalam
// flutter_secure_storage (encrypted di dalam peranti).
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WidgetController {
  static const String _serverUrl = 'https://zticketapp-dxtcyy6wma-as.a.run.app';
  static const _storage = FlutterSecureStorage();

  // ✅ appId sahaja — boleh nampak dalam APK, tak bahaya
  final String appId;

  String? _sessionToken;
  String? _currentNonce;
  final ValueNotifier<List<int>> challengeCode = ValueNotifier([]);
  final ValueNotifier<int> randomizeTrigger    = ValueNotifier(0);
  final GestureAudit gestureAudit = GestureAudit();

  final List<int>    _touchTimestamps  = [];
  final List<double> _scrollVelocities = [];
  DateTime? _challengeStartTime;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double   _lastMagnitude  = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer?   _decayTimer;
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);

  WidgetController({required this.appId}) {
    _initSensors();
    _startDecayTimer();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final delta = (magnitude - _lastMagnitude).abs();
      if (delta > 0.3) {
        motionScore.value = (delta / 3.0).clamp(0.0, 1.0);
        _lastMotionTime = DateTime.now();
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HMAC sign — guna appId sebagai key
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  String _hmacSign(String data) {
    final key  = utf8.encode(appId);
    final body = utf8.encode(data);
    return Hmac(sha256, key).convert(body).toString();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // BOOTSTRAP — dapatkan session token
  // Panggil ini sekali sebelum fetchChallenge
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<bool> bootstrap() async {
    try {
      // 1. Semak token dalam secure storage — kalau masih valid, guna terus
      final cached = await _storage.read(key: 'zk_token_$appId');
      final expiry = await _storage.read(key: 'zk_expiry_$appId');

      if (cached != null && expiry != null) {
        final exp = int.tryParse(expiry) ?? 0;
        if (DateTime.now().millisecondsSinceEpoch < exp) {
          _sessionToken = cached;
          debugPrint('✅ Token reused dari secure storage');
          return true;
        }
      }

      // 2. Token expired atau takde — minta baru dari server
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

      // 3. Sign request dengan HMAC — walaupun appId tahu,
      //    server semak timestamp tidak lebih 30 saat lama
      final ts        = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = _hmacSign('$appId:$deviceId:$ts');

      final response = await http.post(
        Uri.parse('$_serverUrl/bootstrap'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'appId'    : appId,
          'deviceId' : deviceId,
          'platform' : platform,
          'ts'       : ts,
          'signature': signature,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data   = json.decode(response.body);
        final token  = data['token']  as String?;
        final expMs  = data['expiry'] as int?;

        if (token != null && expMs != null) {
          // 4. Simpan dalam secure storage (encrypted)
          await _storage.write(key: 'zk_token_$appId',  value: token);
          await _storage.write(key: 'zk_expiry_$appId', value: expMs.toString());
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FETCH CHALLENGE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
          challengeCode.value =
              (data['challengeCode'] as List<dynamic>).map((e) => e as int).toList();
          _touchTimestamps.clear();
          _scrollVelocities.clear();
          _challengeStartTime = DateTime.now();
          gestureAudit.clear();
          return true;
        }
      }

      // Token expired — clear dan perlu bootstrap semula
      if (response.statusCode == 401) {
        await _storage.delete(key: 'zk_token_$appId');
        await _storage.delete(key: 'zk_expiry_$appId');
        _sessionToken = null;
      }

      return false;
    } catch (e) {
      debugPrint('🔒 Network error - DENY: $e');
      return false;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // VERIFY
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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

    final solveTimeMs = _challengeStartTime != null
        ? DateTime.now().difference(_challengeStartTime!).inMilliseconds : 0;

    final rawBehaviour = RawBehaviourData(
      touchTimestamps : List.from(_touchTimestamps),
      scrollVelocities: List.from(_scrollVelocities),
      solveTimeMs     : solveTimeMs,
    );

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/attest'),
        headers: {
          'Content-Type'   : 'application/json',
          'x-session-token': _sessionToken!,
        },
        body: json.encode({
          'nonce'       : _currentNonce,
          'userAnswer'  : userAnswer,
          'deviceDNA'   : deviceDNA.toJson(),
          'rawBehaviour': rawBehaviour.toJson(),
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) return json.decode(response.body);
      return {'allowed': false, 'error': 'Server error ${response.statusCode}.'};
    } catch (e) {
      return {'allowed': false, 'error': 'Tiada sambungan. Cuba semula.'};
    }
  }

  void registerTouch() {
    if (_challengeStartTime != null) {
      final elapsed = DateTime.now().difference(_challengeStartTime!).inMilliseconds;
      _touchTimestamps.add(elapsed);
      if (_touchTimestamps.length > 20) _touchTimestamps.removeAt(0);
    }
  }

  void registerScroll(double velocity) {
    _scrollVelocities.add(velocity);
    if (_scrollVelocities.length > 20) _scrollVelocities.removeAt(0);
  }

  void randomizeWheels() => randomizeTrigger.value++;

  void dispose() {
    _accelSub?.cancel();
    _decayTimer?.cancel();
    challengeCode.dispose();
    randomizeTrigger.dispose();
    motionScore.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN WIDGET
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticWidgetProdukB extends StatefulWidget {
  final WidgetController controller;
  final Function(bool success) onComplete;
  final VoidCallback? onCancel;

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
  bool _loading = true;
  bool _networkError = false;
  DeviceDNA? _deviceDNA;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Bootstrap dulu — dapatkan session token
    final bootstrapOk = await widget.controller.bootstrap();
    if (!bootstrapOk) {
      if (mounted) setState(() { _loading = false; _networkError = true; });
      return;
    }

    _deviceDNA = await DeviceDNA.collect(context);
    final success = await widget.controller.fetchChallenge();
    if (mounted) {
      setState(() {
        _loading = false;
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
            padding: const EdgeInsets.only(top: 14, bottom: 8, left: 16, right: 16),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else if (_deviceDNA != null)
                  UltimateCryptexLock(
                    controller: widget.controller,
                    deviceDNA: _deviceDNA!,
                    onSuccess: (success) => widget.onComplete(success),
                    onFail: () => widget.onComplete(false),
                  ),
                const SizedBox(height: 10),
                _buildBiometricPanel(),
                const SizedBox(height: 6),
                if (widget.onCancel != null)
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel',
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
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF263238),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                'SAMBUNGAN DIPERLUKAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: Colors.white, letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Z-Kinetic memerlukan sambungan internet untuk pengesahan selamat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() { _loading = true; _networkError = false; });
                  await _initialize();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Cuba Semula'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Kembali', style: TextStyle(color: Colors.white54)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5722),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIndicator(Icons.sensors, 'MOTION', widget.controller.motionScore),
          _buildIndicator(Icons.touch_app, 'TOUCH',
              ValueNotifier(widget.controller._touchTimestamps.length > 3 ? 0.8 : 0.3)),
          _buildIndicator(Icons.fingerprint, 'PATTERN',
              ValueNotifier(widget.controller._scrollVelocities.length > 3 ? 0.8 : 0.3)),
        ],
      ),
    );
  }

  Widget _buildIndicator(IconData icon, String label, ValueNotifier<double> notifier) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, value, _) {
        final isActive = value > 0.5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.greenAccent : Colors.white30),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize: 7, color: isActive ? Colors.greenAccent : Colors.white30,
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

class _UltimateRGBGlitchDisplayState extends State<UltimateRGBGlitchDisplay> {
  Timer? _glitchTimer;
  Timer? _noiseTimer;
  bool   _isGlitching = false;
  double _xOffset = 0.0, _yOffset = 0.0;
  int    _noiseSeed = DateTime.now().millisecondsSinceEpoch;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _glitchTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        _isGlitching = _random.nextDouble() > 0.7;
        _xOffset = _random.nextDouble() * 3 - 1.5;
        _yOffset = _random.nextDouble() * 2 - 1.0;
      });
    });
    _noiseTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _noiseSeed = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _glitchTimer?.cancel();
    _noiseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10)],
      ),
      child: ValueListenableBuilder<List<int>>(
        valueListenable: widget.controller.challengeCode,
        builder: (context, code, _) {
          if (code.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            );
          }
          final codeStr = code.join('');
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: CustomPaint(painter: _NoisePainter(seed: _noiseSeed))),
                if (_isGlitching)
                  Transform.translate(
                    offset: Offset(_xOffset + 2, _yOffset),
                    child: Text(codeStr, style: _glitchStyle(Colors.cyan)),
                  ),
                if (_isGlitching)
                  Transform.translate(
                    offset: Offset(-_xOffset - 2, -_yOffset),
                    child: Text(codeStr, style: _glitchStyle(const Color(0xFFFF00FF))),
                  ),
                Text(codeStr, style: _glitchStyle(Colors.white)),
              ],
            ),
          );
        },
      ),
    );
  }

  TextStyle _glitchStyle(Color color) => TextStyle(
    fontSize: 28, fontWeight: FontWeight.bold,
    fontFamily: 'Courier', letterSpacing: 8, color: color,
  );
}

class _NoisePainter extends CustomPainter {
  final int seed;
  _NoisePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = Random(seed);
    final paint = Paint()..strokeWidth = 0.8..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      paint.color = Colors.white.withOpacity(rng.nextDouble() * 0.12 + 0.03);
      canvas.drawLine(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        paint,
      );
    }
    for (int g = 0; g < 3; g++) {
      final tp = TextPainter(
        text: TextSpan(
          text: rng.nextInt(10).toString(),
          style: TextStyle(
            fontSize: 14 + rng.nextDouble() * 10,
            color: Colors.white.withOpacity(rng.nextDouble() * 0.1 + 0.03),
            fontWeight: FontWeight.bold, fontFamily: 'Courier',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height));
    }
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int d = 0; d < 12; d++) {
      dotPaint.color = Colors.white.withOpacity(rng.nextDouble() * 0.08 + 0.02);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.5 + 0.3,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_NoisePainter old) => old.seed != seed;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CRYPTEX LOCK
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateCryptexLock extends StatefulWidget {
  final WidgetController controller;
  final DeviceDNA deviceDNA;
  final Function(bool) onSuccess;
  final VoidCallback onFail;

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
  static const double imageWidth  = ZKineticConfig.imageWidth3;
  static const double imageHeight = ZKineticConfig.imageHeight3;
  static const List<List<double>> wheelCoords  = ZKineticConfig.coords3;
  static const List<double>       buttonCoords = ZKineticConfig.btnCoords3;

  late List<FixedExtentScrollController> _scrollControllers;
  final List<int> _prevItems = [0, 0, 0];
  DateTime? _lastScrollTime;

  int?   _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool   _isButtonPressed = false;
  final Random _random = Random();

  late List<AnimationController> _textOpacityControllers;
  late List<Animation<double>>   _textOpacityAnimations;
  final List<Offset> _textDriftOffsets = [Offset.zero, Offset.zero, Offset.zero];
  Timer? _driftTimer;
  int _percubaanSalah = 0; // Kaunter 3 Nyawa

  // ─── FIX: Manual drag tracking untuk swipe terhad dalam kawasan roda ───
  final List<double> _dragAccumulators = [0.0, 0.0, 0.0];
  final List<bool>   _isDraggingWheel  = [false, false, false];
  // ────────────────────────────────────────────────────────────────────────

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
          curve: Curves.elasticOut,
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

    final current = _scrollControllers[index].selectedItem;
    if (current != _prevItems[index]) {
      widget.controller.gestureAudit.recordScroll(index, _prevItems[index], current, now);
      _prevItems[index] = current;
    }
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
      // 🎉 LULUS! Reset nyawa dan benarkan masuk
      _percubaanSalah = 0;
      widget.onSuccess(true);
    } else {
      // ❌ SALAH! Tolak nyawa
      setState(() {
        _percubaanSalah++;
      });

      if (_percubaanSalah >= 3) {
        // ⛔ HABIS 3 NYAWA: Halau keluar
        _percubaanSalah = 0; // Reset untuk cabaran akan datang
        widget.onFail(); // Panggil dialog Access Denied (Merah) di main.dart
      } else {
        // 🔄 BAGI PELUANG (PUSING RAWAK)
        int bakiNyawa = 3 - _percubaanSalah;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Akses Ditolak! Padanan kod salah. Baki peluang: $bakiNyawa',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        HapticFeedback.heavyImpact(); // Gegar fon

        // Panggil fungsi intro ni untuk rawakkan roda (susahkan bot!)
        _playSlotMachineIntro();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: imageWidth,
        height: imageHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/z_wheel3.png',
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey,
                  child: const Icon(Icons.broken_image, size: 60, color: Colors.white),
                ),
              ),
            ),
            for (int i = 0; i < 3; i++) _buildWheel(i),
            _buildGlowingButton(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FIX: Swipe hanya berfungsi dalam kawasan roda sahaja.
  //
  // Pendekatan lama: ListWheelScrollView guna physics sendiri → Flutter track
  // pointer secara global selepas drag start → scroll terus walaupun jari
  // dah keluar dari kawasan roda.
  //
  // Pendekatan baru:
  //   1. ListWheelScrollView pakai NeverScrollableScrollPhysics (disable scroll sendiri)
  //   2. GestureDetector intercept semua drag secara manual
  //   3. Dalam onVerticalDragUpdate, semak details.localPosition — kalau jari
  //      keluar dari batas [0..width] × [0..height], terus stop dan snap ke
  //      item semasa. Tidak terima sebarang update lagi sehingga drag baru.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWheel(int index) {
    final coords      = wheelCoords[index];
    final double left   = coords[0];
    final double top    = coords[1];
    final double width  = coords[2] - coords[0];
    final double height = coords[3] - coords[1];
    final isActive    = _activeWheelIndex == index;
    final double itemExtent = height * 0.40;

    return Positioned(
      left: left, top: top, width: width, height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onVerticalDragStart: (details) {
          _isDraggingWheel[index]  = true;
          _dragAccumulators[index] = 0.0;
          _onWheelScrollStart(index);
        },

        onVerticalDragUpdate: (details) {
          // Abaikan kalau drag dah dibatalkan (jari keluar kawasan sebelum ni)
          if (!_isDraggingWheel[index]) return;

          // ── Semak sempadan: jika jari keluar dari kawasan roda, stop terus ──
          final lp = details.localPosition;
          if (lp.dx < 0 || lp.dx > width || lp.dy < 0 || lp.dy > height) {
            _isDraggingWheel[index] = false;
            // Snap ke item semasa dengan lembut
            _scrollControllers[index].animateToItem(
              _scrollControllers[index].selectedItem,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
            _onWheelScrollEnd(index);
            return;
          }

          // ── Scroll manual: kumpul delta → tukar item bila cukup satu langkah ──
          _dragAccumulators[index] += details.delta.dy;
          while (_dragAccumulators[index].abs() >= itemExtent) {
            if (_dragAccumulators[index] > 0) {
              _dragAccumulators[index] -= itemExtent;
              _scrollControllers[index].jumpToItem(
                _scrollControllers[index].selectedItem - 1,
              );
            } else {
              _dragAccumulators[index] += itemExtent;
              _scrollControllers[index].jumpToItem(
                _scrollControllers[index].selectedItem + 1,
              );
            }
          }
          _onWheelScrollUpdate(index);
        },

        onVerticalDragEnd: (_) {
          if (!_isDraggingWheel[index]) return;
          _isDraggingWheel[index] = false;
          _onWheelScrollEnd(index);
        },

        onVerticalDragCancel: () {
          _isDraggingWheel[index] = false;
          _onWheelScrollEnd(index);
        },

        child: ListWheelScrollView.useDelegate(
          controller   : _scrollControllers[index],
          itemExtent   : itemExtent,
          perspective  : 0.001,
          diameterRatio: 1.5,
          // NeverScrollableScrollPhysics: disable scroll dalaman —
          // semua pergerakan dikawal sepenuhnya oleh GestureDetector di atas
          physics      : const NeverScrollableScrollPhysics(),
          onSelectedItemChanged: (_) => HapticFeedback.selectionClick(),
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, idx) {
              final displayNumber = (idx % 10 + 10) % 10;
              return Center(
                child: AnimatedBuilder(
                  animation: _textOpacityAnimations[index],
                  builder: (context, child) {
                    return Transform.translate(
                      offset: isActive ? Offset.zero : _textDriftOffsets[index],
                      child: Opacity(
                        opacity: isActive ? 1.0 : _textOpacityAnimations[index].value,
                        child: Text(
                          '$displayNumber',
                          style: TextStyle(
                            fontSize  : height * 0.30,
                            fontWeight: FontWeight.w900,
                            color: isActive ? const Color(0xFFFF5722) : const Color(0xFF263238),
                            height: 1.0,
                            shadows: isActive
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
            color: Colors.transparent,
            boxShadow: _isButtonPressed
                ? []
                : [BoxShadow(
                    color: const Color(0xFFFF5722).withOpacity(0.5),
                    blurRadius: 20, spreadRadius: 2,
                  )],
          ),
        ),
      ),
    );
  }
}
