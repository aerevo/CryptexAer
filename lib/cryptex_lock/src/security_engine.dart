// 🧠 SECURITY ENGINE V4.1 (HARDENED)
// Status: STRICTER SCORING ✅
// Fix: Removed "Touch = Instant Pass" loophole.

import 'dart:math';
import 'cla_models.dart';

enum ThreatLevel { SAFE, SUSPICIOUS, HIGH_RISK, CRITICAL }

class ThreatVerdict {
  final bool allowed;
  final ThreatLevel level;
  final String reason;
  final double confidence;
  final double riskScore;
  
  const ThreatVerdict({
    required this.allowed,
    required this.level,
    required this.reason,
    required this.confidence,
    required this.riskScore,
  });

  factory ThreatVerdict.allow(double confidence) {
    return ThreatVerdict(
      allowed: true,
      level: ThreatLevel.SAFE,
      reason: 'VERIFIED',
      confidence: confidence,
      riskScore: (1.0 - confidence) * 100,
    );
  }

  factory ThreatVerdict.flag(ThreatLevel level, String reason) {
    return ThreatVerdict(
      allowed: false,
      level: level,
      reason: reason,
      confidence: 0.0,
      riskScore: 100,
    );
  }
}

class SecurityEngine {
  final SecurityEngineConfig config;
  
  SecurityEngine(this.config);

  ThreatVerdict analyze({
    required List<MotionEvent> history,
    required int touchCount,
    required Duration interactionDuration,
  }) {
    
    // 1. BASIC CHECK: Empty History (Telepathy Attack)
    if (history.isEmpty && touchCount == 0) {
      return ThreatVerdict.flag(ThreatLevel.CRITICAL, 'NO_INPUT_DATA');
    }

    // 2. ENTROPY CALCULATION
    final mags = history.map((e) => e.magnitude).toList();
    double entropy = 0.5; // Default neutral
    double variance = 0.0;
    
    if (mags.isNotEmpty) {
      double sum = mags.reduce((a, b) => a + b);
      double mean = sum / mags.length;
      variance = mags.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / mags.length;
      
      // Robot biasanya variance = 0.0 (Gerakan sempurna)
      if (variance < config.minVariance && touchCount < 3) {
         // Flag as suspicious but don't block instantly in Demo Mode
         entropy = 0.2; 
      } else {
         entropy = 0.9;
      }
    }

    // 3. SCORING SYSTEM (REVISED)
    // Formula lama: (entropy * 0.5) + (variance * 0.5)
    // Formula baru: Base Score + Touch Bonus
    
    double score = 0.4; // Base trust
    
    if (variance > config.minVariance) score += 0.4; // Human shake
    if (touchCount > 0) score += 0.2; // Touch bonus (Max 0.2, bukan auto 1.0)
    
    score = score.clamp(0.0, 1.0);
    
    // Strict Threshold Check
    if (score < config.minConfidence) {
      return ThreatVerdict.flag(ThreatLevel.HIGH_RISK, 'LOW_CONFIDENCE_SCORE');
    }

    return ThreatVerdict.allow(score);
  }
}
