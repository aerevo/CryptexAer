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
      backgroundColor: const Color(0xFF1A1A1A), // Match screenshot background
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
                // 3. BUTTON (ORANGE GLOW)
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

    // 🎯 PRECISE WHEEL POSITIONS (adjusted based on screenshot)
    // Dari gambar original 626px width, rough estimate position roda:
    final wheelPositions = [
      containerWidth * 0.115,  // Wheel 1 - kiri sekali
      containerWidth * 0.295,  // Wheel 2
      containerWidth * 0.500,  // Wheel 3 - tengah
      containerWidth * 0.705,  // Wheel 4
      containerWidth * 0.885,  // Wheel 5 - kanan sekali
    ];

    // 🎯 Wheel dimensions - make it narrower to see the wheel behind
    final wheelWidth = containerWidth * 0.12;  // Smaller untuk nampak roda
    final wheelHeight = containerHeight * 0.75; // Shorter vertical

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
          return Positioned(
            left: wheelPositions[index] - (wheelWidth / 2),
            top: (containerHeight - wheelHeight) / 2 + containerHeight * 0.02, // Turun sikit
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
        
        // 🔥 PARAMETER FIZIKAL (TUNED)
        itemExtent: 45,        // Smaller item height
        perspective: 0.005,    // Less 3D curve
        diameterRatio: 1.5,    // Flatter
        
        physics: const FixedExtentScrollPhysics(),
        overAndUnderCenterOpacity: 0.20,
        
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
                  fontSize: 32,              // SMALLER font
                  fontWeight: FontWeight.w700, // Less bold
                  color: Colors.white.withOpacity(0.95), // Slight transparency
                  height: 1.0,
                  letterSpacing: 0,
                  
                  shadows: [
                    // Softer shadow untuk nampak roda belakang
                    Shadow(
                      offset: const Offset(1.5, 1.5),
                      blurRadius: 3,
                      color: Colors.black.withOpacity(0.7),
                    ),
                    Shadow(
                      offset: const Offset(-0.5, -0.5),
                      blurRadius: 1,
                      color: Colors.white.withOpacity(0.3),
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
