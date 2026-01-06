/**
 * CryptexLock Mirror Server
 * Biometric Validation Engine
 * Advanced bot detection using ML-inspired scoring
 */

const crypto = require('crypto');

class BiometricValidator {
  constructor() {
    // Thresholds from environment or defaults
    this.config = {
      minEntropy: parseFloat(process.env.MIN_ENTROPY) || 0.5,
      minTremorHz: parseFloat(process.env.MIN_TREMOR_HZ) || 7.5,
      maxTremorHz: parseFloat(process.env.MAX_TREMOR_HZ) || 13.5,
      minInteractionTime: parseInt(process.env.MIN_INTERACTION_TIME_MS) || 1500,
      minConfidenceScore: parseFloat(process.env.MIN_CONFIDENCE_SCORE) || 0.85,
    };
    
    // Track device behavior patterns
    this.deviceHistory = new Map();
  }
  
  /**
   * Main validation function
   * Returns { allowed: boolean, confidence: number, reason: string }
   */
  validate(payload) {
    const { biometric, device_id, interaction_time_ms } = payload;
    
    // Extract biometric metrics
    const {
      entropy,
      tremor_hz,
      frequency_variance,
      average_magnitude,
      unique_gesture_count,
      interaction_time_ms: bioInteractionTime
    } = biometric;
    
    const interactionTime = interaction_time_ms || bioInteractionTime;
    
    // Multi-layer validation
    const checks = {
      entropyCheck: this._validateEntropy(entropy),
      tremorCheck: this._validateTremor(tremor_hz),
      varianceCheck: this._validateVariance(frequency_variance),
      magnitudeCheck: this._validateMagnitude(average_magnitude),
      gestureCheck: this._validateGestures(unique_gesture_count),
      timeCheck: this._validateInteractionTime(interactionTime),
      consistencyCheck: this._validateConsistency(device_id, biometric),
    };
    
    // Calculate weighted confidence score
    const confidence = this._calculateConfidence(checks);
    
    // Determine if allowed
    const allowed = confidence >= this.config.minConfidenceScore;
    
    // Get reason if denied
    const reason = allowed ? null : this._getDenialReason(checks);
    
    // Store for future consistency checks
    this._updateDeviceHistory(device_id, biometric, confidence);
    
    return {
      allowed,
      confidence: Math.round(confidence * 100) / 100,
      reason,
      details: process.env.NODE_ENV === 'development' ? checks : undefined
    };
  }
  
  /**
   * Validate entropy (randomness)
   * Humans: 0.5-1.0
   * Bots: < 0.3 (too consistent)
   */
  _validateEntropy(entropy) {
    if (entropy >= this.config.minEntropy) {
      return { passed: true, score: 1.0, weight: 0.25 };
    } else if (entropy >= 0.3) {
      return { passed: true, score: 0.6, weight: 0.25 };
    } else {
      return { passed: false, score: 0.0, weight: 0.25 };
    }
  }
  
  /**
   * Validate tremor frequency
   * Humans: 8-12 Hz (natural hand tremor)
   * Bots: Outside range or exactly consistent
   */
  _validateTremor(tremorHz) {
    if (tremorHz >= this.config.minTremorHz && tremorHz <= this.config.maxTremorHz) {
      return { passed: true, score: 1.0, weight: 0.20 };
    } else if (tremorHz > 5 && tremorHz < 15) {
      return { passed: true, score: 0.5, weight: 0.20 };
    } else {
      return { passed: false, score: 0.0, weight: 0.20 };
    }
  }
  
  /**
   * Validate frequency variance
   * Humans: > 0.1 (inconsistent)
   * Bots: < 0.05 (too perfect)
   */
  _validateVariance(variance) {
    if (variance > 0.1) {
      return { passed: true, score: 1.0, weight: 0.20 };
    } else if (variance > 0.05) {
      return { passed: true, score: 0.6, weight: 0.20 };
    } else {
      return { passed: false, score: 0.0, weight: 0.20 };
    }
  }
  
  /**
   * Validate magnitude (shake intensity)
   * Humans: 0.2-2.5
   * Bots: Outside range
   */
  _validateMagnitude(magnitude) {
    if (magnitude > 0.15 && magnitude < 3.0) {
      return { passed: true, score: 1.0, weight: 0.15 };
    } else if (magnitude > 0.1 && magnitude < 4.0) {
      return { passed: true, score: 0.5, weight: 0.15 };
    } else {
      return { passed: false, score: 0.0, weight: 0.15 };
    }
  }
  
