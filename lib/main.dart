import 'dart:async';
import 'dart:math';
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

class _ZKineticLockScreenState extends State<ZKineticLockScreen> {
  late SmartController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SmartController(correctCode: [1, 2, 3, 4, 5]);
  }

  @override
  void dispose() {
    _controller.dispose();
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
      body: Center(
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
              // ✅ UPGRADED LOGO - Custom Shield
              _buildPremiumLogo(),
              
              const SizedBox(height: 16),
              
              // ✅ UPGRADED BRANDING - Premium Typography
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFEEDD),
                  ],
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
                onSuccess: _onSuccess,
                onFail: _onFail,
              ),
              
              const SizedBox(height: 24),
              
              // Sensor status indicators
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
    );
  }

  // ✅ PREMIUM LOGO dengan geometri custom
  Widget _buildPremiumLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFDDDD),
          ],
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
          // Shield outline
          Center(
            child: CustomPaint(
              size: const Size(32, 32),
              painter: ShieldPainter(),
            ),
          ),
          // Z letter overlay
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
    bool isActive = score > 0.15; // ✅ LOWERED from 0.3 for accessibility
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

// ✅ Custom Shield Painter
class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Shield shape
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.3);
    path.lineTo(w, h * 0.7);
    path.quadraticBezierTo(w * 0.5, h * 1.2, w * 0.5, h);
    path.quadraticBezierTo(w * 0.5, h * 1.2, 0, h * 0.7);
    path.lineTo(0, h * 0.3);
    path.close();

    canvas.drawPath(path, paint);

    // Inner detail
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
// 🔥 SMART CONTROLLER - FIXED SENSORS
// ============================================

class SmartController {
  final List<int> correctCode;
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);
  
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  
  // ✅ Motion tracking (detect CHANGE, not magnitude)
  double _lastMagnitude = 9.8; // Initialize to gravity
  DateTime _lastMotionTime = DateTime.now();
  Timer? _decayTimer;
  
  // ✅ Pattern tracking (scroll timing)
  final List<int> _scrollTimings = [];
  DateTime _lastScrollTime = DateTime.now();

  SmartController({required this.correctCode}) {
    _initSensors();
    _startDecayTimer();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // ✅ DETECT CHANGE (movement), not static gravity
      double delta = (magnitude - _lastMagnitude).abs();
      
      if (delta > 0.3) { // ✅ LOWERED from 0.5 for OKU/elderly
        DateTime now = DateTime.now();
        
        // Score based on movement intensity
        double score = (delta / 3.0).clamp(0.0, 1.0);
        motionScore.value = score;
        _lastMotionTime = now;
      }
      
      _lastMagnitude = magnitude;
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      // Additional motion data (optional enhancement)
    });
  }

  void _startDecayTimer() {
    _decayTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      DateTime now = DateTime.now();
      int timeSinceLastMotion = now.difference(_lastMotionTime).inMilliseconds;
      
      // ✅ SLOW DECAY - 0.05 per second (accessible for slow movers)
      if (timeSinceLastMotion > 500) {
        double decay = (timeSinceLastMotion / 1000.0) * 0.05;
        motionScore.value = (motionScore.value - decay).clamp(0.0, 1.0);
      }
    });
  }

  void registerTouch() {
    // ✅ Random touch score (simulates biometric variance)
    touchScore.value = Random().nextDouble() * 0.3 + 0.7;
  }

  void registerScroll() {
    DateTime now = DateTime.now();
    int delta = now.difference(_lastScrollTime).inMilliseconds;
    _scrollTimings.add(delta);
    _lastScrollTime = now;

    if (_scrollTimings.length > 10) _scrollTimings.removeAt(0);

    if (_scrollTimings.length >= 3) {
      // ✅ Calculate variance (human = irregular, bot = consistent)
      double avg = _scrollTimings.reduce((a, b) => a + b) / _scrollTimings.length;
      double variance = _scrollTimings
          .map((e) => pow(e - avg, 2))
          .reduce((a, b) => a + b) / _scrollTimings.length;
      
      // ✅ High variance = human-like
      double humanness = (variance / 10000).clamp(0.0, 1.0);
      patternScore.value = humanness;
    }
  }

  bool verify(List<int> code) {
    // ✅ MINIMUM THRESHOLDS (accessible)
    bool motionOK = motionScore.value > 0.15;  // Very low - even tremor passes
    bool touchOK = touchScore.value > 0.15;    // Very low - any interaction passes
    bool patternOK = patternScore.value > 0.10; // Very low - minimal scroll variance
    
    // ✅ CODE CHECK
    bool codeCorrect = true;
    if (code.length != correctCode.length) return false;
    
    for (int i = 0; i < code.length; i++) {
      if (code[i] != correctCode[i]) {
        codeCorrect = false;
        break;
      }
    }
    
    // ✅ REQUIRE: Code correct + at least 2/3 sensors OK
    int sensorsActive = [motionOK, touchOK, patternOK].where((x) => x).length;
    
    print('🔍 Motion: ${motionScore.value.toStringAsFixed(2)} (${motionOK ? "✅" : "❌"})');
    print('🔍 Touch: ${touchScore.value.toStringAsFixed(2)} (${touchOK ? "✅" : "❌"})');
    print('🔍 Pattern: ${patternScore.value.toStringAsFixed(2)} (${patternOK ? "✅" : "❌"})');
    print('🔍 Code: ${codeCorrect ? "✅" : "❌"}');
    print('🔍 Sensors: $sensorsActive/3');
    
    return codeCorrect && sensorsActive >= 2;
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
// 🔥 CRYPTEX LOCK
// ============================================

class CryptexLock extends StatefulWidget {
  final SmartController controller;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;

  const CryptexLock({
    super.key,
    required this.controller,
    this.onSuccess,
    this.onFail,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> {
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

  @override
  void dispose() {
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    _wheelActiveTimer?.cancel();
    super.dispose();
  }

  void _onWheelScrollStart(int index) {
    setState(() => _activeWheelIndex = index);
    _wheelActiveTimer?.cancel();
    HapticFeedback.selectionClick();
    widget.controller.registerTouch();
    widget.controller.registerScroll(); // ✅ Track pattern
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
    
    widget.controller.registerTouch();
    
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
                widget.controller.registerScroll(); // ✅ Track during scroll
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
          ListWheelScrollView.useDelegate(
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
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
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
                    child: Text('$displayNumber'),
                  ),
                );
              },
            ),
          ),

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
