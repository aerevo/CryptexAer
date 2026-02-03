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
              _buildPremiumLogo(),
              
              const SizedBox(height: 16),
              
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

class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.1);
    path.lineTo(size.width * 0.85, size.height * 0.3);
    path.lineTo(size.width * 0.85, size.height * 0.6);
    path.lineTo(size.width * 0.5, size.height * 0.9);
    path.lineTo(size.width * 0.15, size.height * 0.6);
    path.lineTo(size.width * 0.15, size.height * 0.3);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 🔥 SMART CONTROLLER - Brain of Anti-Bot System
// ============================================================================
class SmartController {
  final List<int> correctCode;
  
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);
  
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  
  int _touchCount = 0;
  int _scrollCount = 0;
  DateTime? _lastTouch;
  DateTime? _lastScroll;
  Timer? _decayTimer;
  
  final Random _random = Random();

  SmartController({required this.correctCode}) {
    _initSensors();
    _startDecayTimer();
  }

  void _initSensors() {
    _accelSubscription = accelerometerEvents.listen((event) {
      double magnitude = sqrt(
        event.x * event.x + 
        event.y * event.y + 
        event.z * event.z
      );
      
      if (magnitude > 1.5) {
        motionScore.value = min(1.0, motionScore.value + 0.15);
      }
    });
  }

  void _startDecayTimer() {
    _decayTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      motionScore.value = max(0.0, motionScore.value - 0.1);
      touchScore.value = max(0.0, touchScore.value - 0.1);
      patternScore.value = max(0.0, patternScore.value - 0.1);
    });
  }

  void registerTouch() {
    _touchCount++;
    DateTime now = DateTime.now();
    
    if (_lastTouch != null) {
      int gap = now.difference(_lastTouch!).inMilliseconds;
      if (gap > 100 && gap < 2000) {
        touchScore.value = min(1.0, touchScore.value + 0.2);
      }
    }
    
    _lastTouch = now;
  }

  void registerScroll() {
    _scrollCount++;
    DateTime now = DateTime.now();
    
    if (_lastScroll != null) {
      int gap = now.difference(_lastScroll!).inMilliseconds;
      if (gap > 50 && gap < 1000) {
        patternScore.value = min(1.0, patternScore.value + 0.15);
      }
    }
    
    _lastScroll = now;
  }

  bool verify(List<int> userCode) {
    if (userCode.length != correctCode.length) return false;
    
    double humanScore = (
      motionScore.value * 0.3 +
      touchScore.value * 0.4 +
      patternScore.value * 0.3
    );
    
    bool codeMatch = true;
    for (int i = 0; i < userCode.length; i++) {
      if (userCode[i] != correctCode[i]) {
        codeMatch = false;
        break;
      }
    }
    
    if (!codeMatch) return false;
    
    if (humanScore < 0.3) {
      return _random.nextDouble() > 0.7;
    }
    
    return true;
  }

  void dispose() {
    _accelSubscription?.cancel();
    _decayTimer?.cancel();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
  }
}

// ============================================================================
// 🔥 CRYPTEX LOCK - Main Widget with FULL Anti-OCR Arsenal
// ============================================================================
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

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin {
  static const double imageWidth = 1080.0;
  static const double imageHeight = 1263.0;
  
  static const List<List<double>> wheelCoords = [
    [120, 480, 270, 750],
    [300, 480, 450, 750],
    [480, 480, 630, 750],
    [660, 480, 810, 750],
    [840, 480, 990, 750],
  ];
  
  static const List<double> buttonCoords = [425, 890, 655, 1020];

  late List<FixedExtentScrollController> _scrollControllers;
  
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _isButtonPressed = false;

  // 🆕 UPGRADE 1: Micro-drift controllers
  late List<AnimationController> _driftControllers;
  late List<Animation<double>> _driftAnimations;
  
  // 🆕 UPGRADE 2: Opacity breathing controller
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  
  // 🆕 UPGRADE 3: Async settle delays
  final List<int> _wheelSettleDelays = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    
    // Original scroll controllers
    _scrollControllers = List.generate(
      5,
      (index) => FixedExtentScrollController(initialItem: 0),
    );

    // 🆕 UPGRADE 1: Micro-drift per wheel
    _driftControllers = List.generate(
      5,
      (index) => AnimationController(
        duration: Duration(milliseconds: 1500 + _random.nextInt(1000)),
        vsync: this,
      )..repeat(reverse: true),
    );
    
    _driftAnimations = _driftControllers.map((controller) {
      return Tween<double>(
        begin: -0.8, // Subtle pixel drift
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
    }).toList();

    // 🆕 UPGRADE 2: Opacity breathing (global)
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
    
    _breathingAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    // 🆕 UPGRADE 3: Random settle delays for each wheel
    for (int i = 0; i < 5; i++) {
      _wheelSettleDelays.add(50 + _random.nextInt(150)); // 50-200ms variance
    }
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    _wheelActiveTimer?.cancel();
    
    // Clean up new controllers
    for (var controller in _driftControllers) {
      controller.dispose();
    }
    _breathingController.dispose();
    
    super.dispose();
  }

  void _onWheelScrollStart(int index) {
    setState(() => _activeWheelIndex = index);
    _wheelActiveTimer?.cancel();
    
    widget.controller.registerTouch();
    widget.controller.registerScroll();
  }

  void _onWheelScrollEnd(int wheelIndex) {
    _wheelActiveTimer?.cancel();
    
    // 🆕 UPGRADE 3: Async settle with random delay per wheel
    _wheelActiveTimer = Timer(
      Duration(milliseconds: 500 + _wheelSettleDelays[wheelIndex]),
      () {
        if (mounted) {
          setState(() => _activeWheelIndex = null);
        }
      },
    );
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
                widget.controller.registerScroll();
              } else if (notification is ScrollEndNotification) {
                // Pass wheel index for async settle
                _onWheelScrollEnd(i);
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
      onTapUp: (_) => _onWheelScrollEnd(index),
      onTapCancel: () => _onWheelScrollEnd(index),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 🆕 UPGRADE 1: Wrap wheel with drift animation
          AnimatedBuilder(
            animation: _driftAnimations[index],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, isActive ? 0 : _driftAnimations[index].value),
                child: child,
              );
            },
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
                    // 🆕 UPGRADE 2: Apply opacity breathing
                    child: AnimatedBuilder(
                      animation: _breathingAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: isActive ? 1.0 : _breathingAnimation.value,
                          child: child,
                        );
                      },
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
                    ),
                  );
                },
              ),
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
