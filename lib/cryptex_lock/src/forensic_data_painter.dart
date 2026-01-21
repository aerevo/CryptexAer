import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

class ForensicDataPainter extends CustomPainter {
  final Color color;
  final int motionCount;
  final int touchCount;
  final double entropy;
  final double confidence;
  
  ForensicDataPainter({
    required this.color,
    required this.motionCount,
    required this.touchCount,
    required this.entropy,
    required this.confidence,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final hash = _generateHash();
    
    final entries = [
      {'hash': hash.substring(0, 8), 'label': 'MC:$motionCount'},
      {'hash': hash.substring(8, 16), 'label': 'TC:$touchCount'},
      {'hash': hash.substring(16, 24), 'label': 'E:${(entropy * 100).toInt()}'},
      {'hash': hash.substring(24, 32), 'label': 'C:${(confidence * 100).toInt()}'},
    ];
    
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final yPos = 35.0 + (i * 28);
      
      _drawText(
        canvas,
        entry['hash']!,
        2, yPos,
        size: 7,
        color: color,
        bold: true,
      );
      
      _drawText(
        canvas,
        entry['label']!,
        2, yPos + 8,
        size: 5,
        color: color.withOpacity(0.5),
        bold: false,
      );
    }
  }
  
  String _generateHash() {
    final payload = {
      'mc': motionCount,
      'tc': touchCount,
      'ent': (entropy * 1000).toInt(),
      'conf': (confidence * 1000).toInt(),
      'ts': DateTime.now().millisecondsSinceEpoch,
      'nonce': DateTime.now().microsecondsSinceEpoch % 10000,
    };
    
    final jsonStr = jsonEncode(payload);
    final bytes = utf8.encode(jsonStr);
    final digest = sha256.convert(bytes);
    
    return digest.toString().substring(0, 32).toUpperCase();
  }
  
  void _drawText(
    Canvas canvas,
    String text,
    double x, double y, {
    required double size,
    required Color color,
    required bool bold,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: size,
          fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
  }
  
  @override
  bool shouldRepaint(ForensicDataPainter oldDelegate) {
    return motionCount != oldDelegate.motionCount ||
           touchCount != oldDelegate.touchCount ||
           entropy != oldDelegate.entropy ||
           confidence != oldDelegate.confidence;
  }
}
