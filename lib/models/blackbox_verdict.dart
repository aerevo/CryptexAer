// 🔥 BLACK BOX VERDICT MODELS
// Type-safe response models for Firebase Cloud Functions

class BlackBoxVerdict {
  final bool allowed;
  final double confidence;
  final String verdict;
  final String threatLevel;
  final String? reason;

  BlackBoxVerdict({
    required this.allowed,
    required this.confidence,
    required this.verdict,
    required this.threatLevel,
    this.reason,
  });

  factory BlackBoxVerdict.fromJson(Map<String, dynamic> json) {
    return BlackBoxVerdict(
      allowed: json['allowed'] ?? false,
      confidence: (json['confidence'] ?? 0).toDouble(),
      verdict: json['verdict'] ?? 'UNKNOWN',
      threatLevel: json['threatLevel'] ?? 'UNKNOWN',
      reason: json['reason'],
    );
  }

  factory BlackBoxVerdict.denied(String reason) {
    return BlackBoxVerdict(
      allowed: false,
      confidence: 0.0,
      verdict: 'DENIED',
      threatLevel: 'HIGH',
      reason: reason,
    );
  }

  factory BlackBoxVerdict.offlineFallback() {
    return BlackBoxVerdict(
      allowed: true, // Or false for strict security
      confidence: 0.5,
      verdict: 'OFFLINE_MODE',
      threatLevel: 'UNKNOWN',
      reason: 'Server unreachable - using offline fallback',
    );
  }

  bool get isVerified => allowed && confidence > 0.7;
  bool get isSuspicious => !allowed || confidence < 0.5;
  bool get isCritical => threatLevel == 'CRITICAL' || threatLevel == 'HIGH';
}

class IncidentReceipt {
  final bool success;
  final String incidentId;
  final String severity;
  final IncidentActions actions;
  final ThreatAnalysis? threatAnalysis;

  IncidentReceipt({
    required this.success,
    required this.incidentId,
    required this.severity,
    required this.actions,
    this.threatAnalysis,
  });

  factory IncidentReceipt.fromJson(Map<String, dynamic> json) {
    return IncidentReceipt(
      success: json['success'] ?? false,
      incidentId: json['incidentId'] ?? '',
      severity: json['severity'] ?? 'UNKNOWN',
      actions: IncidentActions.fromJson(json['actions'] ?? {}),
      threatAnalysis: json['threatAnalysis'] != null
          ? ThreatAnalysis.fromJson(json['threatAnalysis'])
          : null,
    );
  }
}

class IncidentActions {
  final bool logged;
  final bool deviceBlacklisted;
  final bool alertSent;

  IncidentActions({
    required this.logged,
    required this.deviceBlacklisted,
    this.alertSent = false,
  });

  factory IncidentActions.fromJson(Map<String, dynamic> json) {
    return IncidentActions(
      logged: json['logged'] ?? false,
      deviceBlacklisted: json['deviceBlacklisted'] ?? false,
      alertSent: json['alertSent'] ?? false,
    );
  }
}

class ThreatAnalysis {
  final String type;
  final String attackVector;
  final double confidence;

  ThreatAnalysis({
    required this.type,
    required this.attackVector,
    required this.confidence,
  });

  factory ThreatAnalysis.fromJson(Map<String, dynamic> json) {
    return ThreatAnalysis(
      type: json['type'] ?? 'UNKNOWN',
      attackVector: json['attackVector'] ?? 'UNKNOWN',
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}
