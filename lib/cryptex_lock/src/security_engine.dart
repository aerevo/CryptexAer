// SECURITY ENGINE V6.0 (ENTERPRISE READY)

import 'dart:math';
import 'motion_models.dart';
import 'cla_models.dart';

enum ThreatLevel { SAFE, SUSPICIOUS, HIGH_RISK, CRITICAL }

class ThreatVerdict {
  final bool allowed;
  final ThreatLevel level;
  final String reason;
  final double confidence;
  final double riskScore;

  final double entropyScore;
  final double varianceScore;

  const ThreatVerdict({
    required this.allowed,
    required this.level,
    required this.reason,
    required this.confidence,
    required this.riskScore,
    this.entropyScore = 0.0,
    this.varianceScore = 0.0,
  });

  factory ThreatVerdict.allow(double confidence, {double entropy = 0, double variance = 0}) {
    return ThreatVerdict(
      allowed: true,
      level: ThreatLevel.SAFE,
      reason: 'VERIFIED',
      confidence: confidence,
      riskScore: (1.0 - confidence) * 100,
      entropyScore: entropy,
      varianceScore: variance,
    );
  }

  factory ThreatVerdict.flag(ThreatLevel level, String reason, {double entropy = 0, double risk = 100}) {
    return ThreatVerdict(
      allowed: false,
      level: level,
      reason: reason,
      confidence: 0.0,
      riskScore: risk,
      entropyScore: entropy,
    );
  }
}

class SecurityEngine {
  // ============================================
  // 🔧 FIX: NAMED CONSTANTS (No Magic Numbers!)
  // ============================================
  
  /// Minimum interaction time to prevent bot speed attacks (milliseconds)
  static const int MIN_INTERACTION_TIME_MS = 200;
  
  /// Minimum motion data points required for analysis
  static const int MIN_MOTION_SAMPLES = 1;
  
  /// Minimum touch count for non-motion verification
  static const int MIN_TOUCH_COUNT = 1;
  
  // SCORING WEIGHTS (Must sum to 1.0)
  /// Weight for entropy contribution (tremor/variation)
  static const double ENTROPY_WEIGHT = 0.40;
  
  /// Weight for variance contribution (motion jitter)
  static const double VARIANCE_WEIGHT = 0.30;
  
  /// Weight for touch interaction contribution
  static const double TOUCH_WEIGHT = 0.30;
  
  // NORMALIZATION FACTORS
  /// Typical Shannon entropy range for motion data
  static const double ENTROPY_NORMALIZATION = 4.0;
  
  /// Typical variance range for human motion
  static const double VARIANCE_NORMALIZATION = 10.0;
  
  /// Touch count normalization (10 touches = 100% score)
  static const double TOUCH_NORMALIZATION = 10.0;
  
  // THRESHOLDS
  /// Entropy threshold for detecting perfect repetition (bot signature)
  static const double ZERO_ENTROPY_THRESHOLD = 0.001;
  
  /// Minimum touch count when entropy is near zero
  static const int MIN_TOUCH_FOR_ZERO_ENTROPY = 3;

  final SecurityEngineConfig config;
  final Random _rng = Random();

  double _lastEntropy = 0.0;
  double _lastConfidence = 0.0;

  SecurityEngine(this.config);

  double get lastEntropyScore => _lastEntropy;
  double get lastConfidenceScore => _lastConfidence;

