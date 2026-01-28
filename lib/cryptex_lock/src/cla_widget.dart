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
      backgroundColor: const Color(0xFFEEF2F5), // Light Gray Gradient Base
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
                    // EFEK LUBANG TERBENAM (INSET)
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
                    height: 140, // Tinggi FIX
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        // 🔥 LAYER A: GAMBAR RODA (BoxFit.cover)
                        Positioned.fill(
                          child: Image.asset(
                            'assets/z_wheel.png',
                            fit: BoxFit.cover, // UPDATED: Cover untuk fill gap
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

                        // 🔥 LAYER C: NOMBOR (PIXEL PERFECT & CLIPPED)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) => _buildPreciseWheel(index)),
                        ),
                      ],
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

  Widget _buildPreciseWheel(int index) {
    bool isActive = _activeWheelIndex == index;

    return Expanded(
      child: Container(
        // Margin 2-4px (Arahan Captain)
        margin: const EdgeInsets.symmetric(horizontal: 3), 
        
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFFFF5722).withOpacity(0.3) // Active Highlight
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20), // Match clipping
        ),
        
        // 🔥 CLIPPING: Prevent nombor keluar dari roda
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ListWheelScrollView.useDelegate(
            controller: _scrollControllers[index],
            
            // 🔥 TUNED PARAMETERS (Arahan Captain)
            itemExtent: 70,       // Naikkan ke 70 (Range 68-75)
            perspective: 0.007,   // Curve lebih ketara (Range 0.007-0.009)
            diameterRatio: 1.0,   // Lebih dalam/tight (Range 0.9-1.1)
            
            physics: const FixedExtentScrollPhysics(),
            overAndUnderCenterOpacity: 0.3, // Kurangkan opacity edge (Range 0.25-0.35)
            
            onSelectedItemChanged: (_) {
               HapticFeedback.selectionClick();
               setState(() => _activeWheelIndex = index);
            },
            
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, i) {
                return Align(
                  // 🔥 ALIGNMENT FIX: Shift naik atas sikit (-0.1)
                  alignment: const Alignment(0.0, -0.1), 
                  child: Text(
                    '${i % 10}',
                    style: TextStyle(
                      fontFamily: 'Roboto', 
                      fontSize: 52,         // Size 50-54
                      fontWeight: FontWeight.w900, 
                      color: Colors.white,
                      height: 1.0,          // Height 1.0 Exact
                      
                      // 🔥 EMBOSS SHADOWS (3 Layers)
                      shadows: [
                        // Deep Black (Bawah Kanan)
                        Shadow(
                          offset: const Offset(3, 4),
                          blurRadius: 6,
                          color: Colors.black.withOpacity(0.7),
                        ),
                        // Sharp White (Atas Kiri)
                        Shadow(
                          offset: const Offset(-2, -3),
                          blurRadius: 4,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        // Extra Depth (Bawah)
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 3,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
