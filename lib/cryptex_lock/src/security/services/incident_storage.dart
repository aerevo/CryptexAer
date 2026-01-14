/*
 * PROJECT: CryptexLock Security Suite V3.0
 * MODULE: Local Incident Storage (The Black Box)
 * PURPOSE: Permanent forensic backup and offline queue management
 */

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/secure_payload.dart';
import 'package:flutter/foundation.dart';

class IncidentStorage {
  static const String _KEY_INCIDENTS = 'security_incidents';
  static const String _KEY_PENDING_REPORTS = 'pending_incident_reports';
  static const int _MAX_INCIDENTS = 100; // Had simpanan untuk elak memori penuh
  
  /// 🔥 MENYIMPAN INSIDEN (LOCAL BACKUP)
  /// Fungsi ini memastikan bukti jenayah disimpan sebelum dihantar ke server.
  static Future<bool> saveIncident(Map<String, dynamic> incidentData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Ambil senarai insiden sedia ada
      final incidents = await getStoredIncidents();
      
      // Masukkan data baru dengan metadata forensik
      incidents.add({
        ...incidentData,
        'stored_at': DateTime.now().toIso8601String(),
        'synced': false,
      });
      
      // Jika melebihi had, buang yang paling lama (FIFO)
      if (incidents.length > _MAX_INCIDENTS) {
        incidents.removeAt(0);
      }
      
      // Simpan semula ke memori kekal
      final encoded = jsonEncode(incidents);
      await prefs.setString(_KEY_INCIDENTS, encoded);
      
      if (kDebugMode) {
        print('🛡️ [INTELLIGENCE] Evidence secured in local storage');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) print('🚨 [ERROR] Storage failure: $e');
      return false;
    }
  }
  
  /// MENGAMBIL SEMUA REKOD JENAYAH
  static Future<List<Map<String, dynamic>>> getStoredIncidents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString(_KEY_INCIDENTS);
      
      if (encoded == null || encoded.isEmpty) return [];
      
      final List<dynamic> decoded = jsonDecode(encoded);
      return decoded.map((i) => i as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// MENGAMBIL INSIDEN YANG BELUM DI-SYNC (UNTUK RETRY)
  static Future<List<Map<String, dynamic>>> getUnsyncedIncidents() async {
    final all = await getStoredIncidents();
    return all.where((i) => i['synced'] == false).toList();
  }
  
  /// MENANDAKAN REKOD SEBAGAI "BERJAYA DIHANTAR"
  static Future<void> markAsSynced(String incidentId) async {
    final incidents = await getStoredIncidents();
    
    bool found = false;
    for (var i = 0; i < incidents.length; i++) {
      if (incidents[i]['incident_id'] == incidentId) {
        incidents[i]['synced'] = true;
        found = true;
        break;
      }
    }
    
    if (found) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_KEY_INCIDENTS, jsonEncode(incidents));
    }
  }
  
  /// MENAMBAH KE QUEUE RETRY (JIKA SERVER DOWN)
  static Future<void> addToPendingReports(String incidentJson) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await getPendingReports();
    
    if (!pending.contains(incidentJson)) {
      pending.add(incidentJson);
      await prefs.setStringList(_KEY_PENDING_REPORTS, pending);
    }
  }
  
  /// MENGAMBIL SENARAI RETRY
  static Future<List<String>> getPendingReports() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_KEY_PENDING_REPORTS) ?? [];
  }
  
  /// MEMBUANG DARI QUEUE RETRY (SELEPAS BERJAYA)
  static Future<void> removeFromPending(String incidentJson) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await getPendingReports();
    pending.remove(incidentJson);
    await prefs.setStringList(_KEY_PENDING_REPORTS, pending);
  }

  /// PEMBERSIHAN AUTOMATIK (MAINTENANCE)
  /// Membuang log yang sudah synced dan lama (7 hari default)
  static Future<bool> clearOldIncidents({int maxAgeDays = 7}) async {
    try {
      final incidents = await getStoredIncidents();
      final now = DateTime.now();
      
      final filtered = incidents.where((incident) {
        if (incident['stored_at'] == null) return true;
        
        final stored = DateTime.parse(incident['stored_at']);
        final age = now.difference(stored).inDays;
        
        // Simpan jika: Belum sync OR Umur kurang dari had
        return incident['synced'] != true || age < maxAgeDays;
      }).toList();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_KEY_INCIDENTS, jsonEncode(filtered));
      
      final removed = incidents.length - filtered.length;
      if (kDebugMode && removed > 0) {
        print('🧹 [CLEANUP] Purged $removed old incident logs');
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// MENGAMBIL STATISTIK UNTUK DASHBOARD KAPTEN
  static Future<Map<String, int>> getStats() async {
    final incidents = await getStoredIncidents();
    final pending = await getPendingReports();
    
    final synced = incidents.where((i) => i['synced'] == true).length;
    final unsynced = incidents.length - synced;
    
    return {
      'total_stored': incidents.length,
      'synced': synced,
      'unsynced': unsynced,
      'pending_reports': pending.length,
    };
  }
  
  /// RESET SEMUA DATA (ADMIN ONLY)
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_KEY_INCIDENTS);
      await prefs.remove(_KEY_PENDING_REPORTS);
      return true;
    } catch (e) {
      return false;
    }
  }
}