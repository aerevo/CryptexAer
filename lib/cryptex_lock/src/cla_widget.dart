import 'package:flutter/material.dart';

// FASA 1 (DEBUG MODE): KOTAK MERAH + GAMBAR
class CryptexLock extends StatelessWidget {
  // Parameter dummy supaya tak error
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
  Widget build(BuildContext context) {
    // ❌ KITA BUANG SCAFFOLD (Sebab main.dart dah ada Scaffold)
    // ✅ KITA GUNA CONTAINER TERUS
    return Center(
      child: Container(
        height: 140, // Tinggi tetap
        margin: const EdgeInsets.symmetric(horizontal: 16),
        
        decoration: BoxDecoration(
          // 🔥 DEBUG COLOR: MERAH TERANG 🔥
          // Kalau gambar tak keluar, Captain AKAN nampak kotak merah ni.
          color: Colors.redAccent, 
          
          borderRadius: BorderRadius.circular(18),
          
          // Cuba panggil gambar
          image: const DecorationImage(
            image: AssetImage('assets/z_wheel.png'),
            fit: BoxFit.cover, 
          ),
          
          border: Border.all(color: Colors.yellow, width: 2), // Border Kuning
        ),

        // Grid Kuning untuk check alignment
        child: Row(
          children: List.generate(5, (index) {
            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.yellow.withOpacity(0.5), 
                    width: 2
                  ),
                ),
                child: Center(
                  child: Text(
                    "${index + 1}", 
                    style: const TextStyle(
                      color: Colors.yellow, 
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
