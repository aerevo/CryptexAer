import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Import fail-fail controller Captain (pastikan nama file betul)
import 'cla_controller_v2.dart'; 
import 'cla_models.dart';
// (MatrixRain & Forensic painter boleh import kalau nak guna, 
//  tapi untuk kod roda ni hamba fokus visual utama dulu)

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
  // Controller untuk 5 roda
  late List<FixedExtentScrollController> _scrollControllers;
  int? _activeWheelIndex;

  // Warna UI
  final Color _primaryOrange = const Color(0xFFFF5722);
  final Color _engravedShadowDark = Colors.black.withOpacity(0.8);
  final Color _engravedShadowLight = Colors.white.withOpacity(0.4);

  @override
  void initState() {
    super.initState();
    // Mula semua roda pada nombor 0
    _scrollControllers = List.generate(5, (_) => FixedExtentScrollController(initialItem: 0));
  }

  @override
  void dispose() {
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  // Dapatkan kod semasa (untuk dihantar ke controller nanti)
  List<int> get _currentCode {
    return _scrollControllers.map((c) => c.selectedItem % 10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F5), // Background kelabu cerah (macam mockup)
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. STATUS HEADER
                Text(
                  "SECURE ACCESS",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey[800],
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 40),

                // 2. KOTAK PUTIH (FRAME UTAMA)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 🔥 ZONA RODA (GAMBAR + NOMBOR) 🔥
                      SizedBox(
                        height: 140, // Tinggi fix ikut arahan Captain
                        child: Stack(
                          children: [
                            // LAYER A: GAMBAR BACKGROUND (Z_WHEEL)
                            // Kita guna BoxFit.fill supaya dia stretch penuh kiri-kanan
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  image: const DecorationImage(
                                    image: AssetImage('assets/z_wheel.png'),
                                    fit: BoxFit.fill, 
                                  ),
                                ),
                              ),
                            ),

                            // LAYER B: SHADOW KIRI KANAN (Masuk dalam sikit)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.5),
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.5),
                                    ],
                                    stops: const [0.0, 0.1, 0.9, 1.0],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),

                            // LAYER C: NOMBOR SCROLLING (5 LORONG)
                            // Ini logik alignment tepat yang Captain minta
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(5, (index) => _buildWheelLane(index)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 3. INDIKATOR TITIK (DOTS)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: i == 1 ? Colors.blueGrey : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                        )),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 4. BUTTON OREN (CONFIRM)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      widget.controller.verify(_currentCode);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 10,
                      shadowColor: _primaryOrange.withOpacity(0.5),
                    ),
                    child: const Text(
                      "UNLOCK SYSTEM",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
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

  // 🔥 FUNGSI MEMBINA SETIAP RODA (LORONG)
  Widget _buildWheelLane(int index) {
    return Expanded(
      child: Container(
        // Margin 4px kiri kanan (Arahan Captain)
        margin: const EdgeInsets.symmetric(horizontal: 4), 
        
        // ListWheelScrollView adalah enjin pusingan
        child: ListWheelScrollView.useDelegate(
          controller: _scrollControllers[index],
          itemExtent: 55,       // Tinggi setiap nombor (Arahan Captain)
          perspective: 0.005,   // Lengkung 3D sikit (Arahan Captain)
          diameterRatio: 1.1,   // Radius pusingan ketat (Arahan Captain)
          physics: const FixedExtentScrollPhysics(),
          
          // Pudar sikit nombor yang jauh dari tengah
          overAndUnderCenterOpacity: 0.3, 
          
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
                    fontSize: 46, // Saiz Font (Arahan Captain)
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto', // Atau font sistem standard
                    shadows: [
                      // Shadow Bawah Kanan (Gelap)
                      Shadow(
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                        color: _engravedShadowDark,
                      ),
                      // Shadow Atas Kiri (Terang/Highlight) - Efek Ukir
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
