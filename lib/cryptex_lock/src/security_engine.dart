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
  final double minEntropy;
  final double minVariance;
  final double minConfidence;
  final double minMotionPresence;
  final double minTouchPresence;

  const SecurityEngineConfig({
    this.minEntropy = 0.35,
    this.minVariance = 0.02,
    this.minConfidence = 0.55,
    this.minMotionPresence = 0.1,
    this.minTouchPresence = 0.1,
  });
}

class SecurityEngine {
  final SecurityEngineConfig config;
  
  // Public Variable untuk UI Getters (Local Only)
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
    // 1. Check Presence
    if (motionConfidence < config.minMotionPresence && 
        touchConfidence < config.minTouchPresence) {
      lastConfidenceScore = 0.1; 
      lastEntropyScore = 0.0;
      return ThreatVerdict.deny(ThreatLevel.HIGH, 'NO_HUMAN_PRESENCE');
    }

    // 2. Compute Metrics
    final metrics = _computeMetrics(motionHistory);
    lastEntropyScore = metrics.entropy;
    
    // 3. Evaluate Metrics (Real-time Validation)
    if (metrics.entropy < config.minEntropy) {
      lastConfidenceScore = 0.3;
      return ThreatVerdict.deny(ThreatLevel.MEDIUM, 'LOW_ENTROPY_PATTERN');
    }

    if (metrics.variance < config.minVariance) {
      lastConfidenceScore = 0.2;
      return ThreatVerdict.deny(ThreatLevel.CRITICAL, 'ROBOTIC_SIGNATURE');
    }

    if (!_validTremor(metrics.tremorHz)) {
      lastConfidenceScore = 0.4;
      return ThreatVerdict.deny(ThreatLevel.CRITICAL, 'INVALID_TREMOR');
    }

    // Final Score Calculation
    double finalScore = (metrics.entropy * 0.4) + 
                       (motionConfidence * 0.3) + 
                       (touchConfidence * 0.3);
    
    lastConfidenceScore = finalScore;

    if (finalScore < config.minConfidence) {
      return ThreatVerdict.deny(ThreatLevel.MEDIUM, 'LOW_CONFIDENCE');
    }

    return ThreatVerdict.allow(finalScore);
  }

  // --- Internal Helpers ---
  
  _Metrics _computeMetrics(List<MotionEvent> history) {
    if (history.isEmpty) return _Metrics(0, 0, 0);

    final mags = history.map((e) => e.magnitude).toList();
    final mean = mags.reduce((a, b) => a + b) / mags.length;

    // Variance calculation
    final variance = mags
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        mags.length;

    // Entropy calculation
    final freq = <int, int>{};
    for (var m in mags) {
      final bucket = (m * 12).floor().clamp(0, 20);
      freq[bucket] = (freq[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    for (var c in freq.values) {
      final p = c / mags.length;
      if (p > 0) entropy -= p * log(p) / ln2;
    }
    entropy = (entropy / 3.0).clamp(0.0, 1.0);

    // 🔥 TREMOR LOGIC RESTORED (FULL MATH) 🔥
    int validTremorEvents = 0;
    int totalMs = 0;

    for (int i = 1; i < history.length; i++) {
      final dt = history[i]
          .timestamp
          .difference(history[i - 1].timestamp)
          .inMilliseconds;
      
      if (dt > 0) {
        totalMs += dt;
        // Frequency of human micro-tremors (60ms to 200ms)
        if (dt >= 60 && dt <= 200) {
          validTremorEvents++;
        }
      }
    }

    final seconds = totalMs / 1000.0;
    double tremorHz = seconds > 0.1 ? validTremorEvents / seconds : 0.0;

    return _Metrics(entropy, variance, tremorHz);
  }

  bool _validTremor(double hz) {
    // Human tremor range: 0.5Hz to 20Hz
    return hz >= 0.5 && hz <= 20.0; 
  }
}

class _Metrics {
  final double entropy;
  final double variance;
  final double tremorHz;
  _Metrics(this.entropy, this.variance, this.tremorHz);
}
