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
        final data = json.decode(response.body);
        _sessionToken = data['token'] as String;

        // 4. Simpan token & expiry time dalam secure storage
        final expiry = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
        await _storage.write(key: 'zk_token_$appId',  value: _sessionToken);
        await _storage.write(key: 'zk_expiry_$appId', value: expiry.toString());

        debugPrint('✅ Token baru diterima & disimpan: ${_sessionToken!.substring(0, 16)}...');
        return true;
      }

      debugPrint('❌ Bootstrap gagal: ${response.statusCode}');
      return false;

    } catch (e) {
      debugPrint('❌ Bootstrap error: $e');
      return false;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FETCH CHALLENGE — panggil selepas bootstrap
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> fetchChallenge() async {
    if (_sessionToken == null) {
      debugPrint('❌ fetchChallenge: token takde — panggil bootstrap dulu');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/challenge'),
        headers: {
          'Content-Type' : 'application/json',
          'Authorization': 'Bearer $_sessionToken',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentNonce = data['nonce'] as String;
        final digitList = (data['digits'] as List).cast<int>();

        challengeCode.value = digitList;
        _challengeStartTime = DateTime.now();
        gestureAudit.clear();
        _touchTimestamps.clear();
        _scrollVelocities.clear();

        debugPrint('✅ Challenge: $digitList (nonce: $_currentNonce)');
      } else {
        debugPrint('❌ fetchChallenge gagal: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ fetchChallenge error: $e');
    }
  }

  void registerTouch() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    _touchTimestamps.add(ts);
    if (_touchTimestamps.length > 20) _touchTimestamps.removeAt(0);
  }

  void registerScroll(double velocity) {
    _scrollVelocities.add(velocity);
    if (_scrollVelocities.length > 20) _scrollVelocities.removeAt(0);
  }

  Future<Map<String, dynamic>> verify(
    List<int> userAnswer,
    List<FixedExtentScrollController> controllers,
    DeviceDNA deviceDNA,
  ) async {
    if (_sessionToken == null || _currentNonce == null) {
      return {'allowed': false, 'error': 'Session tidak valid'};
    }

    try {
      final solveTimeMs = _challengeStartTime != null
          ? DateTime.now().difference(_challengeStartTime!).inMilliseconds
          : 0;

      final rawData = RawBehaviourData(
        touchTimestamps : _touchTimestamps,
        scrollVelocities: _scrollVelocities,
        solveTimeMs     : solveTimeMs,
      );

      final tampered = gestureAudit.isTampered(controllers);

      final response = await http.post(
        Uri.parse('$_serverUrl/verify'),
        headers: {
          'Content-Type' : 'application/json',
          'Authorization': 'Bearer $_sessionToken',
        },
        body: json.encode({
          'nonce'      : _currentNonce,
          'userAnswer' : userAnswer,
          'rawData'    : rawData.toJson(),
          'deviceDNA'  : deviceDNA.toJson(),
          'tampered'   : tampered,
          'motionScore': motionScore.value,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ verify: ${data['allowed']}');
        return data;
      } else {
        debugPrint('❌ verify gagal: ${response.statusCode}');
        return {'allowed': false, 'error': 'Server tolak'};
      }
    } catch (e) {
      debugPrint('❌ verify error: $e');
      return {'allowed': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _accelSub?.cancel();
    _decayTimer?.cancel();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WIDGET
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticWidget extends StatefulWidget {
  final WidgetController controller;
  final DeviceDNA deviceDNA;
  final void Function(bool) onSuccess;
  final VoidCallback onFail;

  const ZKineticWidget({
    super.key,
    required this.controller,
    required this.deviceDNA,
    required this.onSuccess,
    required this.onFail,
  });

  @override
  State<ZKineticWidget> createState() => _ZKineticWidgetState();
}

class _ZKineticWidgetState extends State<ZKineticWidget>
    with TickerProviderStateMixin {
  final _random = Random();
  static const double imageWidth  = ZKineticConfig.imageWidth3;
  static const double imageHeight = ZKineticConfig.imageHeight3;
  static const wheelCoords        = ZKineticConfig.coords3;
  static const buttonCoords       = ZKineticConfig.btnCoords3;

  final List<FixedExtentScrollController> _scrollControllers = [];
  final List<AnimationController> _textOpacityControllers    = [];
  final List<Animation<double>>   _textOpacityAnimations     = [];
  final List<Offset>              _textDriftOffsets          = [Offset.zero, Offset.zero, Offset.zero];
  final List<int>                 _prevItems                 = [0, 0, 0];

  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  Timer? _driftTimer;
  DateTime? _lastScrollTime;
  bool _isButtonPressed = false;
  int _percubaanSalah = 0;

  // 🎯 TRACKING PAN UNTUK DETECT KELUAR DARI KAWASAN RODA
  bool _isPanning = false;
  int? _panningWheelIndex;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      _scrollControllers.add(FixedExtentScrollController(initialItem: 5));
      _prevItems[i] = 5;

      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      )..repeat(reverse: true);

      _textOpacityControllers.add(controller);
      _textOpacityAnimations.add(Tween<double>(begin: 0.3, end: 0.8).animate(controller));
    }
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

  // 🎯 DETECT BILA JARI KELUAR DARI KAWASAN RODA
  bool _isInsideWheel(int wheelIndex, Offset localPosition) {
    final coords = wheelCoords[wheelIndex];
    final left   = coords[0];
    final top    = coords[1];
    final right  = coords[2];
    final bottom = coords[3];

    return localPosition.dx >= left &&
           localPosition.dx <= right &&
           localPosition.dy >= top &&
           localPosition.dy <= bottom;
  }

  void _handlePanStart(int wheelIndex, DragStartDetails details) {
    _isPanning = true;
    _panningWheelIndex = wheelIndex;
    _onWheelScrollStart(wheelIndex);
  }

  void _handlePanUpdate(int wheelIndex, DragUpdateDetails details, RenderBox box) {
    if (!_isPanning || _panningWheelIndex != wheelIndex) return;

    // Convert global position to local position dalam Stack
    final localPosition = box.globalToLocal(details.globalPosition);

    // Check sama ada masih dalam kawasan roda
    if (!_isInsideWheel(wheelIndex, localPosition)) {
      // 🛑 JARI DAH KELUAR! Hentikan scroll dengan settle
      _forceStopWheel(wheelIndex);
      _isPanning = false;
      _panningWheelIndex = null;
    }
  }

  void _handlePanEnd(int wheelIndex, DragEndDetails details) {
    _isPanning = false;
    _panningWheelIndex = null;
    _onWheelScrollEnd(wheelIndex);
  }

  void _forceStopWheel(int wheelIndex) {
    // Force settle to nearest item dengan animasi halus
    if (_scrollControllers[wheelIndex].hasClients) {
      final currentItem = _scrollControllers[wheelIndex].selectedItem;
      _scrollControllers[wheelIndex].animateToItem(
        currentItem,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      HapticFeedback.lightImpact();
    }
    _onWheelScrollEnd(wheelIndex);
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

  Widget _buildWheel(int index) {
    final coords      = wheelCoords[index];
    final double left   = coords[0];
    final double top    = coords[1];
    final double width  = coords[2] - coords[0];
    final double height = coords[3] - coords[1];
    final isActive    = _activeWheelIndex == index;

    return Positioned(
      left: left, top: top, width: width, height: height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification) {
            if (_scrollControllers[index].position == n.metrics) _onWheelScrollStart(index);
          } else if (n is ScrollUpdateNotification) {
            _onWheelScrollUpdate(index);
          } else if (n is ScrollEndNotification) {
            _onWheelScrollEnd(index);
          }
          return false;
        },
        child: GestureDetector(
          onTapDown: (_) => _onWheelScrollStart(index),
          onTapUp: (_) => _onWheelScrollEnd(index),
          // 🎯 TAMBAH PAN DETECTION UNTUK TRACK BILA KELUAR KAWASAN
          onPanStart: (details) => _handlePanStart(index, details),
          onPanUpdate: (details) {
            // Dapatkan RenderBox untuk convert koordinat
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              _handlePanUpdate(index, details, box);
            }
          },
          onPanEnd: (details) => _handlePanEnd(index, details),
          behavior: HitTestBehavior.opaque,
          child: ListWheelScrollView.useDelegate(
            controller: _scrollControllers[index],
            itemExtent: height * 0.40,
            perspective: 0.001,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
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
                              fontSize: height * 0.30,
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BACKWARD COMPATIBILITY - Nama lama untuk main.dart
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Widget ZKineticWidgetProdukB({
  required WidgetController controller,
  required DeviceDNA deviceDNA,
  void Function(bool)? onComplete,
  void Function(bool)? onSuccess,
  VoidCallback? onFail,
}) {
  return ZKineticWidget(
    controller: controller,
    deviceDNA: deviceDNA,
    onSuccess: onComplete ?? onSuccess ?? (bool result) {},
    onFail: onFail ?? () {},
  );
}
