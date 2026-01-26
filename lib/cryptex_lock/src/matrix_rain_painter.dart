// 📂 LOCATION: lib/cryptex_lock/src/matrix_rain_painter.dart
// ✅ VERSION: V2.1 (FORENSIC DATA STREAM - DIGITS ONLY + PHOSPHOR GREEN)

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ============================================
// MATRIX RAIN ENGINE & MODEL
// ============================================
class MatrixRain {
  final int columnCount;
  final Random _random = Random();
  List<MatrixStream>? _streams;
  
  // 🔥 FORENSIC MODE: HANYA NOMBOR (Nampak macam data bank/server)
  static const String _chars = '0123456789'; 

  MatrixRain({required this.columnCount});

  void update(Size size) {
    // Initialize streams if screen size changes or first run
    if (_streams == null || _streams!.isEmpty || _streams!.length != (size.width / 15).floor()) {
      _respawnStreams(size);
    }

    // Update setiap titisan hujan
    for (var stream in _streams!) {
      stream.update(size.height, _chars, _random);
    }
  }

  void _respawnStreams(Size size) {
    final double colWidth = 14.0; // Lebar lajur (Rapat sikit untuk data padat)
    final int cols = (size.width / colWidth).ceil();
    
    _streams = List.generate(cols, (i) {
      return MatrixStream(
        x: i * colWidth,
        y: _random.nextDouble() * -1000, 
        speed: 4 + _random.nextDouble() * 8, // Laju sikit macam data transfer
        length: 8 + _random.nextInt(20), // Ekor panjang sikit
        chars: List.generate(20, (_) => _getRandomChar()),
        fontSize: 11 + _random.nextDouble() * 4, 
      );
    });
  }

  String _getRandomChar() => _chars[_random.nextInt(_chars.length)];
}

// ============================================
// INDIVIDUAL STREAM LOGIC
// ============================================
class MatrixStream {
  double x;
  double y;
  double speed;
  int length;
  List<String> chars;
  double fontSize;
  int _tick = 0;

  MatrixStream({
    required this.x, 
    required this.y, 
    required this.speed, 
    required this.length,
    required this.chars,
    required this.fontSize,
  });

  void update(double height, String charSet, Random random) {
    y += speed;
    _tick++;

    // Reset bila jatuh bawah skrin
    if (y > height + (length * fontSize)) {
      y = random.nextDouble() * -500;
      speed = 4 + random.nextDouble() * 8;
      length = 8 + random.nextInt(20);
      chars = List.generate(length + 5, (_) => charSet[random.nextInt(charSet.length)]);
    }

    // 🔥 GLITCH EFFECT: Tukar nombor dalam ekor (Data scrambling)
    // Tukar lebih kerap (setiap 3 frame) supaya nampak "busy"
    if (_tick % 3 == 0) {
      int indexToChange = random.nextInt(chars.length);
      chars[indexToChange] = charSet[random.nextInt(charSet.length)];
    }
  }
}

// ============================================
// THE PAINTER (RENDER ENGINE)
// ============================================
class MatrixRainPainter extends CustomPainter {
  final MatrixRain rain;
  final Color color; 

  MatrixRainPainter({required this.rain, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    rain.update(size);

    // ✅ WARNA MOVIE: PHOSPHOR GREEN
    // Hex: #00FF41 (Ini warna rasmi terminal hijau lama)
    final Color phosphorGreen = const Color(0xFF00FF41);

    final headStyle = TextStyle(
      color: Colors.white.withOpacity(0.9), // Kepala Putih (Highlight)
      fontSize: 14,
      fontWeight: FontWeight.w900,
      shadows: [
        Shadow(color: phosphorGreen, blurRadius: 10), // Glow hijau di sekeliling putih
      ], 
      fontFamily: 'monospace', 
    );

    final tailBaseStyle = TextStyle(
      color: phosphorGreen, 
      fontSize: 14,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w500,
    );

    for (var stream in rain._streams ?? []) {
      // Optimization: Skip luar skrin
      if (stream.y < -100 || stream.y > size.height + 500) continue;

      for (int i = 0; i < stream.length; i++) {
        double charY = stream.y - (i * stream.fontSize);
        
        if (charY > size.height || charY < -20) continue;

        bool isHead = (i == 0);
        
        // 🔥 TRAIL EFFECT: Pudar lebih cepat di hujung
        double opacity = (1.0 - (i / stream.length)).clamp(0.0, 1.0);
        
        // Jadikan ekor sedikit telus supaya tak serabut sangat
        opacity = opacity * 0.8; 

        if (opacity < 0.05) continue; 

        final textSpan = TextSpan(
          text: stream.chars[i % stream.chars.length],
          style: isHead 
              ? headStyle.copyWith(fontSize: stream.fontSize) 
              : tailBaseStyle.copyWith(
                  fontSize: stream.fontSize, 
                  color: phosphorGreen.withOpacity(opacity)
                ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(canvas, Offset(stream.x, charY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
