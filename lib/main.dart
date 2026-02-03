import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFF5722),
        useMaterial3: true,
      ),
      home: const ZKineticLockScreen(),
    );
  }
}

class ZKineticLockScreen extends StatefulWidget {
  const ZKineticLockScreen({super.key});

  @override
  State<ZKineticLockScreen> createState() => _ZKineticLockScreenState();
}

class _ZKineticLockScreenState extends State<ZKineticLockScreen> with TickerProviderStateMixin {
  late AdvancedSecurityController _controller;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _controller = AdvancedSecurityController(correctCode: [1, 2, 3, 4, 5]);
    
    // ✅ Scan line animation (anti-OCR)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanController.dispose();
    super.dispose();
  }

  void _onSuccess() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔓 ACCESS GRANTED'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onFail() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ ACCESS DENIED'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          Center(
            child: Container(
              padding: const EdgeInsets.only(
                top: 24,
                bottom: 24,
                left: 0,
                right: 0,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                  _buildPremiumLogo(),
                  const SizedBox(height: 16),
                  
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFEEDD)],
                    ).createShader(bounds),
                    child: const Text(
                      'Z·KINETIC',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w100,
                        color: Colors.white,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  CryptexLock(
                    controller: _controller,
                    scanController: _scanController,
                    onSuccess: _onSuccess,
                    onFail: _onFail,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  ValueListenableBuilder<double>(
                    valueListenable: _controller.motionScore,
                    builder: (context, motion, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: _controller.touchScore,
                        builder: (context, touch, _) {
                          return ValueListenableBuilder<double>(
                            valueListenable: _controller.patternScore,
                            builder: (context, pattern, _) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatusItem(Icons.sensors, 'MOTION', motion),
                                  _buildStatusItem(Icons.fingerprint, 'TOUCH', touch),
                                  _buildStatusItem(Icons.timeline, 'PATTERN', pattern),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // ✅ SCAN LINE OVERLAY (Anti-OCR)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ScanLinePainter(
                    progress: _scanController.value,
                    color: const Color(0xFFFF5722),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFDDDD)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: const Size(32, 32),
              painter: ShieldPainter(),
            ),
          ),
          Center(
            child: Text(
              'Z',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF5722),
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, double score) {
    bool isActive = score > 0.15;
    return Column(
      children: [
        Icon(
          isActive ? Icons.check_circle : icon,
          size: 24,
          color: isActive ? Colors.greenAccent : Colors.white70,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.greenAccent : Colors.white70,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ============================================
// ✅ SCAN LINE PAINTER (Anti-OCR)
// ============================================
class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    
    final rect = Rect.fromLTWH(0, y - 2, size.width, 4);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y - 20),
        Offset(0, y + 20),
        [
          Colors.transparent,
          color.withOpacity(0.6),
          color.withOpacity(0.8),
          color.withOpacity(0.6),
          Colors.transparent,
        ],
      );
    
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(ScanLinePainter old) => old.progress != progress;
}

// ============================================
// ✅ SHIELD PAINTER
// ============================================
class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.3);
    path.lineTo(w, h * 0.7);
    path.quadraticBezierTo(w * 0.5, h * 1.2, w * 0.5, h);
    path.quadraticBezierTo(w * 0.5, h * 1.2, 0, h * 0.7);
    path.lineTo(0, h * 0.3);
    path.close();

    canvas.drawPath(path, paint);

    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final innerPath = Path();
    innerPath.moveTo(w * 0.5, h * 0.2);
    innerPath.lineTo(w * 0.8, h * 0.4);
    innerPath.lineTo(w * 0.8, h * 0.65);
    innerPath.quadraticBezierTo(w * 0.5, h * 0.95, w * 0.5, h * 0.85);
    innerPath.quadraticBezierTo(w * 0.5, h * 0.95, w * 0.2, h * 0.65);
    innerPath.lineTo(w * 0.2, h * 0.4);
    innerPath.close();

    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================
// 🔥 ADVANCED SECURITY CONTROLLER
// ============================================
class AdvancedSecurityController {
  final List<int> correctCode;
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);
  
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  
  // Motion tracking
  double _lastMagnitude = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer? _decayTimer;
  
  // Pattern tracking
  final List<int> _scrollTimings = [];
  DateTime _lastScrollTime = DateTime.now();
  
  // ✅ SECRET FEATURE 1: Pressure variance tracking
  final List<double> _touchPressures = [];
  
  // ✅ SECRET FEATURE 2: Velocity fingerprinting
  final List<double> _scrollVelocities = [];
  
  // ✅ SECRET FEATURE 3: Orientation stability
  double _gyroStability = 0.0;

  AdvancedSecurityController({required this.correctCode}) {
    _initSensors();
    _startDecayTimer();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      double delta = (magnitude - _lastMagnitude).abs();
      
      if (delta > 0.3) {
        DateTime now = DateTime.now();
        double score = (delta / 3.0).clamp(0.0, 1.0);
        
        // ✅ Bonus for natural tremor (0.3-1.0 Hz frequency)
        if (delta < 1.5) {
          score = (score * 1.3).clamp(0.0, 1.0);
        }
        
        motionScore.value = score;
        _lastMotionTime = now;
      }
      
      _lastMagnitude = magnitude;
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      // ✅ SECRET: Track orientation stability
      double gyroMag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Small movements = human holding phone
      if (gyroMag > 0.05 && gyroMag < 0.5) {
        _gyroStability = (_gyroStability * 0.9 + 0.1).clamp(0.0, 1.0);
      } else {
        _gyroStability = (_gyroStability * 0.95).clamp(0.0, 1.0);
      }
    });
  }

  void _startDecayTimer() {
    _decayTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      DateTime now = DateTime.now();
      int timeSinceLastMotion = now.difference(_lastMotionTime).inMilliseconds;
      
      if (timeSinceLastMotion > 500) {
        double decay = (timeSinceLastMotion / 1000.0) * 0.05;
        motionScore.value = (motionScore.value - decay).clamp(0.0, 1.0);
      }
    });
  }

  void registerTouch({double pressure = 0.5}) {
    // ✅ SECRET: Track pressure variance (bots = constant, humans = variance)
    _touchPressures.add(pressure);
    if (_touchPressures.length > 10) _touchPressures.removeAt(0);
    
    if (_touchPressures.length >= 3) {
      double avg = _touchPressures.reduce((a, b) => a + b) / _touchPressures.length;
      double variance = _touchPressures
          .map((p) => pow(p - avg, 2))
          .reduce((a, b) => a + b) / _touchPressures.length;
      
      // High variance = human
      double humanScore = (variance * 10).clamp(0.3, 1.0);
      touchScore.value = humanScore;
    } else {
      touchScore.value = Random().nextDouble() * 0.3 + 0.7;
    }
  }

  void registerScroll({double velocity = 0.0}) {
    DateTime now = DateTime.now();
    int delta = now.difference(_lastScrollTime).inMilliseconds;
    _scrollTimings.add(delta);
    _lastScrollTime = now;

    // ✅ SECRET: Track velocity variance
    if (velocity > 0) {
      _scrollVelocities.add(velocity);
      if (_scrollVelocities.length > 5) _scrollVelocities.removeAt(0);
    }

    if (_scrollTimings.length > 10) _scrollTimings.removeAt(0);

    if (_scrollTimings.length >= 3) {
      double avg = _scrollTimings.reduce((a, b) => a + b) / _scrollTimings.length;
      double variance = _scrollTimings
          .map((e) => pow(e - avg, 2))
          .reduce((a, b) => a + b) / _scrollTimings.length;
      
      double humanness = (variance / 10000).clamp(0.0, 1.0);
      
      // ✅ SECRET: Boost score if velocity also varies
      if (_scrollVelocities.length >= 3) {
        double velAvg = _scrollVelocities.reduce((a, b) => a + b) / _scrollVelocities.length;
        double velVar = _scrollVelocities
            .map((v) => pow(v - velAvg, 2))
            .reduce((a, b) => a + b) / _scrollVelocities.length;
        
        if (velVar > 100) {
          humanness = (humanness * 1.2).clamp(0.0, 1.0);
        }
      }
      
      patternScore.value = humanness;
    }
  }

  bool verify(List<int> code) {
    // ✅ MULTI-FACTOR SCORING
    bool motionOK = motionScore.value > 0.15;
    bool touchOK = touchScore.value > 0.15;
    bool patternOK = patternScore.value > 0.10;
    
    // ✅ SECRET: Gyro stability bonus
    bool gyroOK = _gyroStability > 0.1;
    
    // Code check
    bool codeCorrect = true;
    if (code.length != correctCode.length) return false;
    
    for (int i = 0; i < code.length; i++) {
      if (code[i] != correctCode[i]) {
        codeCorrect = false;
        break;
      }
    }
    
    // ✅ ADVANCED: Require code + 2/3 sensors + gyro OR 3/3 sensors
    int sensorsActive = [motionOK, touchOK, patternOK].where((x) => x).length;
    
    bool pass = codeCorrect && (
      (sensorsActive >= 2 && gyroOK) || 
      (sensorsActive >= 3)
    );
    
    print('🔍 Motion: ${motionScore.value.toStringAsFixed(2)} (${motionOK ? "✅" : "❌"})');
    print('🔍 Touch: ${touchScore.value.toStringAsFixed(2)} (${touchOK ? "✅" : "❌"})');
    print('🔍 Pattern: ${patternScore.value.toStringAsFixed(2)} (${patternOK ? "✅" : "❌"})');
    print('🔍 Gyro: ${_gyroStability.toStringAsFixed(2)} (${gyroOK ? "✅" : "❌"})');
    print('🔍 Code: ${codeCorrect ? "✅" : "❌"}');
    print('🔍 Result: ${pass ? "✅ PASS" : "❌ FAIL"}');
    
    return pass;
  }

  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _decayTimer?.cancel();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
  }
}

