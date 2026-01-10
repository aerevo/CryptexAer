// 🔐 Z-KINETIC SECURITY ENGINE V5.0 — PRODUCTION GRADE
// Tightened security with realistic human thresholds
// Zero tolerance for bots, fair for humans

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
    // PRODUCTION THRESHOLDS (Balanced - not too strict, not too lenient)
    this.minEntropy = 0.35,           // Prevent repetitive patterns
    this.minVariance = 0.02,          // Ensure natural variation
    this.minConfidence = 0.55,        // Overall human confidence
    this.minMotionPresence = 0.12,    // Minimum motion required
    this.minTouchPresence = 0.20,     // Minimum touch interaction
  });

  /// Development mode (lenient for testing)
  factory SecurityEngineConfig.development() {
    return const SecurityEngineConfig(
      minEntropy: 0.25,
      minVariance: 0.015,
      minConfidence: 0.45,
      minMotionPresence: 0.08,
      minTouchPresence: 0.15,
    );
  }

  /// Production mode (strict)
  factory SecurityEngineConfig.production() {
    return const SecurityEngineConfig(
      minEntropy: 0.45,
      minVariance: 0.03,
      minConfidence: 0.65,
      minMotionPresence: 0.15,
      minTouchPresence: 0.25,
    );
  }

  /// Maximum security (very strict - bank grade)
  factory SecurityEngineConfig.maximum() {
    return const SecurityEngineConfig(
      minEntropy: 0.55,
      minVariance: 0.04,
      minConfidence: 0.75,
      minMotionPresence: 0.20,
      minTouchPresence: 0.30,
    );
  }
}

/// 🧠 Stateful Threat Engine (Production Grade)
class SecurityEngine {
  final SecurityEngineConfig config;

  // Threat escalation memory (persists across attempts)
  double _threatScore = 0.0;
  int _consecutiveLowEntropy = 0;
  int _consecutiveLowVariance = 0;

  SecurityEngine(this.config);

  /// Reset threat memory (call after successful unlock)
  void reset() {
    _threatScore = 0.0;
    _consecutiveLowEntropy = 0;
    _consecutiveLowVariance = 0;
  }

  ThreatVerdict analyze({
    required double motionConfidence,
    required double touchConfidence,
    required List<MotionEvent> motionHistory,
    required int touchCount,
  }) {
    // ───────────────────────────────
    // 0. Presence Gate
    // ───────────────────────────────
    if (motionConfidence < config.minMotionPresence && 
        touchConfidence < config.minTouchPresence) {
      _escalate(0.4, severe: true);
      return ThreatVerdict.deny(
        ThreatLevel.HIGH,
        'NO_HUMAN_PRESENCE_DETECTED',
      );
    }

    // ───────────────────────────────
    // 1. Motion Metrics Analysis
    // ───────────────────────────────
    final metrics = _computeMetrics(motionHistory);

    // Entropy check (prevents scripted patterns)
    if (metrics.entropy < config.minEntropy) {
      _consecutiveLowEntropy++;
      _escalate(0.25);
      
      // Escalate if repeatedly low
      if (_consecutiveLowEntropy >= 2) {
        return ThreatVerdict.deny(
          ThreatLevel.HIGH,
          'SCRIPTED_PATTERN_DETECTED',
        );
      }
      
      return ThreatVerdict.deny(
        ThreatLevel.MEDIUM,
        'LOW_ENTROPY_PATTERN',
      );
    } else {
      _consecutiveLowEntropy = 0;
    }

    // Variance check (prevents robotic uniformity)
    if (metrics.variance < config.minVariance) {
      _consecutiveLowVariance++;
      _escalate(0.30);
      
      if (_consecutiveLowVariance >= 2) {
        return ThreatVerdict.deny(
          ThreatLevel.CRITICAL,
          'ROBOTIC_SIGNATURE_DETECTED',
        );
      }
      
      return ThreatVerdict.deny(
        ThreatLevel.MEDIUM,
        'SUSPICIOUS_MOTION_UNIFORMITY',
      );
    } else {
      _consecutiveLowVariance = 0;
    }

    // ───────────────────────────────
    // 2. Tremor Validation (Human Physiology)
    // ───────────────────────────────
    if (motionHistory.length >= 10) {
      if (!_validTremor(metrics.tremorHz)) {
        _escalate(0.20);
        
        // Critical if completely absent or impossibly fast
        if (metrics.tremorHz == 0.0 || metrics.tremorHz > 20.0) {
          return ThreatVerdict.deny(
            ThreatLevel.CRITICAL,
            'NON_HUMAN_TREMOR_SIGNATURE',
          );
        }
        
        return ThreatVerdict.deny(
          ThreatLevel.MEDIUM,
          'ABNORMAL_TREMOR_PATTERN',
        );
      }
    }

    // ───────────────────────────────
    // 3. Final Confidence Score
    // ───────────────────────────────
    final confidence = _finalScore(
      motionConfidence,
      touchConfidence,
      metrics.entropy,
      metrics.variance,
    );

    if (confidence < config.minConfidence) {
      _escalate(0.25);
      return ThreatVerdict.deny(
        ThreatLevel.MEDIUM,
        'INSUFFICIENT_HUMAN_CONFIDENCE',
      );
    }

    // ───────────────────────────────
    // SUCCESS — Decay threat memory
    // ───────────────────────────────
    _threatScore = (_threatScore * 0.6).clamp(0.0, 1.0);

    return ThreatVerdict.allow(confidence);
  }

