import 'package:flutter/material.dart';

class CryptexLock extends StatelessWidget {
  // Parameter wajib (supaya main.dart tak error)
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
      backgroundColor: Colors.black, // Latar belakang gelap
      body: Center(
        // KOTAK RODA UTAMA
        child: Container(
          // Tinggi Roda (Adjust sini kalau nak besar/kecil)
          height: 160, 
          
          // Lebar Penuh (Full Width)
          width: double.infinity, 
          
          decoration: BoxDecoration(
            // Warna backup kalau gambar lambat load
            color: Colors.grey[900], 
            
            // Garis putih nipis atas & bawah (supaya nampak frame)
            border: Border.symmetric(
              horizontal: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
            ),

            // 🔥 INI GAMBAR CAPTAIN 🔥
            image: const DecorationImage(
              image: AssetImage('assets/z_wheel.png'),
              // 'cover' = Penuhkan kotak, potong sikit tepi kalau perlu, janji tak gepenk.
              // 'fill' = Penuhkan kotak, tapi mungkin jadi gepenk/distorted.
              // Captain try 'cover' dulu, nampak lebih premium.
              fit: BoxFit.cover, 
            ),
          ),
        ),
      ),
    );
  }
}
