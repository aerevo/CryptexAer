import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC SDK v5.0 - PRODUCTION GRADE CLEAN REBUILD
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ✅ CLEAN layout (Row-based, no string tricks)
// ✅ Proper glitch animation (simple & effective)
// ✅ Backend-compatible JSON format
// ✅ Device DNA fingerprinting
// ✅ Raw behaviour data collection
// ✅ Production security standard
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticConfig {
  static const double imageWidth3 = 712.0;
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

  DeviceDNA({
    required this.model,
    required this.osVersion,
    required this.screenRes,
  });

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
    final width = (size.width * ratio).toInt();
    final height = (size.height * ratio).toInt();
    final screenRes = '${width}x$height';

    return DeviceDNA(
      model: model,
      osVersion: osVersion,
      screenRes: screenRes,
    );
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
      final raw = controllers[i].selectedItem;
      final digit = (raw % 10 + 10) % 10;
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
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WidgetController {
  static const String _serverUrl = 'https://api-dxtcyy6wma-as.a.run.app';

  final String apiKey;

  String? _currentNonce;
  final ValueNotifier<List<int>> challengeCode = ValueNotifier([]);
  final ValueNotifier<int> randomizeTrigger = ValueNotifier(0);

  final GestureAudit gestureAudit = GestureAudit();

  final List<int> _touchTimestamps = [];
  final List<double> _scrollVelocities = [];
  DateTime? _challengeStartTime;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _lastMagnitude = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer? _decayTimer;
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);

  WidgetController({required this.apiKey}) {
    _initSensors();
    _startDecayTimer();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
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

  Future<bool> fetchChallenge() async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/getChallenge'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: json.encode({}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['challengeCode'] != null && data['nonce'] != null) {
          _currentNonce = data['nonce'];
          challengeCode.value = (data['challengeCode'] as List<dynamic>)
              .map((e) => e as int)
              .toList();

          _touchTimestamps.clear();
          _scrollVelocities.clear();
          _challengeStartTime = DateTime.now();
          gestureAudit.clear();

          debugPrint('✅ Challenge: ${challengeCode.value}');
          return true;
        }
      }

      debugPrint('🔒 Server error - DENY');
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
    if (challengeCode.value.isEmpty || _currentNonce == null) {
      return {'allowed': false, 'error': 'Tiada cabaran aktif.'};
    }

    if (gestureAudit.isTampered(controllers)) {
      debugPrint('🚨 Tamper detected!');
      return {
        'allowed': false,
        'error': 'Aktiviti mencurigakan.',
        'reason': 'TAMPER_DETECTED'
      };
    }

    final solveTimeMs = _challengeStartTime != null
        ? DateTime.now().difference(_challengeStartTime!).inMilliseconds
        : 0;

    final rawBehaviour = RawBehaviourData(
      touchTimestamps: List.from(_touchTimestamps),
      scrollVelocities: List.from(_scrollVelocities),
      solveTimeMs: solveTimeMs,
    );

    try {
      final requestBody = {
        'nonce': _currentNonce,
        'userAnswer': userAnswer,
        'deviceDNA': deviceDNA.toJson(),
        'rawBehaviour': rawBehaviour.toJson(),
      };

      debugPrint('📤 Request: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$_serverUrl/attest'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('✅ Response: ${json.encode(result)}');
        return result;
      }

      return {'allowed': false, 'error': 'Server error ${response.statusCode}.'};
    } catch (e) {
      debugPrint('🔒 Network error: $e');
      return {'allowed': false, 'error': 'Tiada sambungan. Cuba semula.'};
    }
  }

  void registerTouch() {
    if (_challengeStartTime != null) {
      final elapsed =
          DateTime.now().difference(_challengeStartTime!).inMilliseconds;
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
    _deviceDNA = await DeviceDNA.collect(context);
    debugPrint('📱 Device DNA: ${_deviceDNA!.toJson()}');

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
    if (_networkError) {
      return _buildNetworkErrorScreen();
    }

    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Z-KINETIC',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user,
                          color: Colors.greenAccent, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'INTELLIGENT-GRADE BIOMETRIC LOCK',
                        style: TextStyle(
                          fontSize: 7,
                          color: Colors.white,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CleanChallengeDisplay(controller: widget.controller),
                const SizedBox(height: 8),
                const Text(
                  'Please match the code',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                if (_deviceDNA != null)
                  UltimateCryptexLock(
                    controller: widget.controller,
                    deviceDNA: _deviceDNA!,
                    onSuccess: (success) => widget.onComplete(success),
                    onFail: () => widget.onComplete(false),
                  ),
                const SizedBox(height: 12),
                _buildBiometricPanel(),
                if (widget.onCancel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
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
            border: Border.all(
                color: Colors.redAccent.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                'SAMBUNGAN DIPERLUKAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
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
                  setState(() {
                    _loading = true;
                    _networkError = false;
                  });
                  await _initialize();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Cuba Semula'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Kembali',
                      style: TextStyle(color: Colors.white54)),
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
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5722),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIndicator(Icons.sensors, 'MOTION', widget.controller.motionScore),
          _buildIndicator(
              Icons.touch_app,
              'TOUCH',
              ValueNotifier(
                  widget.controller._touchTimestamps.length > 3 ? 0.8 : 0.3)),
          _buildIndicator(
              Icons.fingerprint,
              'PATTERN',
              ValueNotifier(
                  widget.controller._scrollVelocities.length > 3 ? 0.8 : 0.3)),
        ],
      ),
    );
  }

  Widget _buildIndicator(
      IconData icon, String label, ValueNotifier<double> notifier) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, value, _) {
        final isActive = value > 0.5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: isActive ? Colors.greenAccent : Colors.white30),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 6,
                color: isActive ? Colors.greenAccent : Colors.white30,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CLEAN CHALLENGE DISPLAY - ROW LAYOUT (NO STRING TRICKS!)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class CleanChallengeDisplay extends StatefulWidget {
  final WidgetController controller;
  const CleanChallengeDisplay({super.key, required this.controller});

  @override
  State<CleanChallengeDisplay> createState() => _CleanChallengeDisplayState();
}

