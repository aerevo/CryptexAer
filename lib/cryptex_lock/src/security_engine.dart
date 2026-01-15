// 🧠 SECURITY ENGINE V3.1 (AUDIT RESPONSE)
// Status: HARDENED & STATEFUL ✅
// Updates:
// 1. Added Short-Term Memory (Anti-Pattern-Learning)
// 2. Integrated 'touchCount' logic (Ghost Touch Detection)
// 3. Dynamic Thresholds (Jitter) to prevent fingerprinting
// 4. Granular Risk Scoring for Enterprise use

import 'dart:math';
import 'cla_models.dart';

enum ThreatLevel { SAFE, SUSPICIOUS, HIGH_RISK, CRITICAL }

// Keputusan Akhir yang lebih terperinci (Granular Verdict)
class ThreatVerdict {
  final bool allowed;
  final ThreatLevel level;
  final String reason;
  final double confidence;     // 0.0 - 1.0
  final double riskScore;      // 0.0 - 100.0 (Untuk Bank Risk Engine)
  
  // Data Forensik
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
      riskScore: (1.0 - confidence) * 100, // Risk rendah jika confidence tinggi
      entropyScore: entropy,
      varianceScore: variance,
    );
  }

  factory ThreatVerdict.flag(ThreatLevel level, String reason, {double entropy = 0, double risk = 100}) {
    // Nota: Level SUSPICIOUS mungkin masih 'allowed' bergantung pada policy Bank,
    // tapi untuk keselamatan lalai (default), kita set allowed: false.
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
  
  // 🔥 MEMORY (STATEFUL ENGINE)
  // Menyelesaikan masalah "Bot boleh belajar".
  // Kita ingat 5 verdict terakhir untuk kesan corak berulang.
  final List<double> _confidenceHistory = [];
  int _consecutiveSuspiciousCount = 0;
  
  // Internal State
  double _lastEntropy = 0.0;
  double _lastConfidence = 0.0;

  SecurityEngine(this.config);

  double get lastEntropyScore => _lastEntropy;
  double get lastConfidenceScore => _lastConfidence;

  /// 🔥 ANALISIS UTAMA V3.1
  ThreatVerdict analyze({
    required List<MotionEvent> motionHistory,
    required int touchCount, // ✅ FIX: Sekarang parameter ini DIGUNAKAN
    required Duration interactionDuration,
  }) {
    // 1. Dynamic Thresholds (Jitter)
    // Elak hacker 'fingerprint' nilai statik config.
    // Kita tambah +/- 5% variasi rawak.
    final double jitter = 1.0 + ((_rng.nextDouble() * 0.1) - 0.05);
    final double activeMinEntropy = config.minEntropy * jitter;
    
    // 2. Bot Check: Speed Anomaly
    if (interactionDuration.inMilliseconds < 500) {
      return _recordVerdict(ThreatVerdict.flag(
        ThreatLevel.HIGH_RISK, 
        'SPEED_ANOMALY_TOO_FAST',
        risk: 90
      ));
    }

    // 3. Bot Check: No Motion Data
    if (motionHistory.isEmpty) {
      if (config.minMotionPresence <= 0) {
        return _recordVerdict(ThreatVerdict.allow(1.0)); 
      }
      return _recordVerdict(ThreatVerdict.flag(
        ThreatLevel.CRITICAL, 
        'NO_MOTION_DATA_EMULATOR',
        risk: 100
      ));
    }
    
    // 4. ✅ FIX: Touch Density Logic (Ghost Touch)
    // Jika pergerakan banyak (motion > 50) tapi tiada sentuhan skrin,
    // ia mungkin script automation.
    if (motionHistory.length > 20 && touchCount == 0) {
       // Melainkan config membenarkan (cth: FaceID login tanpa sentuh)
       if (config.minMotionPresence > 0) {
         return _recordVerdict(ThreatVerdict.flag(
           ThreatLevel.HIGH_RISK,
           'GHOST_MOTION_NO_TOUCH',
           risk: 85
         ));
       }
    }

    // 5. Analisis Biometrik
    final entropy = _calculateEntropy(motionHistory);
    final variance = _calculateVariance(motionHistory);
    _lastEntropy = entropy;

    // 6. Logik Penilaian (The "Bank Grade" Decision)
    // Check Entropy dengan Jitter
    if (entropy < activeMinEntropy) {
      return _recordVerdict(ThreatVerdict.flag(
        ThreatLevel.HIGH_RISK, 
        'ROBOTIC_MOVEMENT_DETECTED',
        entropy: entropy,
        risk: 95
      ));
    }

    if (variance < config.minVariance) {
      return _recordVerdict(ThreatVerdict.flag(
        ThreatLevel.SUSPICIOUS, 
        'UNNATURAL_STABILITY',
        entropy: entropy,
        risk: 70
      ));
    }

    // 7. Kira Keyakinan (Confidence Score)
    double score = (entropy * 0.6) + (variance * 40 * 0.4);
    
    // Bonus points for organic touch interaction
    if (touchCount > 0) score += 0.05;
    
    score = score.clamp(0.0, 1.0);
    _lastConfidence = score;

    // 8. Memory Check (Pattern Drift)
    // Kalau score TEPAT SAMA 3 kali berturut-turut, itu bot (Replay Attack)
    if (_isReplayAttack(score)) {
      return _recordVerdict(ThreatVerdict.flag(
        ThreatLevel.CRITICAL,
        'REPLAY_ATTACK_DETECTED',
        risk: 100
      ));
    }

    if (score < config.minConfidence) {
      return _recordVerdict(ThreatVerdict.flag(
        ThreatLevel.SUSPICIOUS, 
        'LOW_CONFIDENCE_SCORE',
        entropy: entropy,
        risk: 60
      ));
    }

    // ✅ LULUS BERSIH
    return _recordVerdict(ThreatVerdict.allow(score, entropy: entropy, variance: variance));
  }
  
  // --- MEMORY LOGIC ---
  
  bool _isReplayAttack(double currentScore) {
    if (_confidenceHistory.length < 3) return false;
    // Check 3 terakhir
    return _confidenceHistory.take(3).every((s) => (s - currentScore).abs() < 0.0001);
  }

  ThreatVerdict _recordVerdict(ThreatVerdict v) {
    // Simpan history untuk analisis replay masa depan
    _confidenceHistory.insert(0, v.confidence);
    if (_confidenceHistory.length > 10) _confidenceHistory.removeLast();
    
    // Track consecutive failures
    if (!v.allowed) {
      _consecutiveSuspiciousCount++;
    } else {
      _consecutiveSuspiciousCount = 0;
    }
    
    // Jika gagal 3 kali berturut-turut, naikkan risk level (Progressive Security)
    if (_consecutiveSuspiciousCount >= 3 && !v.allowed) {
      return ThreatVerdict.flag(
        ThreatLevel.CRITICAL, 
        'PERSISTENT_ATTACK_VECTOR',
        risk: 100,
        entropy: v.entropyScore
      );
    }
    
    return v;
  }

  // --- ALGORITMA MATEMATIK (FORENSIK) ---

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
