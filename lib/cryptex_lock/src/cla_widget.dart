import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================
// 🔥 Z-KINETIC CRYPTEX LOCK
// Interactive wheels with NEON ORANGE GLOW
// ============================================

class CryptexLock extends StatefulWidget {
  const CryptexLock({super.key});

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> {
  // Image dimensions
  static const double imageWidth = 706.0;
  static const double imageHeight = 610.0;

  // 5 Wheel coordinates [left, top, right, bottom]
  static const List<List<double>> wheelCoords = [
    [25, 159, 113, 378],   // Wheel 1
    [165, 160, 257, 379],  // Wheel 2
    [308, 160, 396, 379],  // Wheel 3
    [448, 159, 541, 378],  // Wheel 4
    [591, 159, 681, 379],  // Wheel 5
  ];

  // Button coordinates [left, top, right, bottom]
  static const List<double> buttonCoords = [123, 433, 594, 545];

  // Wheel controllers
  final List<FixedExtentScrollController> _scrollControllers = List.generate(
    5,
    (i) => FixedExtentScrollController(initialItem: 0),
  );

  // Active wheel tracking (for NEON GLOW effect)
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
    
    print('🔐 Code entered: ${currentCode.join()}');
    
    // TODO: Add verification logic here
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
              // Background image
              Positioned.fill(
                child: Image.asset(
                  'assets/z_wheel.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.red,
                      child: const Center(
                        child: Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ✅ 5 INTERACTIVE WHEELS with NEON GLOW
              ..._buildWheelOverlays(availableWidth, calculatedHeight),

              // ✅ INVISIBLE BUTTON (transparent but clickable)
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
      onTapDown: (_) {
        _onWheelScrollStart(index);
      },
      onTapUp: (_) => _onWheelScrollEnd(),
      onTapCancel: () => _onWheelScrollEnd(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Scrollable wheel (invisible numbers)
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
              builder: (context, i) {
                // Invisible placeholder
                return Container();
              },
            ),
          ),

          // ✅ NEON ORANGE GLOW OVERLAY
          if (isActive)
            IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF5722),
                    width: 3,
                  ),
                  boxShadow: [
                    // ✅ NEON GLOW EFFECT
                    BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.8),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
        ],
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
        child: Container(
          // ✅ FULLY TRANSPARENT - image button shows through
          color: Colors.transparent,
        ),
      ),
    );
  }
}