  // ════════════════════════════════════════════════
  // INTERNALS
  // ════════════════════════════════════════════════

  void _escalate(double weight, {bool severe = false}) {
    final multiplier = severe ? 1.5 : 1.0;
    _threatScore = (_threatScore + (weight * multiplier)).clamp(0.0, 1.0);
  }

  bool _validTremor(double hz) {
    // Human physiological tremor: 5-16 Hz
    // Slightly wider than medical range (8-12 Hz) for mobile tolerance
    return hz >= 5.0 && hz <= 16.0;
  }

  double _finalScore(double m, double t, double e, double v) {
    // Normalized components
    final entropyNorm = (e / 3.0).clamp(0.0, 1.0);
    final varianceNorm = (v / 0.1).clamp(0.0, 1.0);
    
    // Weighted combination
    final base = (m * 0.35) +           // Motion importance
                 (t * 0.35) +           // Touch importance
                 (entropyNorm * 0.15) + // Pattern diversity
                 (varianceNorm * 0.15); // Natural variation
    
    // Apply threat penalty (adaptive)
    final penalty = _threatScore * 0.35;
    
    return (base - penalty).clamp(0.0, 1.0);
  }

  _MotionMetrics _computeMetrics(List<MotionEvent> history) {
    if (history.length < 6) {
      // Not enough data - return neutral values
      return _MotionMetrics(
        entropy: 0.5,
        variance: 0.03,
        tremorHz: 10.0,
      );
    }

    final mags = history.map((e) => e.magnitude).toList();
    final mean = mags.reduce((a, b) => a + b) / mags.length;

    // Variance calculation
    final variance = mags
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        mags.length;

    // Shannon Entropy (information theory)
    final freq = <int, int>{};
    for (var m in mags) {
      final bucket = (m * 12).floor().clamp(0, 20);
      freq[bucket] = (freq[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    for (var c in freq.values) {
      final p = c / mags.length;
      if (p > 0) {
        entropy -= p * log(p) / ln2;
      }
    }

    // Tremor frequency analysis
    int validTremorEvents = 0;
    int totalMs = 0;

    for (int i = 1; i < history.length; i++) {
      final dt = history[i]
          .timestamp
          .difference(history[i - 1].timestamp)
          .inMilliseconds;
      
      if (dt > 0) {
        totalMs += dt;
        
        // Human tremor timing: 60-200ms between micro-movements
        if (dt >= 60 && dt <= 200) {
          validTremorEvents++;
        }
      }
    }

    final seconds = totalMs / 1000.0;
    final hz = seconds > 0.1 ? validTremorEvents / seconds : 0.0;

    return _MotionMetrics(
      entropy: entropy,
      variance: variance,
      tremorHz: hz,
    );
  }
}

class _MotionMetrics {
  final double entropy;
  final double variance;
  final double tremorHz;

  _MotionMetrics({
    required this.entropy,
    required this.variance,
    required this.tremorHz,
  });
}
