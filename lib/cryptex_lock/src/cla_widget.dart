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
  final Color _engravedShadowDark = Colors.black.withOpacity(0.9); // Lebih gelap sikit
  final Color _engravedShadowLight = Colors.white.withOpacity(0.5); 

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
                    // EFEK LUBANG TERBENAM (INSET)
                    boxShadow: [
                      // Bayang dalam (Atas Kiri - Gelap)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(5, 5),
                        blurRadius: 10,
                        spreadRadius: -2, // Inset effect
                      ),
                      // Highlight dalam (Bawah Kanan - Putih)
                      BoxShadow(
                        color: Colors.white,
                        offset: const Offset(-5, -5),
                        blurRadius: 10,
                        spreadRadius: -2, // Inset effect
                      ),
                    ],
                  ),
                  child: Container(
                    height: 140, // Tinggi FIX (Jangan ubah)
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      // Frame hitam nipis keliling gambar
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    clipBehavior: Clip.hardEdge, // Potong bucu gambar
                    child: Stack(
                      children: [
                        // 🔥 LAYER A: GAMBAR RODA (BACKGROUND)
                        Positioned.fill(
                          child: Image.asset(
                            'assets/z_wheel.png',
                            fit: BoxFit.fill, // PAKSA gambar penuh kotak
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

                        // 🔥 LAYER C: NOMBOR (PIXEL PERFECT ALIGNMENT)
                        Row(
                          children: List.generate(5, (index) => _buildPreciseWheel(index)),
                        ),
                      ],
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
                      elevation: 0, // Kita guna shadow container
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
        // Margin 5px kiri kanan untuk match frame hitam gambar Captain
        margin: const EdgeInsets.symmetric(horizontal: 5), 
        
        // Highlight Oren bila disentuh (Subtle Overlay)
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFFFF5722).withOpacity(0.2) // Active Glow
              : Colors.transparent,
        ),
        
        child: ListWheelScrollView.useDelegate(
          controller: _scrollControllers[index],
          
          // 🔥 PARAMETER FIZIKAL (TUNED)
          itemExtent: 55,       // Match tinggi "shine" roda
          perspective: 0.006,   // Curve 3D
          diameterRatio: 1.2,   // Rasa dial fizikal
          
          physics: const FixedExtentScrollPhysics(),
          overAndUnderCenterOpacity: 0.25, // Nombor tepi pudar
          
          onSelectedItemChanged: (_) {
             HapticFeedback.selectionClick();
             setState(() => _activeWheelIndex = index);
          },
          
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, i) {
              return Container(
                // Pastikan container text ni duduk tengah-tengah slot itemExtent
                alignment: Alignment.center, 
                child: Text(
                  '${i % 10}',
                  style: TextStyle(
                    fontFamily: 'Roboto', // Guna font sistem yang stable
                    fontSize: 48,         // Besar & Jelas
                    fontWeight: FontWeight.w900, // Tebal Maksimum
                    color: Colors.white,
                    height: 1.0,          // 🔥 PENTING: Matikan line-height extra
                    
                    shadows: [
                      // Emboss Bawah (Gelap)
                      Shadow(
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                        color: _engravedShadowDark,
                      ),
                      // Emboss Atas (Terang) - Efek Ukir
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
      ),
    );
  }
}