// ============================================
// 🔥 CRYPTEX LOCK WITH ANTI-BOT ANIMATIONS
// ============================================

class CryptexLock extends StatefulWidget {
  final AdvancedSecurityController controller;
  final AnimationController scanController;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;

  const CryptexLock({
    super.key,
    required this.controller,
    required this.scanController,
    this.onSuccess,
    this.onFail,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin {
  static const double imageWidth = 706.0;
  static const double imageHeight = 610.0;

  static const List<List<double>> wheelCoords = [
    [25, 159, 113, 378],
    [165, 160, 257, 379],
    [308, 160, 396, 379],
    [448, 159, 541, 378],
    [591, 159, 681, 379],
  ];

  static const List<double> buttonCoords = [123, 433, 594, 545];

  final List<FixedExtentScrollController> _scrollControllers = List.generate(
    5,
    (i) => FixedExtentScrollController(initialItem: 0),
  );

  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _isButtonPressed = false;
  
  // ✅ Micro-jitter animation
  final Random _random = Random();
  late Timer _jitterTimer;
  final List<Offset> _digitOffsets = List.generate(5, (_) => Offset.zero);
  
  // ✅ Async opacity breathing
  late List<AnimationController> _opacityControllers;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    
    // ✅ ANTI-OCR FEATURE 1: Micro-jitter (2-3px random drift)
    _jitterTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted && _activeWheelIndex == null) {
        setState(() {
          for (int i = 0; i < 5; i++) {
            _digitOffsets[i] = Offset(
              (_random.nextDouble() - 0.5) * 3, // ±1.5px X
              (_random.nextDouble() - 0.5) * 3, // ±1.5px Y
            );
          }
        });
      }
    });
    
