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
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.pinkAccent, // WARNA PINK
      
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // ❌ JANGAN ADA 'const' DI SINI
          children: [ 
            Icon(Icons.warning, size: 60, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "APK BERJAYA UPDATE!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
