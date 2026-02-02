import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class ZKineticLockScreen extends StatelessWidget {
  const ZKineticLockScreen({super.key});

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
              const Icon(
                Icons.security,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 12),
              
              const Text(
                'Z-KINETIC',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              
              const SizedBox(height: 30),
              
              CryptexLock(),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusItem(Icons.sensors, 'MOTION'),
                  _buildStatusItem(Icons.fingerprint, 'TOUCH'),
                  _buildStatusItem(Icons.timeline, 'PATTERN'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Colors.white70,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ============================================
// 🔥 CRYPTEX LOCK - NEON NUMBER GLOW
// ============================================

class CryptexLock extends StatefulWidget {
  const CryptexLock({super.key});

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
    List<int> currentCode = _scrollControllers
        .map((c) => c.selectedItem % 10)
        .toList();
    
    print('🔐 Code: ${currentCode.join()}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code: ${currentCode.join()}'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
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
              _buildInvisibleButton(availableWidth, calculatedHeight),
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
            
            // ✅ NEON GLOW PADA NOMBOR TENGAH
            return Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: wheelHeight * 0.30,
                  fontWeight: FontWeight.w900,
                  color: isActive 
                      ? const Color(0xFFFF5722)  // ✅ NEON ORANGE bila active
                      : Colors.transparent,      // ✅ Invisible bila tak active
                  shadows: isActive
                      ? [
                          // ✅ NEON GLOW EFFECT
                          Shadow(
                            color: const Color(0xFFFF5722).withOpacity(0.8),
                            blurRadius: 20,
                          ),
                          Shadow(
                            color: const Color(0xFFFF5722).withOpacity(0.5),
                            blurRadius: 40,
                          ),
                        ]
                      : [],
                ),
                child: Text('$displayNumber'),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvisibleButton(double screenWidth, double screenHeight) {
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
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
