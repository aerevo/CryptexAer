/*
 * PROJECT: CryptexLock Security Suite V3.0
 * MODULE: Security Configuration (MERGED: Core + Server + Incident Reporting)
 * STATUS: FIXED & UPDATED FOR PRODUCTION BUILD ✅
 */

class SecurityConfig {
  // =========================================================
  // 1. CORE SECURITY SETTINGS
  // =========================================================
  final bool enableBiometrics;
  final bool enablePinFallback;
  final int maxAttempts;
  final Duration lockoutDuration;
  final bool vibrateOnTouch;
  final bool obscureInput;

  // =========================================================
  // 2. SERVER VALIDATION SETTINGS
  // =========================================================
  final bool enableServerValidation;
  final String serverEndpoint;
  final Duration serverTimeout;
  final bool allowOfflineFallback;
  final double serverConfidenceThreshold;
  final bool enableCertificatePinning;

  // =========================================================
  // 3. INCIDENT REPORTING SETTINGS (THE INTELLIGENCE HUB)
  // =========================================================
  
  /// Enable automatic incident reporting to server
  final bool enableIncidentReporting;
  
  /// Auto-report critical threats (MITM, Overlay attacks)
  final bool autoReportCriticalThreats;
  
  /// Store incident logs locally (backup if server offline)
  final bool enableLocalIncidentStorage;
  
  /// Maximum local incident logs to store
  final int maxLocalIncidentLogs;
  
  /// Auto-retry failed incident reports
  final bool retryFailedReports;
  
  /// Show confirmation dialog to user before reporting
  final bool showReportConfirmation;

  const SecurityConfig({
    // Core Defaults
    this.enableBiometrics = true,
    this.enablePinFallback = true,
    this.maxAttempts = 5,
    this.lockoutDuration = const Duration(seconds: 30),
    this.vibrateOnTouch = true,
    this.obscureInput = false,

    // Server Defaults
    this.enableServerValidation = false,
    this.serverEndpoint = "https://api.yourdomain.com",
    this.serverTimeout = const Duration(seconds: 5),
    this.allowOfflineFallback = true,
    this.serverConfidenceThreshold = 0.8,
    this.enableCertificatePinning = false,

    // Reporting Defaults (Default: OFF)
    this.enableIncidentReporting = false,
    this.autoReportCriticalThreats = false,
    this.enableLocalIncidentStorage = true,
    this.maxLocalIncidentLogs = 50,
    this.retryFailedReports = false,
    this.showReportConfirmation = true,
  });

  // =========================================================
  // FACTORY CONSTRUCTORS (PRESETS)
  // =========================================================

  /// 🔥 PRODUCTION PRESET (High Security)
  /// Updated to accept Incident Reporting parameters from main.dart
  factory SecurityConfig.production({
    String serverEndpoint = "https://api.yourdomain.com",
    bool enableCertificatePinning = true,
    // ✅ FIX: Parameter ditambah di sini supaya main.dart tak error
    bool enableIncidentReporting = true,
    bool autoReportCriticalThreats = true,
    bool retryFailedReports = true,
  }) {
    return SecurityConfig(
      enableBiometrics: true,
      enablePinFallback: true,
      maxAttempts: 3, // Stricter attempts
      lockoutDuration: const Duration(minutes: 1), // Longer lockout
      
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: false, // Strict: Must valid online
      serverConfidenceThreshold: 0.85,
      enableCertificatePinning: enableCertificatePinning,
      
      // ✅ FIX: Nilai dari parameter dimasukkan ke sini
      enableIncidentReporting: enableIncidentReporting,
      autoReportCriticalThreats: autoReportCriticalThreats,
      retryFailedReports: retryFailedReports,
      enableLocalIncidentStorage: true,
      maxLocalIncidentLogs: 100,
      showReportConfirmation: false, // Auto-report in background for critical apps
    );
  }

