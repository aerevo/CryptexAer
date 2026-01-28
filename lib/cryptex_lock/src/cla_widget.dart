import 'package:flutter/material.dart';

// FASA 1: TEST GAMBAR BACKGROUND SAHAJA
class CryptexLock extends StatelessWidget {
  // Kita letak constructor simple dulu, tak perlu controller lagi buat masa ni
  const CryptexLock({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Latar belakang gelap
      body: Center(
        child: Container(
          // Tinggi standard untuk UI kita nanti
          height: 140, 
          
          // Jarak sikit dari tepi skrin
          margin: const EdgeInsets.symmetric(horizontal: 16),
          
          decoration: BoxDecoration(
            // Fallback color (kalau gambar tak load, nampak kelabu)
            color: Colors.grey[800],
            
            // Bucu bulat sikit supaya nampak 'classy'
            borderRadius: BorderRadius.circular(18),
            
            // 🔥 INI DIA. GAMBAR CAPTAIN 🔥
            image: const DecorationImage(
              image: AssetImage('assets/z_wheel.png'),
              fit: BoxFit.cover, // Penuhkan ruang tanpa gepenk
            ),
            
            // Hiasan border sikit (optional)
            border: Border.all(
              color: Colors.white24,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
