/*
 * PROJECT: Z-KINETIC SECURITY CORE
 * MODULE: Behavioral Pattern Analyzer (EDGE COMPUTING - PRIVACY FIRST)
 * PURPOSE: Local-only biometric analysis - NO RAW DATA UPLOAD
 * FILE: lib/cryptex_lock/src/behavioral_analyzer.dart (PART 1/3)
 *
 * PRIVACY GUARANTEE:
 * - All analysis happens on-device
 * - Only threat incidents are reported (anonymized)
 * - Raw biometric data NEVER leaves the device
 */

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'motion_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Behavioral pattern analysis result
class BehavioralAnalysis {
  final double humanLikelihood;
  final double botProbability;
  final double anomalyScore;
  final MotionPattern motionPattern;
  final TouchPattern touchPattern;
  final TemporalPattern temporalPattern;
  final BehavioralFingerprint fingerprint;
  final ThreatLevel threatLevel;
  final List<String> suspiciousIndicators;
  final List<String> humanIndicators;
  
  BehavioralAnalysis({
    required this.humanLikelihood,
    required this.botProbability,
    required this.anomalyScore,
    required this.motionPattern,
    required this.touchPattern,
    required this.temporalPattern,
    required this.fingerprint,
    required this.threatLevel,
    required this.suspiciousIndicators,
    required this.humanIndicators,
  });
  
  bool get isProbablyHuman => humanLikelihood > 0.7;
  bool get isProbablyBot => botProbability > 0.6;
  bool get isAnomalous => anomalyScore > 0.7;
  
  // 🔥 NEW: Check if threat should be reported
  bool get shouldReportThreat {
    if (threatLevel == ThreatLevel.HIGH_RISK || threatLevel == ThreatLevel.CRITICAL) {
      return true;
    }
    if (isProbablyBot && suspiciousIndicators.length >= 2) {
      return true;
    }
    return false;
  }
  
  Map<String, dynamic> toJson() => {
    'human_likelihood': humanLikelihood.toStringAsFixed(3),
    'bot_probability': botProbability.toStringAsFixed(3),
    'anomaly_score': anomalyScore.toStringAsFixed(3),
    'threat_level': threatLevel.name,
    'suspicious_indicators': suspiciousIndicators,
    'human_indicators': humanIndicators,
  };
}

class MotionPattern {
  final double tremorFrequency;
  final double microMovementRatio;
  final double rhythmConsistency;
  final double accelerationProfile;
  final double directionChanges;
  
  MotionPattern({
    required this.tremorFrequency,
    required this.microMovementRatio,
    required this.rhythmConsistency,
    required this.accelerationProfile,
    required this.directionChanges,
  });
  
  Map<String, dynamic> toJson() => {
    'tremor_hz': tremorFrequency.toStringAsFixed(2),
    'micro_movement_ratio': microMovementRatio.toStringAsFixed(3),
    'rhythm_consistency': rhythmConsistency.toStringAsFixed(3),
  };
}

class TouchPattern {
  final double pressureVariance;
  final double velocityProfile;
  final double hesitationCount;
  final double coordinationScore;
  
  TouchPattern({
    required this.pressureVariance,
    required this.velocityProfile,
    required this.hesitationCount,
    required this.coordinationScore,
  });
  
  Map<String, dynamic> toJson() => {
    'pressure_variance': pressureVariance.toStringAsFixed(3),
    'hesitation_count': hesitationCount.toStringAsFixed(0),
  };
}

class TemporalPattern {
  final double averageInteractionTime;
  final double speedVariability;
  final double pauseFrequency;
  final double burstiness;
  
  TemporalPattern({
    required this.averageInteractionTime,
    required this.speedVariability,
    required this.pauseFrequency,
    required this.burstiness,
  });
  
  Map<String, dynamic> toJson() => {
    'avg_interaction_ms': averageInteractionTime.toStringAsFixed(0),
    'speed_variability': speedVariability.toStringAsFixed(3),
  };
}

class BehavioralFingerprint {
  final String signatureHash;
  final Map<String, double> features;
  
  BehavioralFingerprint({
    required this.signatureHash,
    required this.features,
  });
  
  Map<String, dynamic> toJson() => {
    'signature': signatureHash,
    'features': features,
  };
}

