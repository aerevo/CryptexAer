/*
 * PROJECT: CryptexLock Security Suite V3.0
 * MODULE: Incident Reporter (The Intelligence Agent)
 * PURPOSE: Secure communication agent with auto-retry and server analysis
 */

import 'dart:async';
import 'dart:convert'; // ✅ FIX: Library ini wajib ada untuk jsonEncode/jsonDecode
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'mirror_service.dart'; // ✅ FIX: Import model SecurityIncidentReport dari sini
import 'incident_storage.dart';
import '../config/security_config.dart';

/// The Result of an incident reporting operation
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
  
  IncidentReporter({
    required MirrorService mirrorService,
    required SecurityConfig config,
  })  : _mirrorService = mirrorService,
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
      // ✅ FIX: jsonEncode wujud sekarang sebab ada 'dart:convert'
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
      if (!_isSyncing) {
        retryAllPending();
      }
    });
  }

  Future<RetryResult> retryAllPending() async {
    if (_isSyncing) return RetryResult.empty();
    
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
      try {
        final Map<String, dynamic> data = jsonDecode(rawJson);
        // ✅ FIX: Menggunakan SecurityIncidentReport.fromJson dari mirror_service
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

  void dispose() {
    _backgroundSyncTimer?.cancel();
  }
}
