import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Guna controller dummy kalau belum link, atau import yang betul
// import 'cla_controller_v2.dart'; 

class CryptexLock extends StatefulWidget {
  final dynamic controller; // Guna dynamic utk elak error type
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

  @override
  void initState() {
    super.initState();
    // Mula semua roda kat nombor 0
    _scrollControllers = List.generate(5, (_) => FixedExtentScrollController(initialItem: 0));
  }

  @override
  void dispose() {
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  // Dapatkan kod semasa (0-0-0-0-0)
  List<int> get _currentCode {
    return _scrollControllers.map((c) => c.selectedItem % 10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Latar gelap
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
              // 🔥 Z-WHEEL SYSTEM (PIXEL PERFECT CALIBRATED) 🔥
              // ==================================================
              Container(
                width: double.infinity,
                // Kita bagi ruang sikit kat border
                padding: const EdgeInsets.symmetric(horizontal: 10),
                
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 1. Ambil lebar skrin semasa
                    double screenWidth = constraints.maxWidth;
                    
                    // 2. FORMULA MATEMATIK CAPTAIN (626 x 471)
                    // Kita convert pixel asal jadi peratus (%)
                    double paddingLeftPct = 66.0 / 626.0;  // ~10.5%
                    double paddingRightPct = 80.0 / 626.0; // ~12.8%
                    
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // LAYER 1: GAMBAR ORIGINAL (ASAS)
                        Image.asset(
                          'assets/z_wheel.png',
                          fit: BoxFit.fitWidth,
                        ),

                        // LAYER 2: ENJIN RODA (OVERLAY)
                        // Kita 'kepit' roda ni guna Padding hasil kiraan tadi
                        Padding(
                          padding: EdgeInsets.only(
                            left: screenWidth * paddingLeftPct,   // Auto-adjust ikut skrin
                            right: screenWidth * paddingRightPct, // Auto-adjust ikut skrin
                          ),
                          child: Row(
                            // Expanded akan bahagi ruang yg tinggal kpd 5 bahagian sama rata
                            children: List.generate(5, (index) => _buildWheel(index)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 80),

              // TOMBOL CONFIRM
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    // Panggil fungsi verify controller kalau ada
                    // widget.controller?.verify(_currentCode);
                    print("CODE: $_currentCode"); 
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

  // WIDGET SATU RODA
  Widget _buildWheel(int index) {
    return Expanded(
      child: SizedBox(
        // Tinggi ni anggaran, ListWheelScrollView akan handle clipping
        height: 150, 
        
        child: ListWheelScrollView.useDelegate(
          controller: _scrollControllers[index],
          itemExtent: 70,       // Jarak antara nombor (Vertical Spacing)
          perspective: 0.005,   // Curve 3D
          diameterRatio: 1.2,   // Kelengkungan Roda
          physics: const FixedExtentScrollPhysics(),
          
          onSelectedItemChanged: (_) {
            HapticFeedback.selectionClick();
            setState(() => _activeWheelIndex = index);
          },
          
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, i) {
              return Container(
                // 🔥 ALIGNMENT VERTICAL (Y-AXIS FIX)
                // -0.12 bermaksud naikkan sikit dari center (sebab slot roda tinggi sikit)
                alignment: const Alignment(0.0, -0.12),
                
                child: Text(
                  '${i % 10}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0, // Matikan extra leading
                    
                    // Efek Ukiran (Emboss)
                    shadows: [
                      Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black.withOpacity(0.8)),
                      Shadow(offset: Offset(-1, -1), blurRadius: 2, color: Colors.white.withOpacity(0.3)),
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
