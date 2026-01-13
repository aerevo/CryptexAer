import 'dart:math';
import 'cla_models.dart';

enum ThreatLevel { NONE, LOW, MEDIUM, HIGH, CRITICAL }

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
      level: ThreatLevel.NONE,
      reason: 'HUMAN_SIGNATURE_CONFIRMED',
      confidence: confidence,
    );
  }

  factory ThreatVerdict.deny(ThreatLevel level, String reason) {
    return ThreatVerdict(
      allowed: false,
      level: level,
      reason: reason,
      confidence: 0.0,
    );
  }
}

class SecurityEngineConfig {
  // 🔥 RELAXED THRESHOLDS - Human Friendly
  final double minEntropy;
  final double minVariance;
  final double minConfidence;
  final double minMotionPresence;
  final double minTouchPresence;

  const SecurityEngineConfig({
    this.minEntropy = 0.15,        // ✅ LOWERED (was 0.35)
    this.minVariance = 0.005,      // ✅ LOWERED (was 0.02)
    this.minConfidence = 0.30,     // ✅ LOWERED (was 0.55)
    this.minMotionPresence = 0.05, // ✅ LOWERED (was 0.1)
    this.minTouchPresence = 0.05,  // ✅ LOWERED (was 0.1)
  });
}

class SecurityEngine {
  final SecurityEngineConfig config;
  
  // Public Variable untuk UI Getters
  double lastEntropyScore = 0.0;
  double lastConfidenceScore = 0.0;

  SecurityEngine(this.config);

  void dispose() {
    lastEntropyScore = 0.0;
    lastConfidenceScore = 0.0;
  }

  ThreatVerdict analyze({
    required double motionConfidence,
    required double touchConfidence,
    required List<MotionEvent> motionHistory,
    required int touchCount,
  }) {
    // 🔥 STEP 1: Basic Presence Check (RELAXED)
    // Only block if BOTH are extremely low (obvious bot)
    if (motionConfidence < 0.01 && touchConfidence < 0.5) {
      lastConfidenceScore = 0.1; 
      lastEntropyScore = 0.0;
      return ThreatVerdict.deny(ThreatLevel.HIGH, 'NO_INTERACTION_DETECTED');
    }

    // 🔥 STEP 2: Compute Metrics (but be forgiving)
    final metrics = _computeMetrics(motionHistory);
    lastEntropyScore = metrics.entropy;
    
    // 🔥 STEP 3: RELAXED Validation (Only block extreme cases)
    
    // Entropy check - only fail if extremely low
    if (motionHistory.length > 5 && metrics.entropy < 0.05) {
      lastConfidenceScore = 0.2;
      return ThreatVerdict.deny(ThreatLevel.MEDIUM, 'EXTREMELY_LOW_ENTROPY');
    }

    // Variance check - only fail if perfectly static (robot signature)
    if (motionHistory.length > 5 && metrics.variance < 0.001) {
      lastConfidenceScore = 0.15;
      return ThreatVerdict.deny(ThreatLevel.HIGH, 'PERFECT_STABILITY_DETECTED');
    }

    // Tremor check - allow wide range (humans vary a lot)
    if (motionHistory.length > 5 && !_validTremor(metrics.tremorHz)) {
      // Don't block, just lower confidence
      lastConfidenceScore = 0.4;
      // Still allow, just log it
    }

    // 🔥 STEP 4: Final Score (Generous Calculation)
    double finalScore = 0.0;
    
    // If we have good motion, give high weight
    if (motionConfidence > 0.2) {
      finalScore = (motionConfidence * 0.5) + 
                   (touchConfidence * 0.3) + 
                   (metrics.entropy * 0.2);
    } else {
      // Even with low motion, if touch is good, still pass
      finalScore = (touchConfidence * 0.6) + 
                   (motionConfidence * 0.2) + 
                   (metrics.entropy * 0.2);
    }
    
    lastConfidenceScore = finalScore.clamp(0.0, 1.0);

    // Very low bar - only fail extreme cases
    if (finalScore < 0.20) {
      return ThreatVerdict.deny(ThreatLevel.MEDIUM, 'CONFIDENCE_BELOW_MINIMUM');
    }

    // ✅ ALLOW - Human behavior detected
    return ThreatVerdict.allow(finalScore);
  }

  // --- Internal Helpers ---
  
  _Metrics _computeMetrics(List<MotionEvent> history) {
    if (history.isEmpty || history.length < 2) {
      return _Metrics(0.5, 0.01, 5.0); // ✅ Default "reasonable" values
    }

    final mags = history.map((e) => e.magnitude).toList();
    final mean = mags.reduce((a, b) => a + b) / mags.length;

    // Variance calculation (with safety check)
    double variance = 0.0;
    try {
      variance = mags
              .map((x) => pow(x - mean, 2))
              .reduce((a, b) => a + b) /
          mags.length;
    } catch (e) {
      variance = 0.01; // Safe default
    }

    // Entropy calculation (simplified)
    final freq = <int, int>{};
    for (var m in mags) {
      final bucket = (m * 10).floor().clamp(0, 15);
      freq[bucket] = (freq[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    try {
      for (var c in freq.values) {
        final p = c / mags.length;
        if (p > 0) entropy -= p * log(p) / ln2;
      }
      entropy = (entropy / 2.5).clamp(0.0, 1.0); // ✅ More generous scaling
    } catch (e) {
      entropy = 0.5; // Safe default
    }

    // Tremor calculation (very forgiving)
    int validTremorEvents = 0;
    int totalMs = 0;

    for (int i = 1; i < history.length; i++) {
      final dt = history[i]
          .timestamp
          .difference(history[i - 1].timestamp)
          .inMilliseconds;
      
      if (dt > 0 && dt < 1000) { // Ignore huge gaps
        totalMs += dt;
        // Very wide range for human tremor (30ms to 500ms)
        if (dt >= 30 && dt <= 500) {
          validTremorEvents++;
        }
      }
    }

    final seconds = totalMs / 1000.0;
    double tremorHz = seconds > 0.05 ? validTremorEvents / seconds : 2.0; // Default 2Hz

    return _Metrics(entropy, variance, tremorHz);
  }

  bool _validTremor(double hz) {
    // VERY WIDE range - almost always pass
    // Human tremor: 0.2Hz to 30Hz (extremely forgiving)
    return hz >= 0.2 && hz <= 30.0; 
  }
}

class _Metrics {
  final double entropy;
  final double variance;
  final double tremorHz;
  _Metrics(this.entropy, this.variance, this.tremorHz);
}
