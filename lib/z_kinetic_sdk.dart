import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC SDK v2.2 - HARDENED
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ✅ UI asal kekal 100% (tiada perubahan visual)
// ✅ GestureAudit: tamper detect (digit tukar tanpa scroll = block)
// ✅ Visual noise dalam RGB glitch display (anti-OCR)
// ✅ OFFLINE = DENY (buang local fallback berbahaya)
// ✅ REAL touch timing + scroll pattern tracking
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
// GESTURE AUDIT — detect bot yang set digit terus dalam memory
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class GestureAudit {
  final List<_ScrollEvent> _events = [];

  void recordScroll(int wheelIndex, int fromItem, int toItem, DateTime at) {
    _events.add(_ScrollEvent(wheelIndex, fromItem, toItem, at));
    if (_events.length > 50) _events.removeAt(0);
  }

  /// Jika digit bukan posisi awal tapi tiada scroll event — kemungkinan bot
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

  /// Entropy scroll — variance tinggi = lebih manusia
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

  // Gesture audit (tamper detect)
  final GestureAudit gestureAudit = GestureAudit();

  // Motion
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double   _lastMagnitude  = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer?   _decayTimer;

  // Touch timing
  DateTime?       _lastTouchTime;
  final List<int> _touchIntervals = [];

  // Scroll pattern
  final List<double> _scrollVelocities = [];
  DateTime?          _lastScrollTime;

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
          gestureAudit.clear(); // reset audit untuk challenge baru
          return true;
        }
      }
      return false;
    } catch (e) {
      // ✅ OFFLINE = DENY — tiada local fallback
      debugPrint('⚠️ Network error: $e');
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

    // ✅ TAMPER CHECK — block sebelum hantar ke server
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

      // ✅ Server error = DENY, bukan fallback
      return {'allowed': false, 'error': 'Server error ${response.statusCode}.'};
    } catch (e) {
      // ✅ Network gagal = DENY
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
// MAIN WIDGET — UI asal kekal sama
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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await widget.controller.fetchChallenge();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
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
                // ✅ RGB Glitch Display dengan visual noise
                UltimateRGBGlitchDisplay(controller: widget.controller),
                const SizedBox(height: 12),
                const Text(
                  'Please match the code',
                  style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else
                  ValueListenableBuilder<int>(
                    valueListenable: widget.controller.randomizeTrigger,
                    builder: (context, trigger, _) {
                      return UltimateCryptexLock(
                        key: ValueKey(trigger),
                        controller: widget.controller,
                        onSuccess: (isPanic) => widget.onComplete(true),
                        onFail: () => widget.onComplete(false),
                      );
                    },
                  ),
                const SizedBox(height: 10),
                UltimateBiometricPanel(controller: widget.controller),
                const SizedBox(height: 8),
                if (widget.onCancel != null)
                  TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
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
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RGB GLITCH DISPLAY + VISUAL NOISE (anti-OCR)
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
  double _xOffset   = 0;
  double _yOffset   = 0;
  bool   _isGlitching = false;
  int    _noiseSeed = 0; // berubah untuk noise dinamik
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();

    // Glitch effect (sama seperti asal)
    _glitchTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_rnd.nextDouble() > 0.3) {
        setState(() {
          _isGlitching = true;
          _xOffset = (_rnd.nextDouble() - 0.5) * 10;
          _yOffset = (_rnd.nextDouble() - 0.5) * 8;
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() => _isGlitching = false);
        });
      }
    });

    // ✅ Noise tick — ghost digits & lines berubah setiap 400ms
    _noiseTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _noiseSeed = _rnd.nextInt(99999));
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
      margin: const EdgeInsets.symmetric(horizontal: 15),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10)],
      ),
      child: ValueListenableBuilder<List<int>>(
        valueListenable: widget.controller.challengeCode,
        builder: (context, code, _) {
          if (code.isEmpty) {
            return const Center(
              child: Text('...', style: TextStyle(color: Colors.white, fontSize: 28)),
            );
          }
          final codeStr = code.join('');
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ✅ LAYER 1: Visual noise (anti-OCR) — CustomPaint di belakang
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NoisePainter(seed: _noiseSeed),
                  ),
                ),
                // Layer 2: RGB glitch (sama seperti asal)
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
                // Layer 3: Digit sebenar (foreground jelas)
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

// ✅ Noise painter — random lines + ghost digits, seed berubah setiap 400ms
class _NoisePainter extends CustomPainter {
  final int seed;
  _NoisePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = Random(seed);
    final paint = Paint()..strokeWidth = 0.8..style = PaintingStyle.stroke;

    // Random lines
    for (int i = 0; i < 8; i++) {
      paint.color = Colors.white.withOpacity(rng.nextDouble() * 0.12 + 0.03);
      canvas.drawLine(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        paint,
      );
    }

    // Ghost digits
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

    // Noise dots
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
// BIOMETRIC PANEL — sama seperti asal
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
// CRYPTEX LOCK — sama seperti asal + tamper detect
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
  // Track posisi sebelum untuk GestureAudit
  final List<int> _prevItems = [0, 0, 0];

  int?   _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool   _isButtonPressed = false;
  final Random _random = Random();
  late Timer _driftTimer;
  late List<Offset> _textDriftOffsets;
  late List<AnimationController> _opacityControllers;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();

    _scrollControllers = List.generate(
        3, (i) => FixedExtentScrollController(initialItem: _random.nextInt(10)));
    _textDriftOffsets = List.generate(3, (_) => Offset.zero);

