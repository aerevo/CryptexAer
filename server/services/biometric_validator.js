/**
 * CryptexLock Mirror Server V3.0
 * Biometric Validation Engine
 * NEW: Threat Analysis & Attack Vector Detection
 */

const crypto = require('crypto');

class BiometricValidator {
  constructor() {
    this.config = {
      minEntropy: parseFloat(process.env.MIN_ENTROPY) || 0.5,
      minTremorHz: parseFloat(process.env.MIN_TREMOR_HZ) || 7.5,
      maxTremorHz: parseFloat(process.env.MAX_TREMOR_HZ) || 13.5,
      minInteractionTime: parseInt(process.env.MIN_INTERACTION_TIME_MS) || 1500,
      minConfidenceScore: parseFloat(process.env.MIN_CONFIDENCE_SCORE) || 0.85,
    };
    
    this.deviceHistory = new Map();
  }
  
  /**
   * Main validation function
   */
  validate(payload) {
    const { biometric, device_id, interaction_time_ms } = payload;
    
    const {
      entropy,
      tremor_hz,
      frequency_variance,
      average_magnitude,
      unique_gesture_count,
      interaction_time_ms: bioInteractionTime
    } = biometric;
    
    const interactionTime = interaction_time_ms || bioInteractionTime;
    
    const checks = {
      entropyCheck: this._validateEntropy(entropy),
      tremorCheck: this._validateTremor(tremor_hz),
      varianceCheck: this._validateVariance(frequency_variance),
      magnitudeCheck: this._validateMagnitude(average_magnitude),
      gestureCheck: this._validateGestures(unique_gesture_count),
      timeCheck: this._validateInteractionTime(interactionTime),
      consistencyCheck: this._validateConsistency(device_id, biometric),
    };
    
    const confidence = this._calculateConfidence(checks);
    const allowed = confidence >= this.config.minConfidenceScore;
    const reason = allowed ? null : this._getDenialReason(checks);
    
    this._updateDeviceHistory(device_id, biometric, confidence);
    
    return {
      allowed,
      confidence: Math.round(confidence * 100) / 100,
      reason,
      details: process.env.NODE_ENV === 'development' ? checks : undefined
    };
  }
  
  /**
   * ðŸ”¥ NEW: Analyze threat from incident report
   * Determines attack type and severity
   */
  analyzeThreat(threatIntel) {
    const {
      type,
      original_val,
      manipulated_val,
      severity
    } = threatIntel;
    
    let attackVector = 'UNKNOWN';
    let confidence = 0.5;
    let actualSeverity = severity || 'MEDIUM';
    
    // Detect attack type based on manipulation pattern
    if (type === 'MITM_AMOUNT_MANIPULATION' || type === 'DATA_INTEGRITY_MISMATCH') {
      attackVector = this._detectManipulationVector(original_val, manipulated_val);
      confidence = this._calculateThreatConfidence(original_val, manipulated_val);
      
      // Auto-adjust severity based on manipulation magnitude
      const manipulationRatio = this._getManipulationRatio(original_val, manipulated_val);
      
      if (manipulationRatio > 100) {
        actualSeverity = 'CRITICAL'; // >100x increase
      } else if (manipulationRatio > 10) {
        actualSeverity = 'HIGH'; // >10x increase
      } else if (manipulationRatio > 2) {
        actualSeverity = 'MEDIUM';
      } else {
        actualSeverity = 'LOW';
      }
    }
    
    return {
      type: type || 'GENERIC_THREAT',
      attackVector,
      severity: actualSeverity,
      confidence,
      details: {
        original: original_val,
        manipulated: manipulated_val,
        ratio: this._getManipulationRatio(original_val, manipulated_val)
      }
    };
  }
  
  /**
   * Detect specific manipulation vector
   */
  _detectManipulationVector(original, manipulated) {
    if (!original || !manipulated) return 'UNKNOWN';
    
    // Extract numeric values
    const origNum = this._extractNumber(original);
    const manipNum = this._extractNumber(manipulated);
    
    if (origNum === null || manipNum === null) return 'NON_NUMERIC_MANIPULATION';
    
    const ratio = manipNum / origNum;
    
    // Pattern detection
    if (ratio > 1000) {
      return 'OVERLAY_ATTACK'; // Extreme increase suggests screen overlay
    } else if (ratio > 100) {
      return 'MITM_DECIMAL_SHIFT'; // Likely decimal point manipulation
    } else if (ratio > 10) {
      return 'MITM_VALUE_INFLATION'; // Standard MITM attack
    } else if (Math.abs(manipNum - origNum) < 10) {
      return 'SUBTLE_MANIPULATION'; // Small changes (testing attack)
    } else if (manipNum < origNum) {
      return 'VALUE_DEFLATION'; // Rare: reducing amount (refund fraud)
    }
    
    return 'MITM_AMOUNT_MANIPULATION';
  }
  
  /**
   * Calculate threat confidence based on evidence
   */
  _calculateThreatConfidence(original, manipulated) {
    const origNum = this._extractNumber(original);
    const manipNum = this._extractNumber(manipulated);
    
    if (origNum === null || manipNum === null) return 0.5;
    
    const ratio = Math.abs(manipNum - origNum) / origNum;
    
    // Higher ratio = higher confidence it's malicious
    if (ratio > 10) return 0.99;
    if (ratio > 5) return 0.95;
    if (ratio > 2) return 0.90;
    if (ratio > 1) return 0.80;
    if (ratio > 0.5) return 0.70;
    
    return 0.60;
  }
  
