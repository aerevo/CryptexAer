import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Import fail controller & model Captain
import 'cla_controller_v2.dart'; 
import 'cla_models.dart';

class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback onSuccess;
  final VoidCallback onFail;
  final VoidCallback onJammed;

  const CryptexLock({
    super.key,
    required this.controller,
    required this.onSuccess,
    required this.onFail,
    required this.onJammed,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> {
  late List<FixedExtentScrollController> _scrollControllers;
  int? _activeWheelIndex;

  // 🎨 PALETTE WARNA
  final Color _primaryOrange = const Color(0xFFFF5722);
  final Color _engravedShadowDark = Colors.black.withOpacity(0.9);
  final Color _engravedShadowLight = Colors.white.withOpacity(0.5);

  // 📐 IMAGE DIMENSIONS (LOCKED)
  static const double imageWidth = 626.0;
  static const double imageHeight = 471.0;
  static const double aspectRatio = imageWidth / imageHeight;

  // 🎯 PRECISE MEASUREMENTS (FROM IMAGE ANALYSIS)
  static const List<double> wheelCenterRatios = [
    0.1989,  // Slot 1
    0.3698,  // Slot 2
    0.5407,  // Slot 3
    0.7117,  // Slot 4
    0.8826,  // Slot 5
  ];
  
  static const double wheelWidthRatio = 0.1390;
  static const double wheelHeightRatio = 0.3057;
  static const double verticalOffsetRatio = -0.0648;

  @override
  void initState() {
    super.initState();
    _scrollControllers = List.generate(5, (_) => FixedExtentScrollController(initialItem: 0));
  }

  @override
  void dispose() {
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  List<int> get _currentCode {
    return _scrollControllers.map((c) => c.selectedItem % 10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ==========================
                // 1. HEADER
                // ==========================
                const Text(
                  "Z-KINETIC CORE",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5722),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 30),
                
                Text(
                  "SECURE ACCESS",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[800],
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "ENTER PASSCODE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 50),

                // ==========================
                // 2. CRYPTEX HOUSING
                // ==========================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _buildWheelStack(constraints);
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // ==========================
                // 3. BUTTON
                // ==========================
                Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryOrange.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      widget.controller.verify(_currentCode);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "CONFIRM ACCESS",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWheelStack(BoxConstraints constraints) {
    final containerWidth = constraints.maxWidth;
    final containerHeight = constraints.maxHeight;

    // Calculate actual wheel dimensions
    final wheelWidth = containerWidth * wheelWidthRatio;
    final wheelHeight = containerHeight * wheelHeightRatio;
    
    // Calculate vertical position (offset from center)
    final verticalOffset = containerHeight * verticalOffsetRatio;
    final topPosition = (containerHeight - wheelHeight) / 2 + verticalOffset;

    return Stack(
      children: [
        // 🔥 LAYER A: GAMBAR RODA (BACKGROUND)
        Positioned.fill(
          child: Image.asset(
            'assets/z_wheel.png',
            fit: BoxFit.cover,
          ),
        ),

        // 🔥 LAYER B: SHADOW KIRI KANAN (SUBTLE)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                ],
                stops: const [0.0, 0.20, 0.80, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),

        // 🔥 LAYER C: WHEELS (POSITIONED PRECISELY)
        ...List.generate(5, (index) {
          final centerX = containerWidth * wheelCenterRatios[index];
          
          return Positioned(
            left: centerX - (wheelWidth / 2),
            top: topPosition,
            width: wheelWidth,
            height: wheelHeight,
            child: _buildPreciseWheel(index),
          );
        }),
      ],
    );
  }

  Widget _buildPreciseWheel(int index) {
    bool isActive = _activeWheelIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: isActive 
            ? const Color(0xFFFF5722).withOpacity(0.15)
            : Colors.transparent,
      ),
      child: ListWheelScrollView.useDelegate(
        controller: _scrollControllers[index],
        
        // 🔥 PARAMETER FIZIKAL (CALIBRATED)
        itemExtent: 58,        // From analysis
        perspective: 0.005,    // Minimal 3D curve
        diameterRatio: 1.8,    // Flatter wheel
        
        physics: const FixedExtentScrollPhysics(),
        overAndUnderCenterOpacity: 0.25,
        
        onSelectedItemChanged: (_) {
           HapticFeedback.selectionClick();
           setState(() => _activeWheelIndex = index);
        },
        
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            return Container(
              alignment: Alignment.center,
              child: Text(
                '${i % 10}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 49,              // From analysis
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.95),
                  height: 1.0,
                  
                  shadows: [
                    Shadow(
                      offset: const Offset(1.5, 1.5),
                      blurRadius: 3,
                      color: _engravedShadowDark,
                    ),
                    Shadow(
                      offset: const Offset(-0.5, -0.5),
                      blurRadius: 1,
                      color: _engravedShadowLight,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
