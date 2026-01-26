// 📂 LOCATION: lib/cryptex_lock/src/matrix_rain_painter.dart
// ✅ VERSION: V3.0 (CMD BATCH SCRIPT STYLE - "ECHO %RANDOM%")
// "Simple, Laju."

import 'dart:math';
import 'package:flutter/material.dart';

// ============================================
// LOGIC CONTROLLER (CMD ENGINE)
// ============================================
class MatrixRain {
  final int columnCount; // Tak pakai, tapi simpan supaya tak error di widget utama
  final Random _random = Random();
  final List<String> _lines = [];
  final int _maxLines = 40; // Berapa baris muat dalam skrin
  
  // Nombor rawak 0-9 dan ruang kosong sikit
  static const String _chars = '01234567890123456789    '; 

  MatrixRain({required this.columnCount});

  // Fungsi update mudah: Tambah baris baru kat bawah, buang baris atas
  void update(Size size) {
    // Generate satu baris penuh nombor rawak
    String newLine = "";
    int charsPerLine = (size.width / 10).ceil(); // Anggaran lebar font
    
    for (int i = 0; i < charsPerLine; i++) {
      newLine += _chars[_random.nextInt(_chars.length)];
    }

    _lines.add(newLine);

    // Kalau dah penuh skrin, buang yang paling atas (Effect scrolling)
    if (_lines.length > _maxLines) {
      _lines.removeAt(0);
    }
  }

  List<String> get lines => _lines;
}

// ============================================
// PAINTER (RENDER ENGINE)
// ============================================
class MatrixRainPainter extends CustomPainter {
  final MatrixRain rain;
  final Color color; 

  MatrixRainPainter({required this.rain, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Update Logic (Scrolling Up)
    rain.update(size);

    // 2. Setup Font (Hacker Terminal Style)
    final textStyle = TextStyle(
      color: const Color(0xFF00FF00), // Hijau CMD terang
      fontSize: 12,
      fontFamily: 'monospace', // Wajib monospace
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 3. Lukis Baris demi Baris
    for (int i = 0; i < rain.lines.length; i++) {
      textPainter.text = TextSpan(
        text: rain.lines[i],
        style: textStyle,
      );
      
      textPainter.layout();
      
      // Lukis dari atas ke bawah
      textPainter.paint(canvas, Offset(0, i * 14.0));
    }
    
    // 4. Efek "Cursor" di baris paling bawah (Pilihan)
    // Buat baris bawah sekali lebih terang/putih
    if (rain.lines.isNotEmpty) {
      textPainter.text = TextSpan(
        text: rain.lines.last,
        style: textStyle.copyWith(color: Colors.white, backgroundColor: Colors.green.withOpacity(0.3)),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, (rain.lines.length - 1) * 14.0));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