  ThreatVerdict analyze({
    required List<MotionEvent> motionHistory,
    required int touchCount,
    required Duration interactionDuration,
  }) {
    
    // 1. SPEED CHECK (Anti-Bot)
    if (interactionDuration.inMilliseconds < MIN_INTERACTION_TIME_MS) {
      return _recordVerdict(ThreatVerdict.flag(ThreatLevel.HIGH_RISK, 'TOO_FAST', risk: 80));
    }

    // 2. DATA SOURCE CHECK
    if (motionHistory.isEmpty) {
      if (touchCount > 0) {
        // Phone on table scenario - OK with touch input
        return _recordVerdict(ThreatVerdict.allow(0.7));
      }
      return _recordVerdict(ThreatVerdict.flag(ThreatLevel.CRITICAL, 'NO_DATA', risk: 100));
    }

    // 3. BIOMETRIC ANALYSIS
    final entropy = _calculateEntropy(motionHistory);
    final variance = _calculateVariance(motionHistory);
    _lastEntropy = entropy;

    // 4. BOT DETECTION (Perfect repetition check)
    if (entropy <= ZERO_ENTROPY_THRESHOLD && touchCount < MIN_TOUCH_FOR_ZERO_ENTROPY) {
      return _recordVerdict(ThreatVerdict.flag(ThreatLevel.HIGH_RISK, 'ROBOTIC', entropy: entropy, risk: 95));
    }

    // 5. WEIGHTED SCORING
    double score = _calculateWeightedScore(entropy, variance, touchCount);
    _lastConfidence = score;

    // 6. THRESHOLD CHECK
    if (score < config.botThreshold) {
      return _recordVerdict(ThreatVerdict.flag(
        ThreatLevel.SUSPICIOUS,
        'LOW_CONFIDENCE',
        entropy: entropy,
        risk: (1.0 - score) * 100
      ));
    }

    return _recordVerdict(ThreatVerdict.allow(score, entropy: entropy, variance: variance));
  }

  /// Calculate final confidence score using weighted components
  double _calculateWeightedScore(double entropy, double variance, int touchCount) {
    double score = 0.0;

    // Entropy contribution (max ENTROPY_WEIGHT)
    final normalizedEntropy = (entropy * config.minConfidence).clamp(0.0, 1.0);
    score += normalizedEntropy * ENTROPY_WEIGHT;

    // Variance contribution (max VARIANCE_WEIGHT)
    final normalizedVariance = (variance * VARIANCE_NORMALIZATION).clamp(0.0, 1.0);
    score += normalizedVariance * VARIANCE_WEIGHT;

    // Touch contribution (max TOUCH_WEIGHT)
    if (touchCount > 0) {
      final normalizedTouch = min(touchCount / TOUCH_NORMALIZATION, 1.0);
      score += normalizedTouch * TOUCH_WEIGHT;
    }

    return score.clamp(0.0, 1.0);
  }

  ThreatVerdict _recordVerdict(ThreatVerdict v) {
    return v;
  }

  /// Calculate Shannon Entropy (measures randomness/variation)
  /// High entropy = natural human tremor
  /// Low entropy = robotic repetition
  double _calculateEntropy(List<MotionEvent> history) {
    if (history.isEmpty) return 0.0;

    final mags = history.map((e) => e.magnitude).toList();

    // Bucket magnitudes into ranges
    final Map<int, int> distribution = {};
    for (var mag in mags) {
      int bucket = (mag * 10).round();
      distribution[bucket] = (distribution[bucket] ?? 0) + 1;
    }

    // Shannon entropy formula: -Σ(p * log2(p))
    double entropy = 0.0;
    int total = mags.length;

    distribution.forEach((_, count) {
      double probability = count / total;
      if (probability > 0) {
        entropy -= probability * (log(probability) / log(2));
      }
    });

    // Normalize to 0-1 range
    return (entropy / ENTROPY_NORMALIZATION).clamp(0.0, 1.0);
  }

  /// Calculate Variance (measures motion jitter)
  /// High variance = natural hand shake
  /// Low variance = steady robotic movement
  double _calculateVariance(List<MotionEvent> history) {
    if (history.length < 2) return 0.0;

    final magnitudes = history.map((e) => e.magnitude).toList();

    // Calculate mean
    double sum = magnitudes.reduce((a, b) => a + b);
    double mean = sum / magnitudes.length;

    // Calculate variance: average of squared differences from mean
    double sumSquaredDiff = 0.0;
    for (var mag in magnitudes) {
      sumSquaredDiff += pow(mag - mean, 2);
    }

    double variance = sumSquaredDiff / magnitudes.length;

    // Normalize (typical variance ≈ 0.01-0.1)
    return (variance * VARIANCE_NORMALIZATION).clamp(0.0, 1.0);
  }
}