  /**
   * Get manipulation ratio (multiplier)
   */
  _getManipulationRatio(original, manipulated) {
    const origNum = this._extractNumber(original);
    const manipNum = this._extractNumber(manipulated);
    
    if (origNum === null || manipNum === null || origNum === 0) return 1;
    
    return Math.abs(manipNum / origNum);
  }
  
  /**
   * Extract numeric value from string (handles RM, $, etc)
   */
  _extractNumber(value) {
    if (typeof value === 'number') return value;
    if (typeof value !== 'string') return null;
    
    // Remove currency symbols and commas
    const cleaned = value.replace(/[^0-9.]/g, '');
    const num = parseFloat(cleaned);
    
    return isNaN(num) ? null : num;
  }
  
  // ============================================
  // EXISTING VALIDATION METHODS (UNCHANGED)
  // ============================================
  
  _validateEntropy(entropy) {
    if (entropy >= this.config.minEntropy) {
      return { passed: true, score: 1.0, weight: 0.25 };
    } else if (entropy >= 0.3) {
      return { passed: true, score: 0.6, weight: 0.25 };
    } else {
      return { passed: false, score: 0.0, weight: 0.25 };
    }
  }
  
  _validateTremor(tremorHz) {
    if (tremorHz >= this.config.minTremorHz && tremorHz <= this.config.maxTremorHz) {
      return { passed: true, score: 1.0, weight: 0.20 };
    } else if (tremorHz > 5 && tremorHz < 15) {
      return { passed: true, score: 0.5, weight: 0.20 };
    } else {
      return { passed: false, score: 0.0, weight: 0.20 };
    }
  }
  
  _validateVariance(variance) {
    if (variance > 0.1) {
      return { passed: true, score: 1.0, weight: 0.20 };
    } else if (variance > 0.05) {
      return { passed: true, score: 0.6, weight: 0.20 };
    } else {
      return { passed: false, score: 0.0, weight: 0.20 };
    }
  }
  
  _validateMagnitude(magnitude) {
    if (magnitude > 0.15 && magnitude < 3.0) {
      return { passed: true, score: 1.0, weight: 0.15 };
    } else if (magnitude > 0.1 && magnitude < 4.0) {
      return { passed: true, score: 0.5, weight: 0.15 };
    } else {
      return { passed: false, score: 0.0, weight: 0.15 };
    }
  }
  
  _validateGestures(count) {
    if (count >= 5) {
      return { passed: true, score: 1.0, weight: 0.10 };
    } else if (count >= 3) {
      return { passed: true, score: 0.7, weight: 0.10 };
    } else {
      return { passed: false, score: 0.3, weight: 0.10 };
    }
  }
  
  _validateInteractionTime(timeMs) {
    if (timeMs >= this.config.minInteractionTime) {
      return { passed: true, score: 1.0, weight: 0.10 };
    } else if (timeMs >= 1000) {
      return { passed: true, score: 0.5, weight: 0.10 };
    } else {
      return { passed: false, score: 0.0, weight: 0.10 };
    }
  }
  
  _validateConsistency(deviceId, currentBio) {
    const history = this.deviceHistory.get(deviceId);
    
    if (!history || history.samples.length < 3) {
      return { passed: true, score: 0.8, weight: 0.10 };
    }
    
    const avgEntropy = history.avgEntropy;
    const avgMagnitude = history.avgMagnitude;
    
    const entropyDrift = Math.abs(currentBio.entropy - avgEntropy);
    const magnitudeDrift = Math.abs(currentBio.average_magnitude - avgMagnitude);
    
    if (entropyDrift > 0.3 || magnitudeDrift > 0.5) {
      return { passed: false, score: 0.2, weight: 0.10 };
    } else {
      return { passed: true, score: 1.0, weight: 0.10 };
    }
  }
  
  _calculateConfidence(checks) {
    let totalScore = 0;
    let totalWeight = 0;
    
    for (const check of Object.values(checks)) {
      totalScore += check.score * check.weight;
      totalWeight += check.weight;
    }
    
    return totalScore / totalWeight;
  }
  
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
    
    history.samples.push({
      entropy: biometric.entropy,
      magnitude: biometric.average_magnitude,
      confidence: confidence,
      timestamp: Date.now()
    });
    
    if (history.samples.length > 10) {
      history.samples.shift();
    }
    
    history.avgEntropy = history.samples.reduce((sum, s) => sum + s.entropy, 0) / history.samples.length;
    history.avgMagnitude = history.samples.reduce((sum, s) => sum + s.magnitude, 0) / history.samples.length;
    history.lastSeen = Date.now();
    
    this.deviceHistory.set(deviceId, history);
    this._cleanupOldHistories();
  }
  
  _cleanupOldHistories() {
    const now = Date.now();
    const maxAge = 24 * 60 * 60 * 1000;
    
    for (const [deviceId, history] of this.deviceHistory.entries()) {
      if (now - history.lastSeen > maxAge) {
        this.deviceHistory.delete(deviceId);
      }
    }
  }
}

module.exports = BiometricValidator;
