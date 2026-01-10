// 🔐 PROJECT Z-KINETIC V4.1 — PRODUCTION TUNED
// Fixed: Relaxed thresholds for real human interaction
// Pure Logic • Deterministic • Zero-UI

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

  const SecurityEngineConfig({
    this.minEntropy = 0.25,      // Relaxed from 0.6 to 0.25
    this.minVariance = 0.015,    // Relaxed from 0.04 to 0.015
    this.minConfidence = 0.45,   // Relaxed from 0.75 to 0.45
  });
}

/// 🧠 Stateful Threat Engine (Production Tuned)
class SecurityEngine {
  final SecurityEngineConfig config;

  // Escalation memory
  double _threatScore = 0.0;

  SecurityEngine(this.config);

  ThreatVerdict analyze({
    required double motionConfidence,
    required double touchConfidence,
    required List<MotionEvent> motionHistory,
    required int touchCount,
  }) {
    // ───────────────────────────────
    // 0. Hard Presence Gate (RELAXED)
    // ───────────────────────────────
    if (motionConfidence < 0.08 && touchConfidence < 0.15) {
      _escalate(0.3);
      return ThreatVerdict.deny(
        ThreatLevel.HIGH,
        'NO_HUMAN_PRESENCE',
      );
    }

    // ───────────────────────────────
    // 1. Motion Metrics (LENIENT)
    // ───────────────────────────────
    final metrics = _computeMetrics(motionHistory);

    if (metrics.entropy < config.minEntropy) {
      _escalate(0.15); // Reduced penalty
      return ThreatVerdict.deny(
        ThreatLevel.LOW, // Downgraded from MEDIUM
        'LOW_ENTROPY_PATTERN',
      );
    }

    if (metrics.variance < config.minVariance) {
      _escalate(0.2); // Reduced penalty
      return ThreatVerdict.deny(
        ThreatLevel.MEDIUM, // Downgraded from HIGH
        'ROBOTIC_MOTION_VARIANCE',
      );
    }

    // ───────────────────────────────
    // CRITICAL FIX: Tremor Validation
    // ───────────────────────────────
    // Only check if we have enough data
    if (motionHistory.length >= 10) {
      if (!_validTremor(metrics.tremorHz)) {
        // Don't block immediately - just warn
        _escalate(0.1); // Very small penalty
        
        // Only block if tremor is EXTREMELY off (0 or very high)
        if (metrics.tremorHz == 0.0 || metrics.tremorHz > 25.0) {
          return ThreatVerdict.deny(
            ThreatLevel.MEDIUM, // Downgraded from CRITICAL
            'NON_HUMAN_TREMOR_SIGNATURE',
          );
        }
      }
    }

    // ───────────────────────────────
    // 2. Final Confidence (RELAXED)
    // ───────────────────────────────
    final confidence = _finalScore(
      motionConfidence,
      touchConfidence,
      metrics.entropy,
    );

    if (confidence < config.minConfidence) {
      _escalate(0.15); // Reduced penalty
      return ThreatVerdict.deny(
        ThreatLevel.LOW, // Downgraded from MEDIUM
        'CONFIDENCE_TOO_LOW',
      );
    }

    // ───────────────────────────────
    // SUCCESS — decay threat memory
    // ───────────────────────────────
    _threatScore = (_threatScore * 0.5).clamp(0.0, 1.0); // Faster decay

    return ThreatVerdict.allow(confidence);
  }

  // ════════════════════════════════════════════════
  // INTERNALS
  // ════════════════════════════════════════════════

  void _escalate(double weight) {
    _threatScore = (_threatScore + weight).clamp(0.0, 1.0);
  }

  bool _validTremor(double hz) {
    // RELAXED: Human physiological tremor range
    // Original: 7.5-13.5 Hz (too strict!)
    // New: 4.0-18.0 Hz (realistic for mobile interaction)
    return hz >= 4.0 && hz <= 18.0;
  }

  double _finalScore(double m, double t, double e) {
    final entropyNorm = (e / 3.0).clamp(0.0, 1.0);
    
    // Adjusted weights - give more credit to motion/touch
    final base = (m * 0.45) + (t * 0.40) + (entropyNorm * 0.15);
    
    // Reduced threat score impact
    return (base - _threatScore * 0.2).clamp(0.0, 1.0);
  }

  _MotionMetrics _computeMetrics(List<MotionEvent> history) {
    if (history.length < 6) {
      // Return permissive defaults when not enough data
      return _MotionMetrics(
        entropy: 1.0,    // High entropy = good
        variance: 0.5,   // Reasonable variance
        tremorHz: 10.0,  // Middle of range
      );
    }

    final mags = history.map((e) => e.magnitude).toList();
    final mean = mags.reduce((a, b) => a + b) / mags.length;

    final variance = mags
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        mags.length;

    // Shannon Entropy (unchanged - this is correct)
    final freq = <int, int>{};
    for (var m in mags) {
      final bucket = (m * 12).floor();
      freq[bucket] = (freq[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    for (var c in freq.values) {
      final p = c / mags.length;
      if (p > 0) {
        entropy -= p * log(p) / ln2;
      }
    }

    // Tremor frequency (RELAXED calculation)
    int valid = 0;
    int totalMs = 0;

    for (int i = 1; i < history.length; i++) {
      final dt = history[i]
          .timestamp
          .difference(history[i - 1].timestamp)
          .inMilliseconds;
      
      if (dt > 0) {
        totalMs += dt;
        // RELAXED: Accept wider range of timing intervals
        if (dt >= 50 && dt <= 200) {  // Was 70-140, now 50-200
          valid++;
        }
      }
    }

    final seconds = totalMs / 1000.0;
    final hz = seconds > 0.1 ? valid / seconds : 10.0; // Default to safe value

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
