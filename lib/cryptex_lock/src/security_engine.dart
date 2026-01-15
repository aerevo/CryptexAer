// 🧠 SECURITY ENGINE V3.9 - HUMAN FRIENDLY MODE
// Status: "STEADY HAND" LOGIC ENABLED ✅
// Logic: If user touches screen, assume human even if motion is low.

import 'dart:math';
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
      reason: 'HUMAN_VERIFIED',
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
  final SecurityEngineConfig config;
  final Random _rng = Random();
  
  final List<double> _confidenceHistory = [];
  int _consecutiveSuspiciousCount = 0;
  
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
    final double jitter = 1.0 + ((_rng.nextDouble() * 0.1) - 0.05);
    final double activeMinEntropy = config.minEntropy * jitter;
    
    // 1. SPEED CHECK
    if (interactionDuration.inMilliseconds < 300) { // Kurangkan ke 300ms untuk manusia pantas
      return _recordVerdict(ThreatVerdict.flag(ThreatLevel.HIGH_RISK, 'SPEED_ANOMALY', risk: 90));
    }

    // 2. 🔥 NO MOTION + NO TOUCH = BOT
    if (motionHistory.isEmpty) {
      // TAPI... Kalau ada sentuhan (Touch Count > 0), kita LULUSKAN walau motion kosong.
      // Ini cover kes "Tangan Surgeon" (Tangan sangat steady)
      if (touchCount > 0) {
         return _recordVerdict(ThreatVerdict.allow(1.0)); // LULUS SEBAB ADA TOUCH
      }
      
      if (config.minMotionPresence <= 0) {
        return _recordVerdict(ThreatVerdict.allow(1.0)); 
      }
      return _recordVerdict(ThreatVerdict.flag(ThreatLevel.CRITICAL, 'NO_DATA_SOURCE', risk: 100));
    }
    
    // 3. GHOST TOUCH (Motion ada, Touch tiada)
    if (motionHistory.length > 20 && touchCount == 0) {
       if (config.minMotionPresence > 0) {
         return _recordVerdict(ThreatVerdict.flag(ThreatLevel.HIGH_RISK, 'GHOST_MOTION', risk: 85));
       }
    }

    final entropy = _calculateEntropy(motionHistory);
    final variance = _calculateVariance(motionHistory);
    _lastEntropy = entropy;

    // 4. 🔥 RELAXED BIOMETRIC CHECK
    // Jika touchCount tinggi (active user), kita rendahkan threshold motion.
    double thresholdModifier = touchCount > 2 ? 0.5 : 1.0; 

    if (entropy < (activeMinEntropy * thresholdModifier)) {
      // Jangan failkan terus, cuma rendahkan confidence
      // Kecuali kalau betul-betul 0.0 (Emulator)
      if (entropy == 0.0) {
         return _recordVerdict(ThreatVerdict.flag(ThreatLevel.HIGH_RISK, 'ROBOTIC_MOVEMENT', entropy: entropy, risk: 95));
      }
    }

    double score = (entropy * 0.6) + (variance * 40 * 0.4);
    if (touchCount > 0) score += 0.2; // Bonus besar untuk touch
    score = score.clamp(0.0, 1.0);
    _lastConfidence = score;

    if (_isReplayAttack(score)) {
      return _recordVerdict(ThreatVerdict.flag(ThreatLevel.CRITICAL, 'REPLAY_ATTACK', risk: 100));
    }

    // Relaxed confidence check
    if (score < (config.minConfidence * 0.5)) { // 50% diskaun threshold
      return _recordVerdict(ThreatVerdict.flag(ThreatLevel.SUSPICIOUS, 'LOW_CONFIDENCE', entropy: entropy, risk: 60));
    }

    return _recordVerdict(ThreatVerdict.allow(score, entropy: entropy, variance: variance));
  }
  
  bool _isReplayAttack(double currentScore) {
    if (_confidenceHistory.length < 3) return false;
    return _confidenceHistory.take(3).every((s) => (s - currentScore).abs() < 0.0001);
  }

  ThreatVerdict _recordVerdict(ThreatVerdict v) {
    _confidenceHistory.insert(0, v.confidence);
    if (_confidenceHistory.length > 10) _confidenceHistory.removeLast();
    
    if (!v.allowed) {
      _consecutiveSuspiciousCount++;
    } else {
      _consecutiveSuspiciousCount = 0;
    }
    
    if (_consecutiveSuspiciousCount >= 5 && !v.allowed) { // Naikkan ke 5 baru block
      return ThreatVerdict.flag(ThreatLevel.CRITICAL, 'PERSISTENT_ATTACK', risk: 100, entropy: v.entropyScore);
    }
    
    return v;
  }

  double _calculateEntropy(List<MotionEvent> history) {
    if (history.isEmpty) return 0.0;
    final mags = history.map((e) => e.magnitude).toList();
    final freq = <int, int>{};
    for (var m in mags) {
      final bucket = (m * 10).floor().clamp(0, 15);
      freq[bucket] = (freq[bucket] ?? 0) + 1;
    }
    double entropy = 0.0;
    for (var count in freq.values) {
      final p = count / mags.length;
      if (p > 0) entropy -= p * log(p) / ln2;
    }
    return (entropy / 3.0).clamp(0.0, 1.0);
  }

  double _calculateVariance(List<MotionEvent> history) {
    if (history.length < 2) return 0.0;
    double sum = 0.0;
    double sumSq = 0.0;
    for (var h in history) {
      sum += h.magnitude;
      sumSq += h.magnitude * h.magnitude;
    }
    final mean = sum / history.length;
    final variance = (sumSq / history.length) - (mean * mean);
    return variance.clamp(0.0, 1.0);
  }
}
