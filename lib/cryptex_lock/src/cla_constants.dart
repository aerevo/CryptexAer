// ⚙️ Z-KINETIC SECURITY CONFIGURATION CONSTANTS
// File: lib/cryptex_lock/src/cla_constants.dart

class ClaAIConstants {
  // --- AI Learning Engine Settings ---
  static const int minUnlocksForTraining = 5;
  static const int minUnlocksForAnomalyDetection = 3;
  static const int maxHistoryBuffer = 20;
  
  // --- Statistical Thresholds (Z-Score) ---
  static const double anomalyZScoreLimit = 3.0; // Higher = More lenient
  static const double statisticalSmoothingFactor = 0.1;

  // --- Adaptive Sensitivity Factors ---
  static const double motionSensitivityMultiplier = 0.6;
  static const double touchSensitivityMultiplier = 0.5;

  // --- Hard Minimum Safety Limits ---
  static const double minMotionThreshold = 1.0;
  static const double minTouchThreshold = 3.0;
  
  // --- Default Fallback Values ---
  static const double initialMotionThreshold = 2.0;
  static const double initialTouchThreshold = 5.0;
  static const double initialAvgMotion = 3.0;
  static const double initialAvgTouch = 8.0;
  static const double initialStdDev = 1.0;
}

class ClaSecurityConstants {
  static const Duration defaultMinSolveTime = Duration(milliseconds: 600);
  static const Duration defaultJamCooldown = Duration(seconds: 10);
  static const int defaultMaxAttempts = 5;
  static const int motionBufferSize = 50;
  static const int touchBufferSize = 50;
}
