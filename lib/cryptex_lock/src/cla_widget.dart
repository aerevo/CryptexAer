import 'package:flutter/material.dart';

class CryptexLock extends StatelessWidget {
  // Hamba terpaksa letak parameter ini supaya main.dart Captain tak error (crash).
  // Tapi kita takkan guna mereka sekarang.
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
      backgroundColor: Colors.black, // Latar belakang hitam
      body: Center(
        // HANYA PAPAR GAMBAR ORIGINAL
        child: Image.asset(
          'assets/z_wheel.png',
          fit: BoxFit.contain, // Tunjuk gambar penuh, jangan potong
        ),
      ),
    );
  }
}
