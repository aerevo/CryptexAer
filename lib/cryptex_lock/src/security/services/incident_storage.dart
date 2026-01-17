/*
 * PROJECT: CryptexLock Security Suite V4.0 (ULTRA-SECURE)
 * MODULE: Local Incident Storage (The Black Box - SQL Edition)
 * PURPOSE: High-performance forensic logging and offline queueing.
 * STATUS: PRODUCTION READY ✅
 */

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'mirror_service.dart'; // Untuk model SecurityIncidentReport

class IncidentStorage {
  static Database? _database;
  static const String _DB_NAME = 'z_kinetic_forensics.db';
  static const String _TABLE_INCIDENTS = 'incidents';
  static const int _MAX_RECORDS = 1000; // Kapasiti jauh lebih besar dari Prefs

  // ============================================
  // DATABASE INITIALIZATION
  // ============================================
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _DB_NAME);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_TABLE_INCIDENTS (
            id TEXT PRIMARY KEY,
            timestamp TEXT,
            device_id TEXT,
            attack_type TEXT,
            detected_value TEXT,
            expected_signature TEXT,
            action TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');
        
        // Index untuk carian pantas
        await db.execute('CREATE INDEX idx_synced ON $_TABLE_INCIDENTS (is_synced)');
      },
    );
  }

  // ============================================
  // CORE OPERATIONS
  // ============================================

  /// 🔥 MENYIMPAN INSIDEN (LOCAL SQL BACKUP)
  /// Menyimpan bukti serangan dengan struktur yang rigid.
  static Future<void> saveIncident(SecurityIncidentReport incident) async {
    try {
      final db = await database;
      
      await db.insert(
        _TABLE_INCIDENTS,
        {
          'id': incident.incidentId,
          'timestamp': incident.timestamp,
          'device_id': incident.deviceId,
          'attack_type': incident.attackType,
          'detected_value': incident.detectedValue,
          'expected_signature': incident.expectedSignature,
          'action': incident.action,
          'is_synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Auto-cleanup: Buang rekod lama jika melebihi had
      await _purgeOldRecords(db);
      
      if (kDebugMode) print('🛡️ [FORENSICS] Incident logged to SQL: ${incident.incidentId}');
    } catch (e) {
      if (kDebugMode) print('❌ [STORAGE ERROR] Failed to save to SQL: $e');
    }
  }

  /// Menukar status kepada 'Synced' selepas berjaya hantar ke server
  static Future<void> markAsSynced(String incidentId) async {
    final db = await database;
    await db.update(
      _TABLE_INCIDENTS,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [incidentId],
    );
  }

  /// Memadam rekod dari queue (biasanya selepas sync)
  static Future<void> removeFromPending(String incidentId) async {
    final db = await database;
    await db.delete(
      _TABLE_INCIDENTS,
      where: 'id = ?',
      whereArgs: [incidentId],
    );
  }

  // ============================================
  // DATA RETRIEVAL
  // ============================================

  /// Mengambil semua laporan yang belum dihantar ke server
  static Future<List<String>> getPendingReports() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _TABLE_INCIDENTS,
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
      );

      // Convert balik ke format JSON String untuk keserasian IncidentReporter
      return List.generate(maps.length, (i) {
        final report = {
          'incident_id': maps[i]['id'],
          'timestamp': maps[i]['timestamp'],
          'device_id': maps[i]['device_id'],
          'threat_intel': {
            'type': maps[i]['attack_type'],
            'detected': maps[i]['detected_value'],
            'signature': maps[i]['expected_signature'],
          },
          'status': maps[i]['action'],
        };
        return jsonEncode(report);
      });
    } catch (e) {
      return [];
    }
  }

  /// Mengambil statistik untuk dashboard forensik Kapten
  static Future<Map<String, int>> getStats() async {
    final db = await database;
    
    final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_TABLE_INCIDENTS')) ?? 0;
    final pending = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_TABLE_INCIDENTS WHERE is_synced = 0')) ?? 0;
    
    return {
      'total_logs': total,
      'pending_sync': pending,
      'synced': total - pending,
    };
  }

  // ============================================
  // MAINTENANCE
  // ============================================

  static Future<void> _purgeOldRecords(Database db) async {
    // FIFO (First In First Out)
    await db.execute('''
      DELETE FROM $_TABLE_INCIDENTS 
      WHERE id IN (
        SELECT id FROM $_TABLE_INCIDENTS 
        ORDER BY timestamp DESC 
        LIMIT -1 OFFSET $_MAX_RECORDS
      )
    ''');
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete(_TABLE_INCIDENTS);
  }
}