/// Behavioral pattern analyzer (EDGE COMPUTING)
class BehavioralAnalyzer {
  static const double HUMAN_TREMOR_MIN = 8.0;
  static const double HUMAN_TREMOR_MAX = 12.0;
  static const double HUMAN_RHYTHM_VARIANCE = 0.15;
  static const double BOT_RHYTHM_VARIANCE = 0.03;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Analyze biometric session (LOCAL ONLY)
  BehavioralAnalysis analyze(BiometricSession session) {
    final motionPattern = _analyzeMotionPattern(session.motionEvents);
    final touchPattern = _analyzeTouchPattern(session.touchEvents);
    final temporalPattern = _analyzeTemporalPattern(session);
    
    final humanLikelihood = _calculateHumanLikelihood(motionPattern, touchPattern, temporalPattern);
    final botProbability = _calculateBotProbability(motionPattern, touchPattern, temporalPattern);
    final anomalyScore = _calculateAnomalyScore(motionPattern, touchPattern, temporalPattern);
    final fingerprint = _generateFingerprint(motionPattern, touchPattern, temporalPattern);
    final suspiciousIndicators = _findSuspiciousIndicators(motionPattern, touchPattern, temporalPattern);
    final humanIndicators = _findHumanIndicators(motionPattern, touchPattern, temporalPattern);
    final threatLevel = _assessThreatLevel(humanLikelihood, botProbability, anomalyScore);
    
    final analysis = BehavioralAnalysis(
      humanLikelihood: humanLikelihood,
      botProbability: botProbability,
      anomalyScore: anomalyScore,
      motionPattern: motionPattern,
      touchPattern: touchPattern,
      temporalPattern: temporalPattern,
      fingerprint: fingerprint,
      threatLevel: threatLevel,
      suspiciousIndicators: suspiciousIndicators,
      humanIndicators: humanIndicators,
    );
    
    // 🔥 Report threat (PRIVACY-SAFE)
    if (analysis.shouldReportThreat) {
      _reportThreat(analysis, session);
    }
    
    return analysis;
  }
  
  /// 🔥 NEW: Report threat to global intelligence
  Future<void> _reportThreat(BehavioralAnalysis analysis, BiometricSession session) async {
    try {
      final deviceInfo = await _getAnonymizedDeviceInfo();
      
      String threatType = 'UNKNOWN';
      if (analysis.suspiciousIndicators.contains('MECHANICAL_RHYTHM')) {
        threatType = 'MECHANICAL_RHYTHM';
      } else if (analysis.suspiciousIndicators.contains('NO_PHYSIOLOGICAL_TREMOR')) {
        threatType = 'NO_TREMOR_DETECTED';
      } else if (analysis.suspiciousIndicators.contains('CONSTANT_PRESSURE')) {
        threatType = 'CONSTANT_PRESSURE';
      } else if (analysis.suspiciousIndicators.contains('INHUMAN_SPEED')) {
        threatType = 'INHUMAN_SPEED';
      } else if (analysis.suspiciousIndicators.contains('LINEAR_MOVEMENT')) {
        threatType = 'LINEAR_MOVEMENT';
      }
      
      String severity = 'MEDIUM';
      if (analysis.threatLevel == ThreatLevel.CRITICAL) {
        severity = 'CRITICAL';
      } else if (analysis.threatLevel == ThreatLevel.HIGH_RISK) {
        severity = 'HIGH';
      }
      
      // 🔥 PRIVACY-SAFE DATA (NO RAW BIOMETRICS)
      final threatData = {
        'threat_type': threatType,
        'severity': severity,
        'device_os': deviceInfo['os'],
        'device_type': deviceInfo['type'],
        'app_version': deviceInfo['app_version'],
        'timestamp': FieldValue.serverTimestamp(),
        'indicators': {
          'bot_probability': (analysis.botProbability * 100).round(),
          'human_likelihood': (analysis.humanLikelihood * 100).round(),
          'anomaly_score': (analysis.anomalyScore * 100).round(),
          'suspicious_count': analysis.suspiciousIndicators.length,
        },
        'region': 'ASIA_SOUTHEAST',
      };
      
      await _firestore.collection('global_threat_intel').add(threatData);
      
      if (kDebugMode) {
        print('🚨 Threat reported: $threatType ($severity)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to report threat: $e');
      }
    }
  }
  
