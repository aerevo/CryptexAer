// lib/main.dart

import 'package:flutter/material.dart';
// Kita panggil fail kunci Kapten di bawah
import 'cryptex_lock_screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cryptex Aer Demo',
      theme: ThemeData(
        // Tema gelap nampak lebih 'Hacker' & 'Premium'
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.blue,
      ),
      // Skrin pertama terus buka kunci Kapten
      home: const CryptexLockScreen(), 
    );
  }
}