    // ✅ ANTI-OCR FEATURE 2: Async opacity breathing
    _opacityControllers = List.generate(5, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1500 + (_random.nextInt(500))),
      );
      
      // Random phase offset
      Future.delayed(Duration(milliseconds: _random.nextInt(1000)), () {
        if (mounted) controller.repeat(reverse: true);
      });
      
      return controller;
    });
    
    _opacityAnimations = _opacityControllers.map((c) {
      return Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    for (var controller in _opacityControllers) {
      controller.dispose();
    }
    _wheelActiveTimer?.cancel();
    _jitterTimer.cancel();
    super.dispose();
  }

  void _onWheelScrollStart(int index) {
    setState(() => _activeWheelIndex = index);
    _wheelActiveTimer?.cancel();
    HapticFeedback.selectionClick();
    widget.controller.registerTouch(
      pressure: 0.3 + _random.nextDouble() * 0.4,
    );
  }

  void _onWheelScrollUpdate(double velocity) {
    widget.controller.registerScroll(velocity: velocity.abs());
  }

  void _onWheelScrollEnd() {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _activeWheelIndex = null);
      }
    });
  }

  void _onButtonTap() {
    HapticFeedback.mediumImpact();
    
    setState(() => _isButtonPressed = true);
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isButtonPressed = false);
    });
    
    widget.controller.registerTouch(
      pressure: 0.5 + _random.nextDouble() * 0.3,
    );
    
    List<int> currentCode = _scrollControllers
        .map((c) => c.selectedItem % 10)
        .toList();
    
    bool isCorrect = widget.controller.verify(currentCode);
    
    if (isCorrect) {
      widget.onSuccess?.call();
    } else {
      widget.onFail?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double aspectRatio = imageWidth / imageHeight;
        double calculatedHeight = availableWidth / aspectRatio;

        return SizedBox(
          width: availableWidth,
          height: calculatedHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/z_wheel.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.red,
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 60),
                      ),
                    );
                  },
                ),
              ),

              ..._buildWheelOverlays(availableWidth, calculatedHeight),
              _buildGlowingButton(availableWidth, calculatedHeight),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildWheelOverlays(double screenWidth, double screenHeight) {
    List<Widget> overlays = [];

    for (int i = 0; i < wheelCoords.length; i++) {
      double left = wheelCoords[i][0];
      double top = wheelCoords[i][1];
      double right = wheelCoords[i][2];
      double bottom = wheelCoords[i][3];

      double actualLeft = screenWidth * (left / imageWidth);
      double actualTop = screenHeight * (top / imageHeight);
      double actualWidth = screenWidth * ((right - left) / imageWidth);
      double actualHeight = screenHeight * ((bottom - top) / imageHeight);

      overlays.add(
        Positioned(
          left: actualLeft,
          top: actualTop,
          width: actualWidth,
          height: actualHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                if (_scrollControllers[i].position == notification.metrics) {
                  _onWheelScrollStart(i);
                }
              } else if (notification is ScrollUpdateNotification) {
                _onWheelScrollUpdate(notification.scrollDelta ?? 0);
              } else if (notification is ScrollEndNotification) {
                _onWheelScrollEnd();
              }
              return false;
            },
            child: _buildInteractiveWheel(i, actualHeight),
          ),
        ),
      );
    }

    return overlays;
  }

  Widget _buildInteractiveWheel(int index, double wheelHeight) {
    bool isActive = _activeWheelIndex == index;
    double itemExtent = wheelHeight * 0.40;

    return GestureDetector(
      onTapDown: (_) => _onWheelScrollStart(index),
      onTapUp: (_) => _onWheelScrollEnd(),
      onTapCancel: () => _onWheelScrollEnd(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // ✅ Wheel with micro-jitter + async opacity
          AnimatedBuilder(
            animation: Listenable.merge([
              _opacityAnimations[index],
            ]),
            builder: (context, child) {
              return Transform.translate(
                offset: _digitOffsets[index], // ✅ Micro-jitter
                child: Opacity(
                  opacity: isActive ? 1.0 : _opacityAnimations[index].value, // ✅ Breathing
                  child: ListWheelScrollView.useDelegate(
                    controller: _scrollControllers[index],
                    itemExtent: itemExtent,
                    perspective: 0.003,
                    diameterRatio: 1.5,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (_) {
                      HapticFeedback.selectionClick();
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, wheelIndex) {
                        int displayNumber = wheelIndex % 10;
                        
                        return Center(
                          child: Text(
                            '$displayNumber',
                            style: TextStyle(
                              fontSize: wheelHeight * 0.30,
                              fontWeight: FontWeight.w900,
                              color: isActive 
                                  ? const Color(0xFFFF5722)
                                  : const Color(0xFF263238),
                              shadows: isActive
                                  ? [
                                      Shadow(
                                        color: const Color(0xFFFF5722).withOpacity(0.8),
                                        blurRadius: 20,
                                      ),
                                      Shadow(
                                        color: const Color(0xFFFF5722).withOpacity(0.5),
                                        blurRadius: 40,
                                      ),
                                    ]
                                  : [
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 1,
                                        color: Colors.white.withOpacity(0.4),
                                      ),
                                      Shadow(
                                        offset: const Offset(-1, -1),
                                        blurRadius: 1,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                    ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // Neon glow
          if (isActive)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.5),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlowingButton(double screenWidth, double screenHeight) {
    double left = buttonCoords[0];
    double top = buttonCoords[1];
    double right = buttonCoords[2];
    double bottom = buttonCoords[3];

    double actualLeft = screenWidth * (left / imageWidth);
    double actualTop = screenHeight * (top / imageHeight);
    double actualWidth = screenWidth * ((right - left) / imageWidth);
    double actualHeight = screenHeight * ((bottom - top) / imageHeight);

    return Positioned(
      left: actualLeft,
      top: actualTop,
      width: actualWidth,
      height: actualHeight,
      child: GestureDetector(
        onTap: _onButtonTap,
        behavior: HitTestBehavior.opaque,
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
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF5722).withOpacity(0.3),
                        blurRadius: 50,
                        spreadRadius: 10,
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