  Future<Map<String, String>> _getAnonymizedDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'os': 'Android ${androidInfo.version.release}',
          'type': 'Android',
          'app_version': '1.0.0',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'os': 'iOS ${iosInfo.systemVersion}',
          'type': 'iOS',
          'app_version': '1.0.0',
        };
      }
    } catch (e) {}
    return {'os': 'Unknown', 'type': 'Unknown', 'app_version': '1.0.0'};
  }
  
  /*
 * FILE: lib/cryptex_lock/src/behavioral_analyzer.dart
 * EDGE COMPUTING - PRIVACY FIRST (NO RAW DATA UPLOAD)
 */

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'motion_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class BehavioralAnalysis {
  final double humanLikelihood;
  final double botProbability;
  final double anomalyScore;
  final MotionPattern motionPattern;
  final TouchPattern touchPattern;
  final TemporalPattern temporalPattern;
  final BehavioralFingerprint fingerprint;
  final ThreatLevel threatLevel;
  final List<String> suspiciousIndicators;
  final List<String> humanIndicators;
  
  BehavioralAnalysis({
    required this.humanLikelihood,
    required this.botProbability,
    required this.anomalyScore,
    required this.motionPattern,
    required this.touchPattern,
    required this.temporalPattern,
    required this.fingerprint,
    required this.threatLevel,
    required this.suspiciousIndicators,
    required this.humanIndicators,
  });
  
  bool get isProbablyHuman => humanLikelihood > 0.7;
  bool get isProbablyBot => botProbability > 0.6;
  bool get isAnomalous => anomalyScore > 0.7;
  
  bool get shouldReportThreat {
    if (threatLevel == ThreatLevel.HIGH_RISK || threatLevel == ThreatLevel.CRITICAL) return true;
    if (isProbablyBot && suspiciousIndicators.length >= 2) return true;
    return false;
  }
  
  Map<String, dynamic> toJson() => {
    'human_likelihood': humanLikelihood.toStringAsFixed(3),
    'bot_probability': botProbability.toStringAsFixed(3),
    'threat_level': threatLevel.name,
    'suspicious_indicators': suspiciousIndicators,
  };
}

class MotionPattern {
  final double tremorFrequency;
  final double microMovementRatio;
  final double rhythmConsistency;
  final double accelerationProfile;
  final double directionChanges;
  
  MotionPattern({
    required this.tremorFrequency,
    required this.microMovementRatio,
    required this.rhythmConsistency,
    required this.accelerationProfile,
    required this.directionChanges,
  });
  
  Map<String, dynamic> toJson() => {
    'tremor_hz': tremorFrequency.toStringAsFixed(2),
    'micro_movement_ratio': microMovementRatio.toStringAsFixed(3),
    'rhythm_consistency': rhythmConsistency.toStringAsFixed(3),
    'acceleration_profile': accelerationProfile.toStringAsFixed(3),
    'direction_changes': directionChanges.toStringAsFixed(3),
  };
}

class TouchPattern {
  final double pressureVariance;
  final double velocityProfile;
  final double hesitationCount;
  final double coordinationScore;
  
  TouchPattern({
    required this.pressureVariance,
    required this.velocityProfile,
    required this.hesitationCount,
    required this.coordinationScore,
  });
  
  Map<String, dynamic> toJson() => {
    'pressure_variance': pressureVariance.toStringAsFixed(3),
    'velocity_profile': velocityProfile.toStringAsFixed(3),
    'hesitation_count': hesitationCount.toStringAsFixed(0),
    'coordination_score': coordinationScore.toStringAsFixed(3),
  };
}

class TemporalPattern {
  final double averageInteractionTime;
  final double speedVariability;
  final double pauseFrequency;
  final double burstiness;
  
  TemporalPattern({
    required this.averageInteractionTime,
    required this.speedVariability,
    required this.pauseFrequency,
    required this.burstiness,
  });
  
  Map<String, dynamic> toJson() => {
    'avg_interaction_ms': averageInteractionTime.toStringAsFixed(0),
    'speed_variability': speedVariability.toStringAsFixed(3),
    'pause_frequency': pauseFrequency.toStringAsFixed(3),
    'burstiness': burstiness.toStringAsFixed(3),
  };
}

