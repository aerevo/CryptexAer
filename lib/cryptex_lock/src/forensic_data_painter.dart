// forensic_data_painter.dart
// Create: lib/cryptex_lock/src/forensic_data_painter.dart

import 'package:flutter/material.dart';
import 'dart:math';

// ============================================
// FORENSIC DATA PAINTER
// ============================================
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
    _drawDataLines(canvas, size);
    _drawMetrics(canvas, size);
  }
  
  void _drawDataLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 0.5;
    
    // Draw horizontal scan lines
    for (double y = 30; y < size.height; y += 15) {
      canvas.drawLine(
        Offset(5, y),
        Offset(size.width - 5, y),
        paint,
      );
    }
    
    // Draw vertical divider
    canvas.drawLine(
      Offset(size.width / 2, 30),
      Offset(size.width / 2, size.height - 10),
      paint..strokeWidth = 1,
    );
  }
  
  void _drawMetrics(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Motion metric
    _drawMetricText(
      canvas,
      textPainter,
      'M',
      motionCount.toString().padLeft(3, '0'),
      8,
      35,
    );
    
    // Touch metric
    _drawMetricText(
      canvas,
      textPainter,
      'T',
      touchCount.toString().padLeft(3, '0'),
      8,
      55,
    );
    
    // Entropy bar
    _drawProgressBar(canvas, size, entropy, 75, 'E');
    
    // Confidence bar
    _drawProgressBar(canvas, size, confidence, 95, 'C');
    
    // Live indicator
    _drawLiveIndicator(canvas, size, 115);
  }
  
  void _drawMetricText(
    Canvas canvas,
    TextPainter textPainter,
    String label,
    String value,
    double x,
    double y,
  ) {
    // Label
    textPainter.text = TextSpan(
      text: label,
      style: TextStyle(
        color: color.withOpacity(0.7),
        fontSize: 6,
        fontWeight: FontWeight.bold,
        fontFamily: 'Courier',
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
    
    // Value
    textPainter.text = TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontSize: 7,
        fontWeight: FontWeight.w900,
        fontFamily: 'Courier',
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x + 10, y));
  }
  
  void _drawProgressBar(
    Canvas canvas,
    Size size,
    double value,
    double y,
    String label,
  ) {
    final barWidth = size.width - 16;
    final filledWidth = barWidth * value.clamp(0.0, 1.0);
    
    // Background
    canvas.drawRect(
      Rect.fromLTWH(8, y, barWidth, 6),
      Paint()..color = color.withOpacity(0.1),
    );
    
    // Fill
    canvas.drawRect(
      Rect.fromLTWH(8, y, filledWidth, 6),
      Paint()..color = color.withOpacity(0.6),
    );
    
    // Border
    canvas.drawRect(
      Rect.fromLTWH(8, y, barWidth, 6),
      Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    
    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color.withOpacity(0.7),
          fontSize: 5,
          fontWeight: FontWeight.bold,
          fontFamily: 'Courier',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(3, y + 1));
  }
  
  void _drawLiveIndicator(Canvas canvas, Size size, double y) {
    final time = DateTime.now().millisecondsSinceEpoch;
    final pulse = (sin(time / 200) + 1) / 2; // 0.0 to 1.0
    
    // Dot
    canvas.drawCircle(
      Offset(10, y + 3),
      2,
      Paint()..color = color.withOpacity(0.5 + pulse * 0.5),
    );
    
    // Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'LIVE',
        style: TextStyle(
          color: color.withOpacity(0.8),
          fontSize: 6,
          fontWeight: FontWeight.w900,
          fontFamily: 'Courier',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(16, y));
  }
  
  @override
  bool shouldRepaint(ForensicDataPainter oldDelegate) {
    return oldDelegate.motionCount != motionCount ||
        oldDelegate.touchCount != touchCount ||
        oldDelegate.entropy != entropy ||
        oldDelegate.confidence != confidence;
  }
}