class _CleanChallengeDisplayState extends State<CleanChallengeDisplay> {
  Timer? _glitchTimer;
  bool _isGlitching = false;
  final Random _random = Random();
  double _glitchOffset = 0.0;

  @override
  void initState() {
    super.initState();
    // Simple glitch animation
    _glitchTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _isGlitching = _random.nextDouble() > 0.7;
        _glitchOffset = _random.nextDouble() * 2 - 1; // -1 to 1
      });
    });
  }

  @override
  void dispose() {
    _glitchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF3E2723),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ValueListenableBuilder<List<int>>(
        valueListenable: widget.controller.challengeCode,
        builder: (context, code, _) {
          if (code.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            );
          }

          // ✅ CLEAN: Each digit separate, Row layout
          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDigit(code[0]),
                const SizedBox(width: 24), // Fixed spacing
                _buildDigit(code[1]),
                const SizedBox(width: 24), // Fixed spacing
                _buildDigit(code[2]),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ Single digit with glitch effect
  Widget _buildDigit(int digit) {
    return SizedBox(
      width: 40,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glitch layer (cyan - subtle)
          if (_isGlitching)
            Transform.translate(
              offset: Offset(_glitchOffset * 2, 0),
              child: Text(
                '$digit',
                style: _digitStyle(Colors.cyan.withOpacity(0.6)),
              ),
            ),
          // Glitch layer (magenta - subtle)
          if (_isGlitching)
            Transform.translate(
              offset: Offset(-_glitchOffset * 2, 0),
              child: Text(
                '$digit',
                style: _digitStyle(const Color(0xFFFF00FF).withOpacity(0.6)),
              ),
            ),
          // Main digit (white - always visible)
          Text(
            '$digit',
            style: _digitStyle(Colors.white),
          ),
        ],
      ),
    );
  }

  TextStyle _digitStyle(Color color) {
    return TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w900,
      fontFamily: 'Courier',
      color: color,
      height: 1.0,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.8),
          blurRadius: 8,
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CRYPTEX LOCK (same as before, working properly)
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
  static const double imageWidth = ZKineticConfig.imageWidth3;
  static const double imageHeight = ZKineticConfig.imageHeight3;
  static const List<List<double>> wheelCoords = ZKineticConfig.coords3;
  static const List<double> buttonCoords = ZKineticConfig.btnCoords3;

  late List<FixedExtentScrollController> _scrollControllers;
  final List<int> _prevItems = [0, 0, 0];
  DateTime? _lastScrollTime;

  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _isButtonPressed = false;
  final Random _random = Random();

  late List<AnimationController> _textOpacityControllers;
  late List<Animation<double>> _textOpacityAnimations;
  final List<Offset> _textDriftOffsets = [Offset.zero, Offset.zero, Offset.zero];
  Timer? _driftTimer;

  @override
  void initState() {
    super.initState();
    _scrollControllers =
        List.generate(3, (i) => FixedExtentScrollController(initialItem: 0));

    _textOpacityControllers = List.generate(
      3,
      (i) => AnimationController(
          duration: const Duration(milliseconds: 800), vsync: this)
        ..repeat(reverse: true),
    );
    _textOpacityAnimations = _textOpacityControllers
        .map((c) => Tween<double>(begin: 0.75, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    _startDriftTimer();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _playSlotMachineIntro());
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
        final target = 20 + _random.nextInt(10);
        _scrollControllers[i].animateToItem(
          target,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.elasticOut,
        );
      });
    }
  }

  @override
  void dispose() {
    for (var c in _scrollControllers) {
      c.dispose();
    }
    for (var c in _textOpacityControllers) {
      c.dispose();
    }
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
      if (deltaMs > 0) {
        final velocity = 100.0 / deltaMs;
        widget.controller.registerScroll(velocity);
      }
    }
    _lastScrollTime = now;

    final current = _scrollControllers[index].selectedItem;
    if (current != _prevItems[index]) {
      widget.controller.gestureAudit.recordScroll(
        index,
        _prevItems[index],
        current,
        DateTime.now(),
      );
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
      final raw = c.selectedItem;
      userAnswer.add((raw % 10 + 10) % 10);
    }

    final result = await widget.controller.verify(
      userAnswer,
      _scrollControllers,
      widget.deviceDNA,
    );

    widget.onSuccess(result['allowed'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth - 80;
    final aspectRatio = imageWidth / imageHeight;
    final containerWidth = maxWidth.clamp(300.0, 600.0);
    final containerHeight = containerWidth / aspectRatio;

    return SizedBox(
      width: containerWidth,
      height: containerHeight,
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
          for (int i = 0; i < 3; i++)
            _buildWheel(i, containerWidth, containerHeight),
          _buildGlowingButton(containerWidth, containerHeight),
        ],
      ),
    );
  }

  Widget _buildWheel(int index, double containerWidth, double containerHeight) {
    final coords = wheelCoords[index];
    final wheelLeft = (coords[0] / imageWidth) * containerWidth;
    final wheelTop = (coords[1] / imageHeight) * containerHeight;
    final wheelWidth = ((coords[2] - coords[0]) / imageWidth) * containerWidth;
    final wheelHeight =
        ((coords[3] - coords[1]) / imageHeight) * containerHeight;
    final isActive = _activeWheelIndex == index;

    return Positioned(
      left: wheelLeft,
      top: wheelTop,
      width: wheelWidth,
      height: wheelHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification) {
            if (_scrollControllers[index].position == n.metrics) {
              _onWheelScrollStart(index);
            }
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
          behavior: HitTestBehavior.opaque,
          child: ListWheelScrollView.useDelegate(
            controller: _scrollControllers[index],
            itemExtent: wheelHeight * 0.40,
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
                          opacity: isActive
                              ? 1.0
                              : _textOpacityAnimations[index].value,
                          child: Text(
                            '$displayNumber',
                            style: TextStyle(
                              fontSize: wheelHeight * 0.30,
                              fontWeight: FontWeight.w900,
                              color: isActive
                                  ? const Color(0xFFFF5722)
                                  : const Color(0xFF263238),
                              height: 1.0,
                              shadows: isActive
                                  ? [
                                      Shadow(
                                        color: const Color(0xFFFF5722)
                                            .withOpacity(0.8),
                                        blurRadius: 20,
                                      ),
                                    ]
                                  : [
                                      const Shadow(
                                        offset: Offset(1, 1),
                                        color: Colors.black26,
                                        blurRadius: 2,
                                      ),
                                    ],
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

  Widget _buildGlowingButton(
      double containerWidth, double containerHeight) {
    final btnLeft = (buttonCoords[0] / imageWidth) * containerWidth;
    final btnTop = (buttonCoords[1] / imageHeight) * containerHeight;
    final btnWidth =
        ((buttonCoords[2] - buttonCoords[0]) / imageWidth) * containerWidth;
    final btnHeight =
        ((buttonCoords[3] - buttonCoords[1]) / imageHeight) * containerHeight;

    return Positioned(
      left: btnLeft,
      top: btnTop,
      width: btnWidth,
      height: btnHeight,
      child: GestureDetector(
        onTap: _onButtonTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            boxShadow: _isButtonPressed
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