class BehavioralFingerprint {
  final String signatureHash;
  final Map<String, double> features;
  
  BehavioralFingerprint({required this.signatureHash, required this.features});
  
  Map<String, dynamic> toJson() => {'signature': signatureHash, 'features': features};
}

class BehavioralAnalyzer {
  static const double HUMAN_TREMOR_MIN = 8.0;
  static const double HUMAN_TREMOR_MAX = 12.0;
  static const double HUMAN_RHYTHM_VARIANCE = 0.15;
  static const double BOT_RHYTHM_VARIANCE = 0.03;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  BehavioralAnalysis analyze(BiometricSession session) {
    final motionPattern = _analyzeMotionPattern(session.motionEvents);
    final touchPattern = _analyzeTouchPattern(session.touchEvents);
    final temporalPattern = _analyzeTemporalPattern(session);
    
    final humanLikelihood = _calculateHumanLikelihood(motionPattern, touchPattern, temporalPattern);
    final botProbability = _calculateBotProbability(motionPattern, touchPattern, temporalPattern);
    final anomalyScore = _calculateAnomalyScore(motionPattern, touchPattern, temporalPattern);
    final fingerprint = _generateFingerprint(motionPattern, touchPattern, temporalPattern);
    final suspiciousIndicators = _findSuspiciousIndicators(motionPattern, touchPattern, temporalPattern);
    final humanIndicators = _findHumanIndicators(motionPattern, touchPattern, temporalPattern);
    final threatLevel = _assessThreatLevel(humanLikelihood, botProbability, anomalyScore);
    
    final analysis = BehavioralAnalysis(
      humanLikelihood: humanLikelihood,
      botProbability: botProbability,
      anomalyScore: anomalyScore,
      motionPattern: motionPattern,
      touchPattern: touchPattern,
      temporalPattern: temporalPattern,
      fingerprint: fingerprint,
      threatLevel: threatLevel,
      suspiciousIndicators: suspiciousIndicators,
      humanIndicators: humanIndicators,
    );
    
    if (analysis.shouldReportThreat) {
      _reportThreat(analysis);
    }
    
    return analysis;
  }
  
  Future<void> _reportThreat(BehavioralAnalysis analysis) async {
    try {
      final deviceInfo = await _getAnonymizedDeviceInfo();
      
      String threatType = 'UNKNOWN';
      if (analysis.suspiciousIndicators.contains('MECHANICAL_RHYTHM')) {
        threatType = 'MECHANICAL_RHYTHM';
      } else if (analysis.suspiciousIndicators.contains('NO_PHYSIOLOGICAL_TREMOR')) {
        threatType = 'NO_TREMOR_DETECTED';
      } else if (analysis.suspiciousIndicators.contains('CONSTANT_PRESSURE')) {
        threatType = 'CONSTANT_PRESSURE';
      } else if (analysis.suspiciousIndicators.contains('INHUMAN_SPEED')) {
        threatType = 'INHUMAN_SPEED';
      } else if (analysis.suspiciousIndicators.contains('LINEAR_MOVEMENT')) {
        threatType = 'LINEAR_MOVEMENT';
      }
      
      String severity = 'MEDIUM';
      if (analysis.threatLevel == ThreatLevel.CRITICAL) {
        severity = 'CRITICAL';
      } else if (analysis.threatLevel == ThreatLevel.HIGH_RISK) {
        severity = 'HIGH';
      }
      
      final threatData = {
        'threat_type': threatType,
        'severity': severity,
        'device_os': deviceInfo['os'],
        'device_type': deviceInfo['type'],
        'app_version': deviceInfo['app_version'],
        'timestamp': FieldValue.serverTimestamp(),
        'indicators': {
          'bot_probability': (analysis.botProbability * 100).round(),
          'human_likelihood': (analysis.humanLikelihood * 100).round(),
          'anomaly_score': (analysis.anomalyScore * 100).round(),
          'suspicious_count': analysis.suspiciousIndicators.length,
        },
        'region': 'ASIA_SOUTHEAST',
      };
      
      await _firestore.collection('global_threat_intel').add(threatData);
      
      if (kDebugMode) print('🚨 Threat reported: $threatType ($severity)');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to report threat: $e');
    }
  }
  
