/*
 * PROJECT: CryptexLock Security Suite V3.1 (LEAK FREE)
 * MODULE: Incident Reporter
 * STATUS: MEMORY SAFE ✅
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'mirror_service.dart'; 
import 'incident_storage.dart';
// import '../config/security_config.dart'; // Optional depending on file structure

class IncidentReportResult {
  final bool success;
  final String status;
  final String incidentId;

  IncidentReportResult({required this.success, required this.status, required this.incidentId});
  
  factory IncidentReportResult.empty() => IncidentReportResult(success: false, status: 'EMPTY', incidentId: '');
}

class IncidentReporter {
  final MirrorService _mirrorService;
  Timer? _backgroundSyncTimer;
  bool _isSyncing = false;
  bool _isDisposed = false; // 🛡️ GUARD FLAG

  static const Duration _BACKGROUND_SYNC_INTERVAL = Duration(minutes: 5);

  IncidentReporter({MirrorService? mirrorService}) 
      : _mirrorService = mirrorService ?? MirrorService() {
    _initializeBackgroundAgent();
  }

  void _initializeBackgroundAgent() {
    // 🚨 FIX: Store reference to timer to cancel it later
    _backgroundSyncTimer = Timer.periodic(_BACKGROUND_SYNC_INTERVAL, (timer) {
      if (!_isSyncing && !_isDisposed) {
        retryAllPending();
      }
    });
  }

  /// Main entry point to report security violation
  Future<IncidentReportResult> report({
    required String deviceId,
    required String type,
    required Map<String, dynamic> metadata,
  }) async {
    if (_isDisposed) return IncidentReportResult.empty();

    final incidentId = 'INC-${DateTime.now().millisecondsSinceEpoch}';
    
    final report = SecurityIncidentReport(
      incidentId: incidentId,
      timestamp: DateTime.now().toIso8601String(),
      deviceId: deviceId,
      attackType: type,
      detectedValue: metadata['detected'] ?? 'unknown',
      expectedSignature: metadata['expected'] ?? 'unknown',
      action: 'FLAGGED',
    );

    // 1. Cuba hantar online
    try {
      final receipt = await _mirrorService.reportIncident(report);
      return IncidentReportResult(success: true, status: 'SENT', incidentId: receipt.incidentId);
    } catch (e) {
      // 2. Kalau gagal, simpan offline (Queue)
      await IncidentStorage.saveOffline(report);
      return IncidentReportResult(success: false, status: 'QUEUED_OFFLINE', incidentId: incidentId);
    }
  }

  Future<void> retryAllPending() async {
    if (_isSyncing || _isDisposed) return;
    
    _isSyncing = true;
    
    try {
      final List<String> pendingLogs = await IncidentStorage.getPendingReports();
      if (pendingLogs.isEmpty) {
        _isSyncing = false;
        return;
      }

      for (String rawJson in pendingLogs) {
        if (_isDisposed) break; // Stop if disposed mid-loop

        try {
          final Map<String, dynamic> data = jsonDecode(rawJson);
          final incident = SecurityIncidentReport.fromJson(data);
          
          await _mirrorService.reportIncident(incident);
          
          // Only delete if successful
          await IncidentStorage.removeFromPending(incident.incidentId); 
        } catch (e) {
          debugPrint("Sync failed for item: $e");
        }
      }
    } catch (e) {
      debugPrint("Batch sync error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  // 🛡️ MEMORY LEAK FIX
  void dispose() {
    _isDisposed = true;
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
    debugPrint("IncidentReporter disposed. Background tasks killed.");
  }
}
