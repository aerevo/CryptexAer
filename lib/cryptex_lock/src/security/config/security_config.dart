/*
 * PROJECT: CryptexLock Security Suite V3.0
 * MODULE: Security Configuration (MERGED: Core + Server + Incident Reporting)
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
  // ðŸ”¥ 3. INCIDENT REPORTING SETTINGS (NEW)
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
  
  /// Show incident report confirmation dialog to user
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
    this.serverEndpoint = "https://api.cryptex.aer/verify",
    this.serverTimeout = const Duration(seconds: 5),
    this.allowOfflineFallback = true,
    this.serverConfidenceThreshold = 0.85,
    this.enableCertificatePinning = false,
    
    // ðŸ”¥ Incident Reporting Defaults
    this.enableIncidentReporting = true,
    this.autoReportCriticalThreats = true,
    this.enableLocalIncidentStorage = true,
    this.maxLocalIncidentLogs = 50,
    this.retryFailedReports = true,
    this.showReportConfirmation = true,
  });

  // =========================================================
  // FACTORIES
  // =========================================================

  /// Standard default config
  factory SecurityConfig.standard() {
    return const SecurityConfig();
  }

  /// Development config (no server, basic reporting)
  factory SecurityConfig.development() {
    return const SecurityConfig(
      enableServerValidation: false,
      enableBiometrics: true,
      enableIncidentReporting: true,
      autoReportCriticalThreats: false, // Manual reporting in dev
      showReportConfirmation: true,
    );
  }
  
  /// Production config (High Security + Full Reporting)
  factory SecurityConfig.production({
    required String serverEndpoint,
  }) {
    return SecurityConfig(
      // Core Security
      enableBiometrics: true,
      maxAttempts: 3,
      lockoutDuration: const Duration(minutes: 5),
      
      // Server Validation
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: true,
      serverConfidenceThreshold: 0.85,
      enableCertificatePinning: true,
      
      // ðŸ”¥ Incident Reporting (Production)
      enableIncidentReporting: true,
      autoReportCriticalThreats: true,
      enableLocalIncidentStorage: true,
      maxLocalIncidentLogs: 100,
      retryFailedReports: true,
      showReportConfirmation: false, // Auto-report in production
    );
  }
  
  /// Strict production (No offline fallback, immediate reporting)
  factory SecurityConfig.strict({
    required String serverEndpoint,
  }) {
    return SecurityConfig(
      // Core Security
      enableBiometrics: true,
      maxAttempts: 3,
      obscureInput: true,
      
      // Server Validation
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: false, // No offline mode
      serverConfidenceThreshold: 0.90,
      enableCertificatePinning: true,
      
      // ðŸ”¥ Incident Reporting (Strict)
      enableIncidentReporting: true,
      autoReportCriticalThreats: true, // Immediate auto-report
      enableLocalIncidentStorage: false, // Server-only
      maxLocalIncidentLogs: 0,
      retryFailedReports: false, // Fail-fast
      showReportConfirmation: false,
    );
  }
  
  /// Banking/Financial config (Maximum security)
  factory SecurityConfig.banking({
    required String serverEndpoint,
  }) {
    return SecurityConfig(
      // Core Security (Strict)
      enableBiometrics: true,
      maxAttempts: 3,
      lockoutDuration: const Duration(minutes: 30),
      obscureInput: true,
      
      // Server Validation (Required)
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: false,
      serverConfidenceThreshold: 0.95,
      enableCertificatePinning: true,
      
      // ðŸ”¥ Incident Reporting (Maximum)
      enableIncidentReporting: true,
      autoReportCriticalThreats: true,
      enableLocalIncidentStorage: true,
      maxLocalIncidentLogs: 200,
      retryFailedReports: true,
      showReportConfirmation: false,
    );
  }
  
  /// Validate configuration integrity
  bool isValid() {
    if (enableServerValidation && serverEndpoint.isEmpty) {
      return false;
    }
    if (enableIncidentReporting && serverEndpoint.isEmpty) {
      return false; // Need endpoint for reporting
    }
    if (maxLocalIncidentLogs < 0) {
      return false;
    }
    return true;
  }

  /// CopyWith helper
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
