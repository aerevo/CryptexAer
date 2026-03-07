import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC SDK v3.0 - PRODUCTION GRADE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 🔒 OFFLINE = TOTAL LOCKDOWN (no demo mode, no fallback)
// ✅ GestureAudit: tamper detect
// ✅ Visual noise: anti-OCR RGB glitch
// ✅ Real biometric tracking
// ✅ Production security standard
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
// GESTURE AUDIT — detect memory injection attacks
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
      final raw   = controllers[i].selectedItem;
      final digit = (raw % 10 + 10) % 10;
      final wheelEvents = _events.where((e) => e.wheelIndex == i).toList();
      if (digit != 0 && wheelEvents.isEmpty) return true;
    }
    return false;
  }

  double get scrollEntropy {
    if (_events.length < 3) return 0.5;
    final intervals = <int>[];
    for (int i = 1; i < _events.length; i++) {
      intervals.add(_events[i].at.difference(_events[i - 1].at).inMilliseconds);
    }
    final avg      = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals.map((i) => (i - avg).abs()).reduce((a, b) => a + b) / intervals.length;
    return (variance / avg).clamp(0.0, 1.0);
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
  final ValueNotifier<List<int>> challengeCode  = ValueNotifier([]);
  final ValueNotifier<int>       randomizeTrigger = ValueNotifier(0);

  final ValueNotifier<double> motionScore  = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore   = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);

  final GestureAudit gestureAudit = GestureAudit();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double   _lastMagnitude  = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer?   _decayTimer;

  DateTime? _lastTouchTime;
  final List<int> _touchIntervals = [];

  final List<double> _scrollVelocities = [];
  DateTime? _lastScrollTime;

  WidgetController({required this.apiKey}) {
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
        motionScore.value = (delta / 3.0).clamp(0.0, 1.0);
        _lastMotionTime   = DateTime.now();
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

  // 🔒 PRODUCTION: Offline = FAIL (no demo mode, no fallback)
  Future<bool> fetchChallenge() async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/challenge'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: json.encode({}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['challengeCode'] != null) {
          _currentNonce = data['nonce'];
          challengeCode.value =
              (data['challengeCode'] as List<dynamic>).map((e) => e as int).toList();
          gestureAudit.clear();
          debugPrint('✅ Challenge from server: ${challengeCode.value}');
          return true;
        }
      }
      
      debugPrint('🔒 Server error - DENY');
      return false;
      
    } catch (e) {
      // 🔒 OFFLINE = TOTAL LOCKDOWN
      debugPrint('🔒 Network error - DENY: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> verify(
    List<int> userResponse,
    List<FixedExtentScrollController> controllers,
  ) async {
    if (challengeCode.value.isEmpty || _currentNonce == null) {
      return {'allowed': false, 'error': 'Tiada cabaran aktif.'};
    }

    // Tamper check
    if (gestureAudit.isTampered(controllers)) {
      debugPrint('🚨 Tamper detected!');
      return {'allowed': false, 'error': 'Aktiviti mencurigakan.', 'reason': 'TAMPER_DETECTED'};
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/verify'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: json.encode({
          'nonce'       : _currentNonce,
          'userResponse': userResponse,
          'biometricData': {
            'motion' : motionScore.value,
            'touch'  : touchScore.value,
            'pattern': (patternScore.value + gestureAudit.scrollEntropy) / 2.0,
          },
          'deviceId': 'flutter_device_${apiKey.substring(8, 16)}',
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) return json.decode(response.body);

      return {'allowed': false, 'error': 'Server error ${response.statusCode}.'};
    } catch (e) {
      return {'allowed': false, 'error': 'Tiada sambungan. Cuba semula.'};
    }
  }

  void registerTouch() {
    final now = DateTime.now();
    if (_lastTouchTime != null) {
      final interval = now.difference(_lastTouchTime!).inMilliseconds;
      _touchIntervals.add(interval);
      if (_touchIntervals.length > 5) _touchIntervals.removeAt(0);

      if (_touchIntervals.length >= 3) {
        final avg      = _touchIntervals.reduce((a, b) => a + b) / _touchIntervals.length;
        final variance = _touchIntervals.map((i) => (i - avg).abs()).reduce((a, b) => a + b) / _touchIntervals.length;
        touchScore.value =
            ((variance / avg).clamp(0.0, 1.0) * 0.6 + ((avg > 200 && avg < 800) ? 1.0 : 0.3) * 0.4)
                .clamp(0.3, 1.0);
      } else {
        touchScore.value = 0.5;
      }
    }
    _lastTouchTime = now;
  }

  void registerScroll() {
    final now = DateTime.now();
    if (_lastScrollTime != null) {
      final timeDelta        = now.difference(_lastScrollTime!).inMilliseconds;
      final velocityEstimate = timeDelta > 0 ? (100.0 / timeDelta) : 0.0;
      _scrollVelocities.add(velocityEstimate.clamp(0.0, 10.0));
      if (_scrollVelocities.length > 5) _scrollVelocities.removeAt(0);

      if (_scrollVelocities.length >= 3) {
        final changes = <double>[];
        for (int i = 1; i < _scrollVelocities.length; i++) {
          changes.add((_scrollVelocities[i] - _scrollVelocities[i - 1]).abs());
        }
        patternScore.value =
            (1.0 - (changes.reduce((a, b) => a + b) / changes.length / 5.0)).clamp(0.3, 1.0);
      } else {
        patternScore.value = 0.5;
      }
    }
    _lastScrollTime = now;
  }

  void randomizeWheels() => randomizeTrigger.value++;

  void dispose() {
    _accelSub?.cancel();
    _decayTimer?.cancel();
    challengeCode.dispose();
    randomizeTrigger.dispose();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final success = await widget.controller.fetchChallenge();
    if (mounted) {
      setState(() {
        _loading = false;
        _networkError = !success; // 🔒 Track if network failed
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 OFFLINE = SHOW ERROR SCREEN ONLY
    if (_networkError) {
      return _buildNetworkErrorScreen();
    }

    // Normal UI (only if server connection successful)
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.only(top: 20, bottom: 12, left: 16, right: 16),
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
                    fontSize: 28, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 18),
                UltimateRGBGlitchDisplay(controller: widget.controller),
                const SizedBox(height: 12),
                const Text(
                  'Please match the code',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 18),
                UltimateCryptexLock(
                  controller: widget.controller,
                  onSuccess: (success) => widget.onComplete(success),
                  onFail: () => widget.onComplete(false),
                ),
                const SizedBox(height: 18),
                UltimateBiometricPanel(controller: widget.controller),
                const SizedBox(height: 12),
                if (widget.onCancel != null)
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔒 NETWORK ERROR SCREEN (offline = total lockdown)
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
              const Icon(
                Icons.cloud_off_rounded,
                size: 80,
                color: Colors.redAccent,
              ),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(
                    'Kembali',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RGB GLITCH DISPLAY — anti-OCR visual noise
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateRGBGlitchDisplay extends StatefulWidget {
  final WidgetController controller;
  const UltimateRGBGlitchDisplay({super.key, required this.controller});

  @override
  State<UltimateRGBGlitchDisplay> createState() => _UltimateRGBGlitchDisplayState();
}

class _UltimateRGBGlitchDisplayState extends State<UltimateRGBGlitchDisplay> {
  Timer? _glitchTimer;
  bool   _isGlitching = false;
  double _xOffset = 0.0, _yOffset = 0.0;
  final Random _random = Random();

  int _noiseSeed = DateTime.now().millisecondsSinceEpoch;
  Timer? _noiseTimer;

  @override
  void initState() {
    super.initState();
    _glitchTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        _isGlitching = _random.nextDouble() > 0.7;
        _xOffset     = _random.nextDouble() * 3 - 1.5;
        _yOffset     = _random.nextDouble() * 2 - 1.0;
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
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NoisePainter(seed: _noiseSeed),
                  ),
                ),
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

  TextStyle _glitchStyle(Color color) {
    return TextStyle(
      fontSize: 28, fontWeight: FontWeight.bold,
      fontFamily: 'Courier', letterSpacing: 8, color: color,
    );
  }
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
          text : rng.nextInt(10).toString(),
          style: TextStyle(
            fontSize   : 14 + rng.nextDouble() * 10,
            color      : Colors.white.withOpacity(rng.nextDouble() * 0.1 + 0.03),
            fontWeight : FontWeight.bold,
            fontFamily : 'Courier',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      ));
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
// BIOMETRIC PANEL
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateBiometricPanel extends StatelessWidget {
  final WidgetController controller;
  const UltimateBiometricPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
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
          _buildIndicator(icon: Icons.sensors,     label: 'MOTION',  notifier: controller.motionScore),
          _buildIndicator(icon: Icons.touch_app,   label: 'TOUCH',   notifier: controller.touchScore),
          _buildIndicator(icon: Icons.fingerprint, label: 'PATTERN', notifier: controller.patternScore),
        ],
      ),
    );
  }

  Widget _buildIndicator({
    required IconData icon,
    required String label,
    required ValueNotifier<double> notifier,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, value, _) {
        final isActive = value > 0.5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.greenAccent : Colors.white30),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 7,
                color: isActive ? Colors.greenAccent : Colors.white30,
                fontWeight: FontWeight.bold, letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CRYPTEX LOCK
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateCryptexLock extends StatefulWidget {
  final WidgetController controller;
  final Function(bool) onSuccess;
  final VoidCallback onFail;

  const UltimateCryptexLock({
    super.key,
    required this.controller,
    required this.onSuccess,
    required this.onFail,
  });

  @override
  State<UltimateCryptexLock> createState() => _UltimateCryptexLockState();
}

class _UltimateCryptexLockState extends State<UltimateCryptexLock>
    with TickerProviderStateMixin {
  static const double imageWidth   = ZKineticConfig.imageWidth3;
  static const double imageHeight  = ZKineticConfig.imageHeight3;
  static const List<List<double>> wheelCoords  = ZKineticConfig.coords3;
  static const List<double>       buttonCoords = ZKineticConfig.btnCoords3;

  late List<FixedExtentScrollController> _scrollControllers;
  final List<int> _prevItems = [0, 0, 0];

  int?   _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool   _isButtonPressed = false;
  final Random _random = Random();

  late List<AnimationController> _textOpacityControllers;
  late List<Animation<double>>   _textOpacityAnimations;
  final List<Offset> _textDriftOffsets = [Offset.zero, Offset.zero, Offset.zero];
  Timer? _driftTimer;

  @override
  void initState() {
    super.initState();
    _scrollControllers = List.generate(
      3, (i) => FixedExtentScrollController(initialItem: 0),
    );

    _textOpacityControllers = List.generate(
      3, (i) => AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this,
      )..repeat(reverse: true),
    );
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
    widget.controller.registerScroll();
    final current = _scrollControllers[index].selectedItem;
    if (current != _prevItems[index]) {
      widget.controller.gestureAudit.recordScroll(
        index, _prevItems[index], current, DateTime.now(),
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

    final currentCode = <int>[];
    for (var c in _scrollControllers) {
      final raw = c.selectedItem;
      currentCode.add((raw % 10 + 10) % 10);
    }

    final result = await widget.controller.verify(currentCode, _scrollControllers);
    widget.onSuccess(result['allowed'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth    = screenWidth - 80;
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
          for (int i = 0; i < 3; i++) _buildWheel(i, containerWidth, containerHeight),
          _buildGlowingButton(containerWidth, containerHeight),
        ],
      ),
    );
  }

  Widget _buildWheel(int index, double containerWidth, double containerHeight) {
    final coords      = wheelCoords[index];
    final wheelLeft   = (coords[0] / imageWidth)  * containerWidth;
    final wheelTop    = (coords[1] / imageHeight) * containerHeight;
    final wheelWidth  = ((coords[2] - coords[0]) / imageWidth)  * containerWidth;
    final wheelHeight = ((coords[3] - coords[1]) / imageHeight) * containerHeight;
    final isActive    = _activeWheelIndex == index;

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
            onSelectedItemChanged: (_) {
              HapticFeedback.selectionClick();
            },
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
                              fontSize: wheelHeight * 0.30,
                              fontWeight: FontWeight.w900,
                              color: isActive
                                  ? const Color(0xFFFF5722)
                                  : const Color(0xFF263238),
                              height: 1.0,
                              shadows: isActive
                                  ? [
                                      Shadow(
                                        color: const Color(0xFFFF5722).withOpacity(0.8),
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

  Widget _buildGlowingButton(double containerWidth, double containerHeight) {
    final btnLeft   = (buttonCoords[0] / imageWidth)  * containerWidth;
    final btnTop    = (buttonCoords[1] / imageHeight) * containerHeight;
    final btnWidth  = ((buttonCoords[2] - buttonCoords[0]) / imageWidth)  * containerWidth;
    final btnHeight = ((buttonCoords[3] - buttonCoords[1]) / imageHeight) * containerHeight;

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
