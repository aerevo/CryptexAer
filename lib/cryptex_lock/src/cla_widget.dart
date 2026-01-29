import 'package:flutter/material.dart';

class CryptexLock extends StatelessWidget {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        // KITA GUNA CONTAINER TANPA HEIGHT TETAP
        child: Container(
          width: double.infinity, // Lebar Penuh (Wajib)
          
          // Letak border sikit supaya Captain nampak batas gambar
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
            ),
          ),

          // 🔥 KOD FIX POTONG ATAS BAWAH 🔥
          child: Image.asset(
            'assets/z_wheel.png',
            
            // "fitWidth" maksudnya: 
            // 1. Tarik gambar sampai penuh kiri-kanan.
            // 2. Tinggi akan 'expand' secara automatik supaya gambar tak terpotong.
            // 3. Gambar takkan jadi gepenk.
            fit: BoxFit.fitWidth, 
          ),
        ),
      ),
    );
  }
}