  Future<Map<String, String>> _getAnonymizedDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {'os': 'Android ${androidInfo.version.release}', 'type': 'Android', 'app_version': '1.0.0'};
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {'os': 'iOS ${iosInfo.systemVersion}', 'type': 'iOS', 'app_version': '1.0.0'};
      }
    } catch (e) {}
    return {'os': 'Unknown', 'type': 'Unknown', 'app_version': '1.0.0'};
  }

  MotionPattern _analyzeMotionPattern(List<MotionEvent> events) {
    if (events.isEmpty) {
      return MotionPattern(tremorFrequency: 0, microMovementRatio: 0, rhythmConsistency: 0, accelerationProfile: 0, directionChanges: 0);
    }
    return MotionPattern(
      tremorFrequency: _calculateTremorFrequency(events),
      microMovementRatio: _calculateMicroMovementRatio(events),
      rhythmConsistency: _calculateRhythmConsistency(events),
      accelerationProfile: _calculateAccelerationProfile(events),
      directionChanges: _calculateDirectionChanges(events),
    );
  }

  double _calculateTremorFrequency(List<MotionEvent> events) {
    if (events.length < 5) return 0;
    int oscillations = 0;
    double lastMagnitude = events.first.magnitude;
    bool wasIncreasing = false;
    for (int i = 1; i < events.length; i++) {
      final current = events[i].magnitude;
      final isIncreasing = current > lastMagnitude;
      if (isIncreasing != wasIncreasing) oscillations++;
      wasIncreasing = isIncreasing;
      lastMagnitude = current;
    }
    final durationSeconds = events.last.timestamp.difference(events.first.timestamp).inMilliseconds / 1000.0;
    return durationSeconds > 0 ? oscillations / durationSeconds : 0;
  }

  double _calculateMicroMovementRatio(List<MotionEvent> events) {
    if (events.isEmpty) return 0;
    final microMovements = events.where((e) => e.magnitude < 0.5).length;
    return microMovements / events.length;
  }

  double _calculateRhythmConsistency(List<MotionEvent> events) {
    if (events.length < 3) return 0;
    final intervals = <double>[];
    for (int i = 1; i < events.length; i++) {
      intervals.add(events[i].timestamp.difference(events[i - 1].timestamp).inMilliseconds.toDouble());
    }
    if (intervals.isEmpty) return 0;
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / intervals.length;
    final stdDev = sqrt(variance);
    return mean > 0 ? stdDev / mean : 0;
  }

  double _calculateAccelerationProfile(List<MotionEvent> events) {
    if (events.length < 3) return 0;
    double totalJerk = 0;
    for (int i = 2; i < events.length; i++) {
      final accel1 = events[i - 1].magnitude - events[i - 2].magnitude;
      final accel2 = events[i].magnitude - events[i - 1].magnitude;
      totalJerk += (accel2 - accel1).abs();
    }
    return events.length > 2 ? totalJerk / (events.length - 2) : 0;
  }

  double _calculateDirectionChanges(List<MotionEvent> events) {
    if (events.length < 3) return 0;
    int directionChanges = 0;
    for (int i = 2; i < events.length; i++) {
      final dx1 = events[i - 1].deltaX - events[i - 2].deltaX;
      final dy1 = events[i - 1].deltaY - events[i - 2].deltaY;
      final dx2 = events[i].deltaX - events[i - 1].deltaX;
      final dy2 = events[i].deltaY - events[i - 1].deltaY;
      final angle1 = atan2(dy1, dx1);
      final angle2 = atan2(dy2, dx2);
      if ((angle2 - angle1).abs() > pi / 4) directionChanges++;
    }
    return events.length > 2 ? directionChanges / (events.length - 2) : 0;
  }

  TouchPattern _analyzeTouchPattern(List<TouchEvent> events) {
    if (events.isEmpty) {
      return TouchPattern(pressureVariance: 0, velocityProfile: 0, hesitationCount: 0, coordinationScore: 0);
    }
    return TouchPattern(
      pressureVariance: _calculatePressureVariance(events),
      velocityProfile: _calculateVelocityProfile(events),
      hesitationCount: _calculateHesitationCount(events),
      coordinationScore: _calculateCoordinationScore(events),
    );
  }

  double _calculatePressureVariance(List<TouchEvent> events) {
    if (events.length < 2) return 0;
    final pressures = events.map((e) => e.pressure).toList();
    final mean = pressures.reduce((a, b) => a + b) / pressures.length;
    final variance = pressures.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / pressures.length;
    return sqrt(variance);
  }

  double _calculateVelocityProfile(List<TouchEvent> events) {
    if (events.isEmpty) return 0;
    final velocities = events.map((e) => sqrt(e.velocityX * e.velocityX + e.velocityY * e.velocityY)).toList();
    return velocities.reduce((a, b) => a + b) / velocities.length;
  }

  double _calculateHesitationCount(List<TouchEvent> events) {
    if (events.length < 2) return 0;
    int hesitations = 0;
    for (int i = 1; i < events.length; i++) {
      if (events[i].timestamp.difference(events[i - 1].timestamp).inMilliseconds > 200) hesitations++;
    }
    return hesitations.toDouble();
  }

  double _calculateCoordinationScore(List<TouchEvent> events) {
    if (events.length < 3) return 0.5;
    double smoothness = 0;
    for (int i = 2; i < events.length; i++) {
      final v1 = sqrt(pow(events[i-1].velocityX, 2) + pow(events[i-1].velocityY, 2));
      final v2 = sqrt(pow(events[i].velocityX, 2) + pow(events[i].velocityY, 2));
      smoothness += (v2 - v1).abs();
    }
    final avgChange = events.length > 2 ? smoothness / (events.length - 2) : 0;
    return (1.0 / (1.0 + avgChange)).clamp(0.0, 1.0);
  }

  TemporalPattern _analyzeTemporalPattern(BiometricSession session) {
    return TemporalPattern(
      averageInteractionTime: session.duration.inMilliseconds.toDouble(),
      speedVariability: _calculateSpeedVariability(session),
      pauseFrequency: _calculatePauseFrequency(session),
      burstiness: _calculateBurstiness(session),
    );
  }

  double _calculateSpeedVariability(BiometricSession session) {
    if (session.motionEvents.length < 2) return 0;
    final speeds = <double>[];
    for (int i = 1; i < session.motionEvents.length; i++) {
      final dt = session.motionEvents[i].timestamp.difference(session.motionEvents[i - 1].timestamp).inMilliseconds;
      if (dt > 0) speeds.add(1000.0 / dt);
    }
    if (speeds.isEmpty) return 0;
    final mean = speeds.reduce((a, b) => a + b) / speeds.length;
    final variance = speeds.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / speeds.length;
    return sqrt(variance) / (mean + 0.001);
  }

  double _calculatePauseFrequency(BiometricSession session) {
    if (session.motionEvents.length < 2) return 0;
    int pauses = 0;
    for (int i = 1; i < session.motionEvents.length; i++) {
      if (session.motionEvents[i].timestamp.difference(session.motionEvents[i - 1].timestamp).inMilliseconds > 100) pauses++;
    }
    return pauses / session.duration.inSeconds.toDouble();
  }

  double _calculateBurstiness(BiometricSession session) {
    if (session.motionEvents.length < 10) return 0;
    final totalDuration = session.duration.inMilliseconds.toDouble();
    final chunkSize = totalDuration / 5;
    final chunksActivity = List.filled(5, 0);
    for (final event in session.motionEvents) {
      final elapsed = event.timestamp.difference(session.startTime).inMilliseconds;
      final chunkIndex = (elapsed / chunkSize).floor().clamp(0, 4);
      chunksActivity[chunkIndex]++;
    }
    final mean = session.motionEvents.length / 5.0;
    final variance = chunksActivity.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / 5.0;
    return sqrt(variance) / (mean + 0.001);
  }

  double _calculateHumanLikelihood(MotionPattern motion, TouchPattern touch, TemporalPattern temporal) {
    double score = 0;
    int factors = 0;
    if (motion.tremorFrequency >= HUMAN_TREMOR_MIN && motion.tremorFrequency <= HUMAN_TREMOR_MAX) {
      score += 0.3;
      factors++;
    }
    if (motion.microMovementRatio > 0.3) {
      score += 0.2;
      factors++;
    }
    if (motion.rhythmConsistency > HUMAN_RHYTHM_VARIANCE) {
      score += 0.2;
      factors++;
    }
    if (touch.pressureVariance > 0.1) {
      score += 0.15;
      factors++;
    }
    if (touch.hesitationCount > 0) {
      score += 0.15;
      factors++;
    }
    return factors > 0 ? score : 0;
  }

  double _calculateBotProbability(MotionPattern motion, TouchPattern touch, TemporalPattern temporal) {
    double score = 0;
    if (motion.rhythmConsistency < BOT_RHYTHM_VARIANCE) score += 0.4;
    if (motion.tremorFrequency < HUMAN_TREMOR_MIN || motion.tremorFrequency > HUMAN_TREMOR_MAX * 1.5) score += 0.3;
    if (touch.pressureVariance < 0.05) score += 0.2;
    if (touch.hesitationCount == 0 && temporal.averageInteractionTime < 500) score += 0.1;
    return score.clamp(0.0, 1.0);
  }

  double _calculateAnomalyScore(MotionPattern motion, TouchPattern touch, TemporalPattern temporal) {
    double anomaly = 0;
    if (motion.tremorFrequency > 20 || motion.tremorFrequency < 2) anomaly += 0.3;
    if (temporal.burstiness > 2.0) anomaly += 0.2;
    if (touch.coordinationScore < 0.2) anomaly += 0.2;
    if (temporal.speedVariability > 3.0) anomaly += 0.3;
    return anomaly.clamp(0.0, 1.0);
  }

  BehavioralFingerprint _generateFingerprint(MotionPattern motion, TouchPattern touch, TemporalPattern temporal) {
    final features = {
      'tremor_freq': motion.tremorFrequency,
      'micro_ratio': motion.microMovementRatio,
      'rhythm_consistency': motion.rhythmConsistency,
      'pressure_var': touch.pressureVariance,
      'coordination': touch.coordinationScore,
      'speed_var': temporal.speedVariability,
      'burstiness': temporal.burstiness,
    };
    final signature = features.entries.map((e) => '${e.key}:${e.value.toStringAsFixed(4)}').join('|');
    final hash = signature.hashCode.abs().toRadixString(16).toUpperCase();
    return BehavioralFingerprint(signatureHash: 'BEHAVIOR_$hash', features: features);
  }

  List<String> _findSuspiciousIndicators(MotionPattern motion, TouchPattern touch, TemporalPattern temporal) {
    final indicators = <String>[];
    if (motion.rhythmConsistency < BOT_RHYTHM_VARIANCE) indicators.add('MECHANICAL_RHYTHM');
    if (motion.tremorFrequency < HUMAN_TREMOR_MIN) indicators.add('NO_PHYSIOLOGICAL_TREMOR');
    if (touch.pressureVariance < 0.05) indicators.add('CONSTANT_PRESSURE');
    if (touch.hesitationCount == 0 && temporal.averageInteractionTime < 500) indicators.add('INHUMAN_SPEED');
    if (motion.directionChanges < 0.1) indicators.add('LINEAR_MOVEMENT');
    return indicators;
  }

  List<String> _findHumanIndicators(MotionPattern motion, TouchPattern touch, TemporalPattern temporal) {
    final indicators = <String>[];
    if (motion.tremorFrequency >= HUMAN_TREMOR_MIN && motion.tremorFrequency <= HUMAN_TREMOR_MAX) indicators.add('NATURAL_TREMOR');
    if (motion.microMovementRatio > 0.3) indicators.add('MICRO_CORRECTIONS');
    if (touch.pressureVariance > 0.1) indicators.add('VARIABLE_PRESSURE');
    if (touch.hesitationCount > 0) indicators.add('COGNITIVE_PAUSES');
    if (motion.directionChanges > 0.3) indicators.add('ORGANIC_MOVEMENT');
    return indicators;
  }

  ThreatLevel _assessThreatLevel(double humanLikelihood, double botProbability, double anomalyScore) {
    if (botProbability > 0.7) return ThreatLevel.CRITICAL;
    if (anomalyScore > 0.8) return ThreatLevel.HIGH_RISK;
    if (humanLikelihood < 0.3) return ThreatLevel.SUSPICIOUS;
    return ThreatLevel.SAFE;
  }
}
