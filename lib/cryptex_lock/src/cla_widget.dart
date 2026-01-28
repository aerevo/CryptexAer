import 'package:flutter/material.dart';

// FASA 1 (FIXED): UJIAN ALIGNMENT GAMBAR (GRID MERAH)
// Hamba tambah parameter 'controller' dan lain-lain supaya main.dart tak error.

class CryptexLock extends StatelessWidget {
  // 🔥 PARAMETER DUMMY (Supaya build tak fail)
  final dynamic controller;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;
  final VoidCallback? onJammed;

  const CryptexLock({
    super.key,
    this.controller, // Kita terima tapi tak guna (sebab tengah test gambar)
    this.onSuccess,
    this.onFail,
    this.onJammed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          // Tinggi standard
          height: 140, 
          margin: const EdgeInsets.symmetric(horizontal: 16),
          
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(18),
            // GAMBAR BACKGROUND
            image: const DecorationImage(
              image: AssetImage('assets/z_wheel.png'),
              fit: BoxFit.cover, // Penuhkan kotak
            ),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          
          // 🔥 DEBUG: GRID MERAH UNTUK CHECK ALIGNMENT 🔥
          child: Row(
            children: List.generate(5, (index) {
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    // Garis merah ni mewakili "Lorong Nombor"
                    border: Border.all(
                      color: Colors.red.withOpacity(0.5), 
                      width: 2
                    ),
                    // Warna sikit supaya nampak kawasan dia
                    color: Colors.red.withOpacity(0.1),
                  ),
                  child: Center(
                    // Label lorong
                    child: Text(
                      "${index + 1}", 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
