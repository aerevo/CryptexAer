import 'package:flutter/material.dart';

class CryptexLock extends StatelessWidget {
  // Parameter wajib supaya main.dart tak error semasa build
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
    // ❌ TAK ADA GAMBAR
    // ✅ CUMA WARNA PINK TERANG
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.pinkAccent, // Kalau skrin tak jadi Pink, maksudnya APK belum update
      
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.warning, size: 60, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "SILA UPDATE APK",
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold, 
                color: Colors.white
              ),
            ),
            Text(
              "Kod Pink Berjaya!",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