  /// DEVELOPMENT PRESET (Debugging)
  factory SecurityConfig.development({
    String serverEndpoint = "http://localhost:3000",
  }) {
    return SecurityConfig(
      maxAttempts: 99,
      lockoutDuration: const Duration(seconds: 5),
      enableServerValidation: false,
      serverEndpoint: serverEndpoint,
      enableIncidentReporting: true,
      showReportConfirmation: true, // Ask dev before sending
    );
  }
  
  /// STRICT PRESET (Military Grade)
  factory SecurityConfig.strict({
    required String serverEndpoint,
  }) {
    return SecurityConfig(
      enableBiometrics: true,
      enablePinFallback: false, // Biometrics ONLY
      maxAttempts: 2,
      lockoutDuration: const Duration(minutes: 5),
      
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: false,
      serverConfidenceThreshold: 0.95, // Very high confidence required
      enableCertificatePinning: true,
      
      enableIncidentReporting: true,
      autoReportCriticalThreats: true,
      retryFailedReports: true,
    );
  }

  /// Validate configuration integrity
  bool isValid() {
    if (enableServerValidation && serverEndpoint.isEmpty) {
      return false;
    }
    return true;
  }

  /// CopyWith helper for dynamic updates
  SecurityConfig copyWith({
    bool? enableBiometrics,
    bool? enablePinFallback,
    int? maxAttempts,
    Duration? lockoutDuration,
    bool? vibrateOnTouch,
    bool? obscureInput,
    bool? enableServerValidation,
    String? serverEndpoint,
    Duration? serverTimeout,
    bool? allowOfflineFallback,
    double? serverConfidenceThreshold,
    bool? enableCertificatePinning,
    bool? enableIncidentReporting,
    bool? autoReportCriticalThreats,
    bool? enableLocalIncidentStorage,
    int? maxLocalIncidentLogs,
    bool? retryFailedReports,
    bool? showReportConfirmation,
  }) {
    return SecurityConfig(
      enableBiometrics: enableBiometrics ?? this.enableBiometrics,
      enablePinFallback: enablePinFallback ?? this.enablePinFallback,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      lockoutDuration: lockoutDuration ?? this.lockoutDuration,
      vibrateOnTouch: vibrateOnTouch ?? this.vibrateOnTouch,
      obscureInput: obscureInput ?? this.obscureInput,
      enableServerValidation: enableServerValidation ?? this.enableServerValidation,
      serverEndpoint: serverEndpoint ?? this.serverEndpoint,
      serverTimeout: serverTimeout ?? this.serverTimeout,
      allowOfflineFallback: allowOfflineFallback ?? this.allowOfflineFallback,
      serverConfidenceThreshold: serverConfidenceThreshold ?? this.serverConfidenceThreshold,
      enableCertificatePinning: enableCertificatePinning ?? this.enableCertificatePinning,
      enableIncidentReporting: enableIncidentReporting ?? this.enableIncidentReporting,
      autoReportCriticalThreats: autoReportCriticalThreats ?? this.autoReportCriticalThreats,
      enableLocalIncidentStorage: enableLocalIncidentStorage ?? this.enableLocalIncidentStorage,
      maxLocalIncidentLogs: maxLocalIncidentLogs ?? this.maxLocalIncidentLogs,
      retryFailedReports: retryFailedReports ?? this.retryFailedReports,
      showReportConfirmation: showReportConfirmation ?? this.showReportConfirmation,
    );
  }
  
  /// Get configuration summary for debugging
  Map<String, dynamic> toDebugMap() {
    return {
      'core': {
        'biometrics': enableBiometrics,
        'max_attempts': maxAttempts,
        'lockout_duration': lockoutDuration.inSeconds,
      },
      'server': {
        'validation_enabled': enableServerValidation,
        'endpoint': serverEndpoint,
        'offline_fallback': allowOfflineFallback,
      },
      'incident_reporting': {
        'enabled': enableIncidentReporting,
        'auto_report_critical': autoReportCriticalThreats,
        'local_storage': enableLocalIncidentStorage,
        'max_logs': maxLocalIncidentLogs,
      }
    };
  }
}
