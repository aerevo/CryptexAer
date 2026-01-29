import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import controller kalau ada
// import 'cla_controller_v2.dart'; 

class CryptexLock extends StatefulWidget {
  final dynamic controller;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;
  final VoidCallback? onJammed;

  const CryptexLock({
    super.key,
    this.controller,
    this.onSuccess,
    this.onFail,
    this.onJammed,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> {
  // Controller untuk 5 roda
  late List<FixedExtentScrollController> _scrollControllers;
  int? _activeWheelIndex;

  // Warna Emas/Oren Captain
  final Color _primaryOrange = const Color(0xFFFF5722);

  // 🔥 KOORDINAT SEBENAR DARI IMAGE MAP (626 x 471)
  // Format: [left, top, right, bottom]
  static const List<List<double>> _wheelCoords = [
    [85, 133, 143, 286],   // Roda 1
    [180, 132, 242, 285],  // Roda 2
    [276, 133, 337, 282],  // Roda 3
    [371, 132, 431, 282],  // Roda 4
    [467, 130, 529, 285],  // Roda 5
  ];

  static const double _imageWidth = 626.0;
  static const double _imageHeight = 471.0;

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
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // HEADER
              Text(
                "SECURE ACCESS",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueGrey[200],
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 60),

              // ==================================================
              // 🔥 Z-WHEEL SYSTEM (PIXEL PERFECT v2.0) 🔥
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double screenWidth = constraints.maxWidth;
                    
                    // 🎯 KIRA ASPECT RATIO SUPAYA GAMBAR TAK DISTORT
                    double aspectRatio = _imageWidth / _imageHeight;
                    double imageHeight = screenWidth / aspectRatio;
                    
                    return SizedBox(
                      width: screenWidth,
                      height: imageHeight,
                      child: Stack(
                        children: [
                          // LAYER 1: GAMBAR Z-WHEEL
                          Positioned.fill(
                            child: Image.asset(
                              'assets/z_wheel.png',
                              fit: BoxFit.fill,
                            ),
                          ),

                          // LAYER 2: RODA OVERLAY (5 WHEELS)
                          ..._buildWheelOverlays(screenWidth, imageHeight),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 80),

              // TOMBOL UNLOCK
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    // widget.controller?.verify(_currentCode);
                    print("CODE: $_currentCode");
                    
                    // Demo: Check kalau kod betul
                    if (_currentCode.join() == "00009") {
                      print("✅ UNLOCKED!");
                      widget.onSuccess?.call();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    shadowColor: _primaryOrange.withOpacity(0.5),
                    elevation: 10,
                  ),
                  child: const Text(
                    "UNLOCK SYSTEM",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
    );
  }

  // 🔥 BUILD SEMUA 5 RODA DENGAN POSITIONED YANG TEPAT
  List<Widget> _buildWheelOverlays(double screenWidth, double screenHeight) {
    List<Widget> wheels = [];
    
    for (int i = 0; i < 5; i++) {
      // Ambil koordinat asal (dalam pixel)
      double left = _wheelCoords[i][0];
      double top = _wheelCoords[i][1];
      double right = _wheelCoords[i][2];
      double bottom = _wheelCoords[i][3];
      
      // 🎯 CONVERT PIXEL → PERATUS (%)
      double leftPct = left / _imageWidth;
      double topPct = top / _imageHeight;
      double widthPct = (right - left) / _imageWidth;
      double heightPct = (bottom - top) / _imageHeight;
      
      // 🎯 CONVERT PERATUS → PIXEL SKRIN SEMASA
      double actualLeft = screenWidth * leftPct;
      double actualTop = screenHeight * topPct;
      double actualWidth = screenWidth * widthPct;
      double actualHeight = screenHeight * heightPct;
      
      wheels.add(
        Positioned(
          left: actualLeft,
          top: actualTop,
          width: actualWidth,
          height: actualHeight,
          child: _buildWheel(i, actualHeight),
        ),
      );
    }
    
    return wheels;
  }

  // WIDGET SATU RODA
  Widget _buildWheel(int index, double wheelHeight) {
    // 🎯 ITEM EXTENT = 35% DARI TINGGI RODA (BOLEH ADJUST)
    double itemExtent = wheelHeight * 0.40;
    
    return ListWheelScrollView.useDelegate(
      controller: _scrollControllers[index],
      itemExtent: itemExtent,
      perspective: 0.003,        // Kurangkan sikit untuk effect lebih flat
      diameterRatio: 1.5,        // Adjust curve
      physics: const FixedExtentScrollPhysics(),
      
      onSelectedItemChanged: (_) {
        HapticFeedback.selectionClick();
        setState(() => _activeWheelIndex = index);
      },
      
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, i) {
          return Center(
            child: Text(
              '${i % 10}',
              style: TextStyle(
                fontSize: wheelHeight * 0.30,  // Font size 30% dari tinggi roda
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
                
                // Efek Ukiran
                shadows: [
                  Shadow(
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.8),
                  ),
                  Shadow(
                    offset: const Offset(-1, -1),
                    blurRadius: 2,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