    _driftTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && _activeWheelIndex == null) {
        setState(() {
          for (int i = 0; i < 3; i++) {
            _textDriftOffsets[i] = Offset(
              (_random.nextDouble() - 0.5) * 2.0,
              (_random.nextDouble() - 0.5) * 2.0,
            );
          }
        });
      }
    });

    _opacityControllers = List.generate(3, (i) {
      final c = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 1800 + _random.nextInt(400)));
      Future.delayed(Duration(milliseconds: _random.nextInt(1000)), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _opacityAnimations = _opacityControllers
        .map((c) => Tween<double>(begin: 0.75, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) => _playSlotMachineIntro());
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
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) HapticFeedback.heavyImpact();
        });
      });
    }
  }

  @override
  void dispose() {
    for (final c in _scrollControllers) c.dispose();
    for (final c in _opacityControllers) c.dispose();
    _wheelActiveTimer?.cancel();
    _driftTimer.cancel();
    super.dispose();
  }

  void _onWheelScrollStart(int index) {
    setState(() => _activeWheelIndex = index);
    _wheelActiveTimer?.cancel();
    HapticFeedback.selectionClick();
    widget.controller.registerTouch();
  }

  void _onWheelScrollEnd(int index) {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _activeWheelIndex = null);
    });
  }

  // ✅ Rekod scroll untuk GestureAudit
  void _onItemChanged(int index, int newItem) {
    widget.controller.gestureAudit.recordScroll(
      index, _prevItems[index], newItem, DateTime.now(),
    );
    _prevItems[index] = newItem;
  }

  Future<void> _onButtonTap() async {
    setState(() => _isButtonPressed = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _isButtonPressed = false);

    final currentCode = <int>[];
    for (final c in _scrollControllers) {
      currentCode.add((c.selectedItem % 10 + 10) % 10);
    }

    // ✅ Hantar controllers untuk tamper check
    final result = await widget.controller.verify(currentCode, _scrollControllers);

    if (result['allowed'] == true) {
      widget.onSuccess(false);
    } else {
      HapticFeedback.heavyImpact();
      // Reset audit dan fetch challenge baru
      widget.controller.gestureAudit.clear();
      await widget.controller.fetchChallenge();
      _playSlotMachineIntro();
      widget.onFail();
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
                  color: Colors.red,
                  child: const Icon(Icons.error, color: Colors.white, size: 60),
                ),
              ),
            ),
            ..._buildWheelOverlays(),
            _buildGlowingButton(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWheelOverlays() {
    return List.generate(wheelCoords.length, (i) {
      final coords = wheelCoords[i];
      return Positioned(
        left  : coords[0],
        top   : coords[1],
        width : coords[2] - coords[0],
        height: coords[3] - coords[1],
        child : NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification) {
              if (_scrollControllers[i].position == n.metrics) _onWheelScrollStart(i);
            } else if (n is ScrollUpdateNotification) {
              widget.controller.registerScroll();
            } else if (n is ScrollEndNotification) {
              _onWheelScrollEnd(i);
            }
            return false;
          },
          child: _buildWheel(i, coords[3] - coords[1]),
        ),
      );
    });
  }

  Widget _buildWheel(int index, double wheelHeight) {
    final isActive = _activeWheelIndex == index;
    return GestureDetector(
      onTapDown  : (_) => _onWheelScrollStart(index),
      onTapUp    : (_) => _onWheelScrollEnd(index),
      onTapCancel: ()  => _onWheelScrollEnd(index),
      behavior   : HitTestBehavior.opaque,
      child: ListWheelScrollView.useDelegate(
        controller : _scrollControllers[index],
        itemExtent : wheelHeight * 0.40,
        perspective: 0.001,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (newItem) {
          HapticFeedback.selectionClick();
          _onItemChanged(index, newItem); // ✅ rekod untuk tamper detect
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, idx) {
            final displayNumber = (idx % 10 + 10) % 10;
            return Center(
              child: AnimatedBuilder(
                animation: _opacityAnimations[index],
                builder: (context, child) {
                  return Transform.translate(
                    offset: isActive ? Offset.zero : _textDriftOffsets[index],
                    child: Opacity(
                      opacity: isActive ? 1.0 : _opacityAnimations[index].value,
                      child: Text(
                        '$displayNumber',
                        style: TextStyle(
                          fontSize  : wheelHeight * 0.30,
                          fontWeight: FontWeight.w900,
                          color: isActive ? const Color(0xFFFF5722) : const Color(0xFF263238),
                          height: 1.0,
                          shadows: isActive
                              ? [Shadow(color: const Color(0xFFFF5722).withOpacity(0.8), blurRadius: 20)]
                              : [
                                  Shadow(offset: const Offset(1, 1), blurRadius: 1, color: Colors.white.withOpacity(0.4)),
                                  Shadow(offset: const Offset(-1, -1), blurRadius: 1, color: Colors.black.withOpacity(0.6)),
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
    );
  }

  Widget _buildGlowingButton() {
    return Positioned(
      left  : buttonCoords[0],
      top   : buttonCoords[1],
      width : buttonCoords[2] - buttonCoords[0],
      height: buttonCoords[3] - buttonCoords[1],
      child : GestureDetector(
        onTap    : _onButtonTap,
        behavior : HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(color: Colors.transparent),
            if (_isButtonPressed)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5722).withOpacity(0.6),
                        blurRadius: 30, spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
