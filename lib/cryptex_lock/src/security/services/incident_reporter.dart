/*
 * PROJECT: CryptexLock Security Suite V3.2
 * MODULE: Incident Reporter (MEMORY SAFE + BUG FIXED)
 * STATUS: PRODUCTION READY ✅
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
  bool _isDisposed = false; // 🛡️ MEMORY LEAK GUARD

  IncidentReporter({
    required MirrorService mirrorService,
    required SecurityConfig config,
  }) : _mirrorService = mirrorService,
       _config = config {
    
    if (_config.retryFailedReports) {
      _initializeBackgroundAgent();
    }
  }

  Future<IncidentReportResult> report(SecurityIncidentReport incident) async {
    if (!_config.enableIncidentReporting) {
      if (kDebugMode) print('🛡️ [INTEL] Reporting protocol is disabled.');
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
      if (kDebugMode) print('🌐 [OFFLINE] Queuing $incidentId.');
      await IncidentStorage.addToPendingReports(jsonEncode(incidentData));
      return IncidentReportResult.queuedForRetry(incidentId);
      
    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏳ [TIMEOUT] Queuing $incidentId.');
      await IncidentStorage.addToPendingReports(jsonEncode(incidentData));
      return IncidentReportResult.queuedForRetry(incidentId);
      
    } catch (e) {
      if (kDebugMode) print('❌ [ERROR] Critical failure: $e');
      await IncidentStorage.addToPendingReports(jsonEncode(incidentData));
      return IncidentReportResult.failed(incidentId, e.toString());
    }
  }

  void _initializeBackgroundAgent() {
    _backgroundSyncTimer = Timer.periodic(_BACKGROUND_SYNC_INTERVAL, (timer) {
      // 🛡️ FIX: Check disposal status before executing
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
      // 🛡️ FIX: Stop processing if disposed mid-loop
      if (_isDisposed) break;
      
      try {
        final Map<String, dynamic> data = jsonDecode(rawJson);
        final incident = SecurityIncidentReport.fromJson(data);
        
        final receipt = await _mirrorService.reportIncident(incident);
        
        if (receipt.incidentId.isNotEmpty) {
          await IncidentStorage.markAsSynced(incident.incidentId);
          // 🔥 CRITICAL FIX: Use rawJson instead of incidentId
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

  // 🛡️ MEMORY SAFE DISPOSAL
  void dispose() {
    _isDisposed = true;
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
    
    if (kDebugMode) {
      debugPrint('🛡️ [INCIDENT_REPORTER] Disposed safely. Background sync terminated.');
    }
  }
}
