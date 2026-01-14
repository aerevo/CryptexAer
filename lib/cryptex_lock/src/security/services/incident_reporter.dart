/*
 * PROJECT: CryptexLock Security Suite V3.0
 * MODULE: Incident Reporter (The Intelligence Agent)
 * PURPOSE: Secure communication agent with auto-retry and server analysis
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'mirror_service.dart';
import 'incident_storage.dart';
import '../config/security_config.dart';

class IncidentReporter {
  final MirrorService _mirrorService;
  final SecurityConfig _config;
  
  // Konfigurasi Retry
  static const int MAX_RETRY_ATTEMPTS = 3;
  static const Duration RETRY_INTERVAL = Duration(minutes: 5);
  
  // Timer untuk perkhidmatan latar belakang
  Timer? _retryTimer;
  
  IncidentReporter({
    required MirrorService mirrorService,
    required SecurityConfig config,
  })  : _mirrorService = mirrorService,
        _config = config {
    
    // 🔥 MULAKAN PERKHIDMATAN AUTO-SYNC (BACKGROUND)
    if (_config.retryFailedReports) {
      _startRetryService();
    }
  }
  
  /// 🦸‍♂️ FUNGSI UTAMA LAPORAN JENAYAH
  /// Fungsi yang dipanggil oleh Kapten dari main.dart
  Future<IncidentReportResult> report(SecurityIncidentReport incident) async {
    // 1. Semak jika fungsi ini diaktifkan dalam konfigurasi
    if (!_config.enableIncidentReporting) {
      return IncidentReportResult.disabled();
    }
    
    final String incidentJson = jsonEncode(incident.toJson());
    
    // 2. Backup secara lokal (Forensic Safety)
    if (_config.enableLocalIncidentStorage) {
      await IncidentStorage.saveIncident(incident.toJson());
    }
    
    try {
      // 3. Cuba hantar ke Intelligence Hub (Mirror Server)
      final receipt = await _mirrorService.reportIncident(incident);
      
      // 4. Jika berjaya, tandakan sebagai synced
      if (_config.enableLocalIncidentStorage) {
        await IncidentStorage.markAsSynced(incident.incidentId);
      }
      
      return IncidentReportResult.success(receipt);
    } catch (e) {
      if (kDebugMode) {
        print('📡 [NETWORK] Target offline. Queuing incident for retry...');
      }
      
      // 5. Jika gagal (offline), masukkan ke queue retry
      await IncidentStorage.addToPendingReports(incidentJson);
      
      return IncidentReportResult.queuedForRetry(incident.incidentId);
    }
  }
  
  /// PERKHIDMATAN LATAR BELAKANG (AUTO-RETRY)
  void _startRetryService() {
    // Cuba sync setiap 5 minit secara automatik
    _retryTimer = Timer.periodic(RETRY_INTERVAL, (timer) {
      retryAllPending();
    });
  }
  
  /// CUBA HANTAR SEMUA LAPORAN YANG TERTUNGGAK
  Future<RetryResult> retryAllPending() async {
    final pendingJsons = await IncidentStorage.getPendingReports();
    if (pendingJsons.isEmpty) return RetryResult.empty();
    
    int succeeded = 0;
    int failed = 0;
    
    for (String jsonStr in pendingJsons) {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        // Tukar semula JSON jadi Model
        final incident = SecurityIncidentReport.fromJson(data);
        
        final receipt = await _mirrorService.reportIncident(incident);
        
        if (receipt.incidentId.isNotEmpty) {
          await IncidentStorage.markAsSynced(incident.incidentId);
          await IncidentStorage.removeFromPending(jsonStr);
          succeeded++;
        }
      } catch (e) {
        failed++;
      }
    }
    
    if (kDebugMode && succeeded > 0) {
      print('🚀 [SYNC] Auto-retry successful: $succeeded reports sent.');
    }
    
    return RetryResult(
      total: pendingJsons.length,
      succeeded: succeeded,
      failed: failed,
    );
  }
  
  /// MENGAMBIL STATUS PERKHIDMATAN
  Future<Map<String, dynamic>> getStats() async {
    final storageStats = await IncidentStorage.getStats();
    return {
      ...storageStats,
      'retry_service_active': _retryTimer?.isActive ?? false,
      'endpoint': _config.serverEndpoint,
    };
  }
  
  void dispose() {
    _retryTimer?.cancel();
  }
}

// =========================================================
// RESULT MODELS (UNTUK MAKLUMBALAS UI)
// =========================================================

class IncidentReportResult {
  final bool success;
  final String status;
  final String incidentId;
  final IncidentReceipt? receipt;

  IncidentReportResult({
    required this.success,
    required this.status,
    required this.incidentId,
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
      status: 'QUEUED_FOR_RETRY',
      incidentId: incidentId,
    );
  }
  
  factory IncidentReportResult.disabled() {
    return IncidentReportResult(
      success: false,
      status: 'REPORTING_DISABLED',
      incidentId: '',
    );
  }
}

class RetryResult {
  final int total;
  final int succeeded;
  final int failed;

  RetryResult({
    required this.total,
    required this.succeeded,
    required this.failed,
  });
  
  factory RetryResult.empty() => RetryResult(total: 0, succeeded: 0, failed: 0);
}