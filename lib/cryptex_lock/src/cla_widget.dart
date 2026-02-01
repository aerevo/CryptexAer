import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Menghilangkan banner debug di pojok kanan atas
      debugShowCheckedModeBanner: false, 
      home: Scaffold(
        // Latar belakang putih agar kontras dengan kotak
        backgroundColor: Colors.white, 
        body: Center(
          child: Container(
            // Ukuran tetap agar tidak menghilang (collapse)
            width: 200,
            height: 200,
            // Warna biru pilihan saya agar terlihat jelas
            color: Colors.blue, 
            child: const Center(
              child: Text(
                'SISTEM HIDUP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
