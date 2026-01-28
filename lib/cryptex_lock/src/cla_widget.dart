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

  // 🎨 PALETTE WARNA (FIXED)
  final Color _primaryOrange = const Color(0xFFFF5722);
  final Color _engravedShadowDark = Colors.black.withOpacity(0.9);
  final Color _engravedShadowLight = Colors.white.withOpacity(0.5);

  // 📐 IMAGE DIMENSIONS
  static const double imageWidth = 626.0;
  static const double imageHeight = 471.0;
  static const double aspectRatio = imageWidth / imageHeight;

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
      backgroundColor: const Color(0xFFEEF2F5),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ==========================
                // 1. HEADER (BOLD DARK)
                // ==========================
                Text(
                  "SECURE ACCESS",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey[900],
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "ENTER PASSCODE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[400],
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 50),

                // ==========================
                // 2. CRYPTEX HOUSING (RECESSED SLOT)
                // ==========================
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F5),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(5, 5),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: Colors.white,
                        offset: const Offset(-5, -5),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.black, width: 2),
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
                // 3. BUTTON (ORANGE GLOW)
                // ==========================
                Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryOrange.withOpacity(0.4),
                        blurRadius: 20,
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

    // 📐 Calculate scaling factor
    final scale = containerWidth / imageWidth;
    
    // 🎯 POSITIONS - Adjust these based on your actual wheel centers in the image
    // Format: [x_center_in_original_image] * scale
    // Contoh positioning untuk 5 roda yang tersebar merata (adjust based on actual image)
    final wheelPositions = [
      containerWidth * 0.11,  // Wheel 1 - ~11% dari kiri
      containerWidth * 0.28,  // Wheel 2 - ~28% dari kiri
      containerWidth * 0.50,  // Wheel 3 - tengah (50%)
      containerWidth * 0.72,  // Wheel 4 - ~72% dari kiri
      containerWidth * 0.89,  // Wheel 5 - ~89% dari kiri
    ];

    // 🎯 Wheel dimensions
    final wheelWidth = containerWidth * 0.15;  // Setiap roda ~15% dari total width
    final wheelHeight = containerHeight * 0.85; // ~85% dari height untuk capture roda

    return Stack(
      children: [
        // 🔥 LAYER A: GAMBAR RODA (BACKGROUND)
        Positioned.fill(
          child: Image.asset(
            'assets/z_wheel.png',
            fit: BoxFit.cover,
          ),
        ),

        // 🔥 LAYER B: SHADOW KIRI KANAN (DEPTH)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.15, 0.85, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),

        // 🔥 LAYER C: WHEELS (POSITIONED PRECISELY)
        ...List.generate(5, (index) {
          return Positioned(
            left: wheelPositions[index] - (wheelWidth / 2),
            top: (containerHeight - wheelHeight) / 2,
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
            ? const Color(0xFFFF5722).withOpacity(0.2)
            : Colors.transparent,
      ),
      child: ListWheelScrollView.useDelegate(
        controller: _scrollControllers[index],
        
        // 🔥 PARAMETER FIZIKAL (TUNED)
        itemExtent: 50,
        perspective: 0.006,
        diameterRatio: 1.2,
        
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
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                  
                  shadows: [
                    Shadow(
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                      color: _engravedShadowDark,
                    ),
                    Shadow(
                      offset: const Offset(-1, -1),
                      blurRadius: 2,
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
