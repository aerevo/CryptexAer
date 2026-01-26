// 📂 LOCATION: lib/cryptex_lock/src/matrix_rain_painter.dart
// ✅ VERSION: V2.3 (DARK MICROSCOPIC - FIT FOR 'FOREN' BOX)

import 'dart:math';
import 'package:flutter/material.dart';

class MatrixRain {
  final int columnCount;
  final Random _random = Random();
  List<MatrixStream>? _streams;
  
  // Digit Binary shj nampak lebih 'code'
  static const String _chars = '01'; 

  MatrixRain({required this.columnCount});

  void update(Size size) {
    // 🔥 OPTIMIZATION: Lebar lajur KECIL (8px) supaya muat dalam kotak 'FOREN' 45px
    double colWidth = 9.0; 
    
    if (_streams == null || _streams!.isEmpty || _streams!.length != (size.width / colWidth).floor()) {
      _respawnStreams(size, colWidth);
    }
    
    for (var stream in _streams!) {
      stream.update(size.height, _chars, _random);
    }
  }

  void _respawnStreams(Size size, double colWidth) {
    final int cols = (size.width / colWidth).ceil(); 
    
    _streams = List.generate(cols, (i) {
      return MatrixStream(
        x: i * colWidth,
        y: _random.nextDouble() * -400, // Mula random
        speed: 1.5 + _random.nextDouble() * 2.0, // Speed sederhana
        length: 2 + _random.nextInt(4), // 🔥 EKOR PENDEK (2-6 huruf je)
        chars: List.generate(8, (_) => _getRandomChar()),
        fontSize: 7.0 + _random.nextDouble() * 2.0, // 🔥 FONT HALUS (7-9px)
      );
    });
  }

  String _getRandomChar() => _chars[_random.nextInt(_chars.length)];
}

class MatrixStream {
  double x, y, speed, fontSize;
  int length;
  List<String> chars;
  int _tick = 0;

  MatrixStream({required this.x, required this.y, required this.speed, required this.length, required this.chars, required this.fontSize});

  void update(double height, String charSet, Random random) {
    y += speed;
    _tick++;
    
    // Reset bila jejak bawah
    if (y > height) { 
      y = -50 - (random.nextDouble() * 100); // Reset dekat-dekat sikit
      speed = 1.5 + random.nextDouble() * 2.0;
      length = 2 + random.nextInt(4); // Kekalkan ekor pendek
    }
    
    // Glitch jarang-jarang (Data scrambling)
    if (_tick % 10 == 0) { 
      chars[random.nextInt(chars.length)] = charSet[random.nextInt(charSet.length)];
    }
  }
}

class MatrixRainPainter extends CustomPainter {
  final MatrixRain rain;
  final Color color; 

  MatrixRainPainter({required this.rain, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    rain.update(size);

    // 🔥 WARNA HIJAU GELAP (Deep Terminal Green)
    // Tak menyilaukan mata, nampak macam background process
    final Color darkGreen = const Color(0xFF1B5E20); // Green 900
    final Color headColor = const Color(0xFF2E7D32); // Green 800 (Highlight sikit je)

    for (var stream in rain._streams ?? []) {
      // Optimization: Skip kalau jauh sangat luar skrin
      if (stream.y < -20 || stream.y > size.height + 20) continue;

      for (int i = 0; i < stream.length; i++) {
        double charY = stream.y - (i * stream.fontSize);
        
        // 🔥 LOGIK FADE: Pudar sangat cepat
        double opacity = (1.0 - (i / stream.length)).clamp(0.0, 1.0);
        
        if (opacity < 0.2) continue; // Potong terus kalau pudar sgt

        final textSpan = TextSpan(
          text: stream.chars[i % stream.chars.length],
          style: TextStyle(
            // Kalau kepala (i==0), terang sikit. Ekor gelap.
            color: (i == 0) ? headColor : darkGreen.withOpacity(opacity * 0.7),
            fontSize: stream.fontSize,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold, // Tebal sikit sbb font kecil
            height: 1.0, // Rapatkan jarak atas-bawah
          ),
        );

        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();
        textPainter.paint(canvas, Offset(stream.x, charY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
