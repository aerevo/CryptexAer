/*
 * PROJECT: CryptexLock Security Suite V4.0
 * MODULE: Incident Reporter (ENTERPRISE READY)
 * STATUS: PRODUCTION READY ✅
 * VERSION: Cleaned (All Debug Statements Removed)
 * 
 * FIXES:
 * - Dual method signature (Map + Model support)
 * - main.dart compatibility restored
 * - Memory leak guards enhanced
 * - Error handling improved
 * - ALL debug print statements removed for production
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'mirror_service.dart';
import 'incident_storage.dart';
import '../config/security_config.dart';

class IncidentReportResult {
  final bool success;
  final String status;
  final String incidentId;
  final String? errorMessage;
  final IncidentReceipt? receipt;

  IncidentReportResult({
    required this.success,
    required this.status,
    required this.incidentId,
    this.errorMessage,
    this.receipt,
  });

  factory IncidentReportResult.success(IncidentReceipt receipt) {
    return IncidentReportResult(
      success: true,
      status: 'REPORTED_TO_SERVER',
      incidentId: receipt.incidentId,
      receipt: receipt,
    );
  }

  factory IncidentReportResult.queuedForRetry(String incidentId) {
    return IncidentReportResult(
      success: true,
      status: 'QUEUED_OFFLINE',
      incidentId: incidentId,
    );
  }

  factory IncidentReportResult.failed(String incidentId, String error) {
    return IncidentReportResult(
      success: false,
      status: 'CRITICAL_FAILURE',
      incidentId: incidentId,
      errorMessage: error,
    );
  }

  factory IncidentReportResult.disabled() {
    return IncidentReportResult(
      success: false,
      status: 'REPORTING_PROTOCOL_DISABLED',
      incidentId: '',
    );
  }
}

class RetryResult {
  final int totalPending;
  final int succeeded;
  final int failed;
  final List<String> errorLogs;

  RetryResult({
    required this.totalPending,
    required this.succeeded,
    required this.failed,
    required this.errorLogs,
  });

  factory RetryResult.empty() => RetryResult(
    totalPending: 0,
    succeeded: 0,
    failed: 0,
    errorLogs: []
  );
}

class IncidentReporter {
  final MirrorService _mirrorService;
  final SecurityConfig _config;

  static const Duration _BACKGROUND_SYNC_INTERVAL = Duration(minutes: 5);

  Timer? _backgroundSyncTimer;
  bool _isSyncing = false;
  bool _isDisposed = false;

  IncidentReporter({
    required MirrorService mirrorService,
    SecurityConfig? config,
  }) : _mirrorService = mirrorService,
       _config = config ?? const SecurityConfig() {
    
    if (_config.retryFailedReports) {
      _initializeBackgroundAgent();
    }
  }

  // ============================================
  // 🔧 FIX: DUAL SIGNATURE SUPPORT
  // ============================================

  /// PRIMARY METHOD: Named parameters (main.dart compatibility)
  Future<IncidentReportResult> report({
    required String deviceId,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    // Convert to model internally
    final incident = SecurityIncidentReport(
      incidentId: 'INC-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().toIso8601String(),
      deviceId: deviceId,
      attackType: type,
      detectedValue: metadata?['detected_value'] ?? 'N/A',
      expectedSignature: metadata?['expected_signature'] ?? 'N/A',
      action: metadata?['action'] ?? 'LOGGED',
    );

    return _reportInternal(incident);
  }

  /// SECONDARY METHOD: Model-based (backward compatibility)
  Future<IncidentReportResult> reportModel(SecurityIncidentReport incident) async {
    return _reportInternal(incident);
  }

  // ============================================
  // INTERNAL REPORTING LOGIC
  // ============================================

  Future<IncidentReportResult> _reportInternal(SecurityIncidentReport incident) async {
    if (!_config.enableIncidentReporting) {
      // Silent operation in production
      return IncidentReportResult.disabled();
    }

    final String incidentId = incident.incidentId;
    final Map<String, dynamic> incidentData = incident.toJson();

    if (_config.enableLocalIncidentStorage) {
      await IncidentStorage.saveIncident(incidentData);
    }

    try {
      final receipt = await _mirrorService.reportIncident(incident);

      if (_config.enableLocalIncidentStorage) {
        await IncidentStorage.markAsSynced(incidentId);
      }

      return IncidentReportResult.success(receipt);

    } on SocketException catch (e) {
      // Network error - queue for retry (silent operation)
      await IncidentStorage.addToPendingReports(jsonEncode(incidentData));
      return IncidentReportResult.queuedForRetry(incidentId);

    } on TimeoutException catch (e) {
      // Timeout - queue for retry (silent operation)
      await IncidentStorage.addToPendingReports(jsonEncode(incidentData));
      return IncidentReportResult.queuedForRetry(incidentId);

    } catch (e) {
      // Critical failure - queue and return error (silent operation)
      await IncidentStorage.addToPendingReports(jsonEncode(incidentData));
      return IncidentReportResult.failed(incidentId, e.toString());
    }
  }

  // ============================================
  // BACKGROUND SYNC
  // ============================================

  void _initializeBackgroundAgent() {
    _backgroundSyncTimer = Timer.periodic(_BACKGROUND_SYNC_INTERVAL, (timer) {
      if (!_isSyncing && !_isDisposed) {
        retryAllPending();
      }
    });
  }

  Future<RetryResult> retryAllPending() async {
    if (_isSyncing || _isDisposed) return RetryResult.empty();

    _isSyncing = true;
    final List<String> pendingLogs = await IncidentStorage.getPendingReports();

    if (pendingLogs.isEmpty) {
      _isSyncing = false;
      return RetryResult.empty();
    }

    int succeeded = 0;
    int failed = 0;
    List<String> errors = [];

    for (String rawJson in pendingLogs) {
      if (_isDisposed) break;

      try {
        final Map<String, dynamic> data = jsonDecode(rawJson);
        final incident = SecurityIncidentReport.fromJson(data);

        final receipt = await _mirrorService.reportIncident(incident);

        if (receipt.incidentId.isNotEmpty) {
          await IncidentStorage.markAsSynced(incident.incidentId);
          await IncidentStorage.removeFromPending(rawJson);
          succeeded++;
        }
      } catch (e) {
        failed++;
        errors.add(e.toString());
      }
    }

    _isSyncing = false;
    return RetryResult(
      totalPending: pendingLogs.length,
      succeeded: succeeded,
      failed: failed,
      errorLogs: errors,
    );
  }

  // ============================================
  // MEMORY SAFE DISPOSAL
  // ============================================

  void dispose() {
    _isDisposed = true;
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;

    // Silent disposal in production
  }
}
