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

  // 🔥 KOORDINAT RODA (626 x 471)
  // Format: [left, top, right, bottom]
  static const List<List<double>> _wheelCoords = [
    [85, 133, 143, 286],   // Roda 1
    [180, 132, 242, 285],  // Roda 2
    [276, 133, 337, 282],  // Roda 3
    [371, 132, 431, 282],  // Roda 4
    [467, 130, 529, 285],  // Roda 5
  ];

  // 🔥 KOORDINAT BUTTON "CONFIRM ACCESS"
  // Dari Captain: 150, 318, 472, 399
  static const List<double> _buttonCoords = [150, 318, 472, 399];

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

  // Fungsi Unlock
  void _attemptUnlock() {
    HapticFeedback.heavyImpact();
    print("ATTEMPTING UNLOCK: $_currentCode");

    // Demo Logic
    if (_currentCode.join() == "00009") {
      print("✅ UNLOCKED!");
      widget.onSuccess?.call();
    } else {
      print("❌ WRONG CODE");
      widget.onFail?.call();
    }
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
              // 🔥 Z-WHEEL SYSTEM (WHEELS + BUTTON OVERLAY) 🔥
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double screenWidth = constraints.maxWidth;
                    
                    // 🎯 KIRA ASPECT RATIO
                    double aspectRatio = _imageWidth / _imageHeight;
                    double imageHeight = screenWidth / aspectRatio;
                    
                    return SizedBox(
                      width: screenWidth,
                      height: imageHeight,
                      child: Stack(
                        children: [
                          // LAYER 1: GAMBAR Z-WHEEL (BASE)
                          Positioned.fill(
                            child: Image.asset(
                              'assets/z_wheel.png',
                              fit: BoxFit.fill,
                            ),
                          ),

                          // LAYER 2: RODA OVERLAY (5 WHEELS)
                          ..._buildWheelOverlays(screenWidth, imageHeight),

                          // LAYER 3: PHANTOM BUTTON (KOTAK MERAH TEST)
                          _buildPhantomButton(screenWidth, imageHeight),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 BUILD BUTTON HANTU
  Widget _buildPhantomButton(double screenWidth, double screenHeight) {
    double left = _buttonCoords[0];
    double top = _buttonCoords[1];
    double right = _buttonCoords[2];
    double bottom = _buttonCoords[3];

    // Convert ke Pixel Skrin Semasa
    double actualLeft = screenWidth * (left / _imageWidth);
    double actualTop = screenHeight * (top / _imageHeight);
    double actualWidth = screenWidth * ((right - left) / _imageWidth);
    double actualHeight = screenHeight * ((bottom - top) / _imageHeight);

    return Positioned(
      left: actualLeft,
      top: actualTop,
      width: actualWidth,
      height: actualHeight,
      child: Material(
        color: Colors.transparent, // Material mesti transparent
        child: InkWell(
          onTap: _attemptUnlock, // Panggil fungsi unlock bila tekan kotak ni
          splashColor: Colors.white.withOpacity(0.3), // Efek kilat bila tekan
          borderRadius: BorderRadius.circular(10), // Curve sikit bucu effect
          
          // 🔥 CONTAINER VISUAL UNTUK TESTING (KOTAK MERAH)
          child: Container(
            decoration: BoxDecoration(
              // Nanti kita buang border ni bila Captain kata LULUS
              border: Border.all(color: Colors.redAccent, width: 3), 
              color: Colors.red.withOpacity(0.2), // Isi merah pudar sikit
            ),
            child: const Center(
              child: Text(
                "TAP HERE",
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 BUILD SEMUA 5 RODA
  List<Widget> _buildWheelOverlays(double screenWidth, double screenHeight) {
    List<Widget> wheels = [];
    
    for (int i = 0; i < 5; i++) {
      double left = _wheelCoords[i][0];
      double top = _wheelCoords[i][1];
      double right = _wheelCoords[i][2];
      double bottom = _wheelCoords[i][3];
      
      double actualLeft = screenWidth * (left / _imageWidth);
      double actualTop = screenHeight * (top / _imageHeight);
      double actualWidth = screenWidth * ((right - left) / _imageWidth);
      double actualHeight = screenHeight * ((bottom - top) / _imageHeight);
      
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
    double itemExtent = wheelHeight * 0.40;
    
    return ListWheelScrollView.useDelegate(
      controller: _scrollControllers[index],
      itemExtent: itemExtent,
      perspective: 0.003,
      diameterRatio: 1.5,
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
                fontSize: wheelHeight * 0.30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
                shadows: [
                  Shadow(offset: const Offset(2, 2), blurRadius: 4, color: Colors.black.withOpacity(0.8)),
                  Shadow(offset: const Offset(-1, -1), blurRadius: 2, color: Colors.white.withOpacity(0.3)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