  /**
   * Validate gesture diversity
   * Humans: >= 3 unique patterns
   * Bots: < 3 (repetitive)
   */
  _validateGestures(count) {
    if (count >= 5) {
      return { passed: true, score: 1.0, weight: 0.10 };
    } else if (count >= 3) {
      return { passed: true, score: 0.7, weight: 0.10 };
    } else {
      return { passed: false, score: 0.3, weight: 0.10 };
    }
  }
  
  /**
   * Validate interaction time
   * Humans: > 1.5 seconds
   * Bots: < 1 second (too fast)
   */
  _validateInteractionTime(timeMs) {
    if (timeMs >= this.config.minInteractionTime) {
      return { passed: true, score: 1.0, weight: 0.10 };
    } else if (timeMs >= 1000) {
      return { passed: true, score: 0.5, weight: 0.10 };
    } else {
      return { passed: false, score: 0.0, weight: 0.10 };
    }
  }
  
  /**
   * Validate consistency with device history
   * Detect if behavior drastically changed (account takeover)
   */
  _validateConsistency(deviceId, currentBio) {
    const history = this.deviceHistory.get(deviceId);
    
    if (!history || history.samples.length < 3) {
      // Not enough history yet
      return { passed: true, score: 0.8, weight: 0.10 };
    }
    
    // Calculate drift from historical average
    const avgEntropy = history.avgEntropy;
    const avgMagnitude = history.avgMagnitude;
    
    const entropyDrift = Math.abs(currentBio.entropy - avgEntropy);
    const magnitudeDrift = Math.abs(currentBio.average_magnitude - avgMagnitude);
    
    // If drift too high, suspicious (possible account takeover)
    if (entropyDrift > 0.3 || magnitudeDrift > 0.5) {
      return { passed: false, score: 0.2, weight: 0.10 };
    } else {
      return { passed: true, score: 1.0, weight: 0.10 };
    }
  }
  
  /**
   * Calculate weighted confidence score
   */
  _calculateConfidence(checks) {
    let totalScore = 0;
    let totalWeight = 0;
    
    for (const check of Object.values(checks)) {
      totalScore += check.score * check.weight;
      totalWeight += check.weight;
    }
    
    return totalScore / totalWeight;
  }
  
  /**
   * Get human-readable denial reason
   */
  _getDenialReason(checks) {
    const failedChecks = Object.entries(checks)
      .filter(([_, check]) => !check.passed)
      .map(([name]) => name);
    
    if (failedChecks.includes('entropyCheck')) {
      return 'low_entropy_pattern';
    } else if (failedChecks.includes('tremorCheck')) {
      return 'abnormal_tremor_frequency';
    } else if (failedChecks.includes('varianceCheck')) {
      return 'motion_too_consistent';
    } else if (failedChecks.includes('timeCheck')) {
      return 'interaction_too_fast';
    } else if (failedChecks.includes('consistencyCheck')) {
      return 'behavioral_drift_detected';
    } else {
      return 'low_biometric_confidence';
    }
  }
  
  /**
   * Update device behavior history
   */
  _updateDeviceHistory(deviceId, biometric, confidence) {
    let history = this.deviceHistory.get(deviceId);
    
    if (!history) {
      history = {
        samples: [],
        avgEntropy: 0,
        avgMagnitude: 0,
        lastSeen: Date.now()
      };
    }
    
    // Add new sample
    history.samples.push({
      entropy: biometric.entropy,
      magnitude: biometric.average_magnitude,
      confidence: confidence,
      timestamp: Date.now()
    });
    
    // Keep last 10 samples only
    if (history.samples.length > 10) {
      history.samples.shift();
    }
    
    // Update averages
    history.avgEntropy = history.samples.reduce((sum, s) => sum + s.entropy, 0) / history.samples.length;
    history.avgMagnitude = history.samples.reduce((sum, s) => sum + s.magnitude, 0) / history.samples.length;
    history.lastSeen = Date.now();
    
    this.deviceHistory.set(deviceId, history);
    
    // Cleanup old histories (after 24 hours)
    this._cleanupOldHistories();
  }
  
  /**
   * Remove old device histories
   */
  _cleanupOldHistories() {
    const now = Date.now();
    const maxAge = 24 * 60 * 60 * 1000; // 24 hours
    
    for (const [deviceId, history] of this.deviceHistory.entries()) {
      if (now - history.lastSeen > maxAge) {
        this.deviceHistory.delete(deviceId);
      }
    }
  }
}

module.exports = BiometricValidator;
