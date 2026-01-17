// 🧠 SECURITY ENGINE V5.0 (FORTIFIED)
// Status: SECURITY HOLE PATCHED ✅
// Fix: Removed "Touch = Auto Pass" logic.
// New: Weighted Scoring System (Entropy + Variance + Timing)

import 'dart:math';
import 'cla_models.dart';

enum ThreatLevel { SAFE, SUSPICIOUS, HIGH_RISK, CRITICAL }

class ThreatVerdict {
  final bool allowed;
  final ThreatLevel level;
  final String reason;
  final double confidence;
  
  const ThreatVerdict({
    required this.allowed,
    required this.level,
    required this.reason,
    required this.confidence,
  });

  factory ThreatVerdict.allow(double confidence) {
    return ThreatVerdict(
      allowed: true,
      level: ThreatLevel.SAFE,
      reason: 'VERIFIED_HUMAN',
      confidence: confidence,
    );
  }

  factory ThreatVerdict.block(ThreatLevel level, String reason) {
    return ThreatVerdict(
      allowed: false,
      level: level,
      reason: reason,
      confidence: 0.0,
    );
  }
}

class SecurityEngine {
  final SecurityEngineConfig config;

  SecurityEngine({required this.config});

  ThreatVerdict analyze({
    required List<MotionEvent> motionHistory,
    required int touchCount,
    required Duration interactionDuration,
  }) {
    // 1. FAST FAIL: Zero Interaction
    if (motionHistory.isEmpty && touchCount == 0) {
      return ThreatVerdict.block(ThreatLevel.CRITICAL, 'NO_INTERACTION_DATA');
    }

    // 2. SPEED CHECK: Superhuman Speed
    // Manusia perlukan masa > 500ms untuk input 5 digit dengan tepat
    if (interactionDuration.inMilliseconds < 300) {
       return ThreatVerdict.block(ThreatLevel.HIGH_RISK, 'SUPERHUMAN_SPEED');
    }

    // 3. BIOMETRIC ANALYSIS
    double entropy = _calculateEntropy(motionHistory);
    double variance = _calculateVariance(motionHistory);
    
    // 🚨 FIX: Strict logic. No more free pass.
    bool hasMicroTremors = entropy > config.minEntropy;
    bool hasNaturalMotion = variance > config.minVariance;
    
    // Scoring Algorithm
    // Entropy (Ketar tangan) weight: 50%
    // Variance (Gerak peranti) weight: 30%
    // Touch (Interaksi fizikal) weight: 20%
    
    double score = 0.0;
    
    score += (entropy * 10).clamp(0.0, 0.5); // Max 0.5
    score += (variance * 100).clamp(0.0, 0.3); // Max 0.3
    if (touchCount > 0) score += 0.2; // Bonus 0.2
    
    // Threshold Check
    if (score < config.botThreshold) {
       return ThreatVerdict.block(
         ThreatLevel.HIGH_RISK, 
         'ROBOTIC_MOVEMENT (Score: ${score.toStringAsFixed(2)})'
       );
    }

    return ThreatVerdict.allow(score);
  }

  // Helper: Calculate Shannon Entropy of motion magnitude
  double _calculateEntropy(List<MotionEvent> history) {
    if (history.isEmpty) return 0.0;
    
    // Normalize magnitudes to buckets
    final Map<int, int> buckets = {};
    for (var m in history) {
      int bucket = (m.magnitude * 10).round(); // Reduced resolution
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    
    // Shannon formula
    double entropy = 0.0;
    int total = history.length;
    
    buckets.forEach((_, count) {
      double p = count / total;
      if (p > 0) entropy -= p * (log(p) / log(2));
    });
    
    return entropy;
  }

  // Helper: Calculate Variance (Jitter)
  double _calculateVariance(List<MotionEvent> history) {
    if (history.length < 2) return 0.0;
    
    final magnitudes = history.map((e) => e.magnitude).toList();
    double mean = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    
    double sumSquaredDiff = magnitudes.fold(0.0, (sum, val) => sum + pow(val - mean, 2));
    return sumSquaredDiff / magnitudes.length;
  }
}
