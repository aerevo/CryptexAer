import 'dart:math';
import 'package:flutter/material.dart';

class MatrixRain {
  final List<RainColumn> columns = [];
  final Random _random = Random();
  
  static const String chars = '0123456789ABCDEF!@#\$%^&*()_+-=[]{}|;:,.<>?~';
  
  MatrixRain({required int columnCount}) {
    for (int i = 0; i < columnCount; i++) {
      columns.add(RainColumn(
        x: i * 10.0,
        speed: 0.5 + _random.nextDouble() * 2.0,
        length: 5 + _random.nextInt(10),
      ));
    }
  }
  
  void update() {
    for (var column in columns) {
      column.update();
    }
  }
  
  String getRandomChar() {
    return chars[_random.nextInt(chars.length)];
  }
}

class RainColumn {
  double x;
  double y;
  double speed;
  int length;
  List<RainChar> characters = [];
  final Random _random = Random();
  
  RainColumn({
    required this.x,
    required this.speed,
    required this.length,
  }) : y = -Random().nextDouble() * 200 {
    for (int i = 0; i < length; i++) {
      characters.add(RainChar(
        char: MatrixRain.chars[_random.nextInt(MatrixRain.chars.length)],
        opacity: 1.0 - (i / length),
      ));
    }
  }
  
  void update() {
    y += speed;
    
    if (y > 150) {
      y = -length * 10.0;
      
      for (var char in characters) {
        char.char = MatrixRain.chars[_random.nextInt(MatrixRain.chars.length)];
      }
    }
    
    if (_random.nextDouble() < 0.05) {
      characters.first.char = MatrixRain.chars[_random.nextInt(MatrixRain.chars.length)];
    }
  }
}

class RainChar {
  String char;
  double opacity;
  
  RainChar({required this.char, required this.opacity});
}

class MatrixRainPainter extends CustomPainter {
  final MatrixRain rain;
  final Color color;
  
  MatrixRainPainter({
    required this.rain,
    this.color = const Color(0xFF00FF00),
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var column in rain.columns) {
      for (int i = 0; i < column.characters.length; i++) {
        final char = column.characters[i];
        final posY = column.y + (i * 10);
        
        if (posY < -10 || posY > size.height + 10) continue;
        
        final opacity = i == 0 ? 1.0 : char.opacity * 0.7;
        
        final charColor = i == 0
            ? const Color(0xFFCCFFCC)
            : color.withOpacity(opacity);
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: char.char,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: charColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(canvas, Offset(column.x, posY));
      }
    }
  }
  
  @override
  bool shouldRepaint(MatrixRainPainter oldDelegate) => true;
}
