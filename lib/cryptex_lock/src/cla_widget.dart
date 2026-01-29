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
      // KITA TUKAR JADI MERAH. 
      // Kalau Captain run dan skrin masih HITAM, maksudnya kod ni tak update.
      // Kalau skrin MERAH tapi kosong, maksudnya kod jalan tapi gambar hilang.
      backgroundColor: Colors.red, 
      
      body: Center(
        child: Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2), // Kotak putih
          ),
          child: Image.asset(
            'assets/z_wheel.png',
            
            // Kalau gambar rosak/tak jumpa, dia akan tunjuk icon pangkah
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    "GAMBAR HILANG!", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ],
              );
            },
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
