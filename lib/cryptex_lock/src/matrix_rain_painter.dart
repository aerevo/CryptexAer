// matrix_rain_painter.dart
// Create: lib/cryptex_lock/src/matrix_rain_painter.dart

import 'dart:math';
import 'package:flutter/material.dart';

// ============================================
// MATRIX RAIN MODEL
// ============================================
class MatrixColumn {
  double y;
  double speed;
  List<String> chars;
  
  MatrixColumn({
    required this.y,
    required this.speed,
    required this.chars,
  });
}

class MatrixRain {
  final int columnCount;
  final List<MatrixColumn> columns = [];
  final Random _random = Random();
  
  static const String _chars = '01アイウエオカキクケコサシスセソタチツテト';
  
  MatrixRain({required this.columnCount}) {
    for (int i = 0; i < columnCount; i++) {
      columns.add(_createColumn());
    }
  }
  
  MatrixColumn _createColumn() {
    return MatrixColumn(
      y: _random.nextDouble() * 140,
      speed: 1.5 + _random.nextDouble() * 2.5,
      chars: List.generate(
        8 + _random.nextInt(5),
        (_) => _chars[_random.nextInt(_chars.length)],
      ),
    );
  }
  
  void update() {
    for (var col in columns) {
      col.y += col.speed;
      
      if (col.y > 160) {
        col.y = -20;
        col.speed = 1.5 + _random.nextDouble() * 2.5;
        col.chars = List.generate(
          8 + _random.nextInt(5),
          (_) => _chars[_random.nextInt(_chars.length)],
        );
      }
    }
  }
}

// ============================================
// MATRIX RAIN PAINTER
// ============================================
class MatrixRainPainter extends CustomPainter {
  final MatrixRain rain;
  final Color color;
  
  MatrixRainPainter({
    required this.rain,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final columnWidth = size.width / rain.columnCount;
    
    for (int i = 0; i < rain.columns.length; i++) {
      final col = rain.columns[i];
      final x = i * columnWidth + columnWidth / 2;
      
      for (int j = 0; j < col.chars.length; j++) {
        final charY = col.y - (j * 10);
        
        if (charY < 0 || charY > size.height) continue;
        
        final opacity = j == 0 ? 0.9 : (1.0 - (j / col.chars.length)) * 0.6;
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: col.chars[j],
            style: TextStyle(
              color: color.withOpacity(opacity),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, charY),
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(MatrixRainPainter oldDelegate) => true;
}
