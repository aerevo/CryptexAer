// 🛡️ Z-KINETIC CLEAN INTELLIGENCE
// Status: SENSORS REMOVED
// Features: Intelligence Hub Logic + Anti-Scam UI + Cryptex Only

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert'; // Untuk JSON encoding
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Z-KINETIC INTEL',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: Colors.cyanAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      // ⚠️ TUKAR 'isHacked' KE 'true' UNTUK TEST SYSTEM REPORTING
      home: const LockScreen(
        systemName: "TRANSFER FUNDS",
        originalAmount: "RM 50.00",
        isHacked: true, // 🔥 TEST MODE: TRUE
      ),
    );
  }
}

// 🧠 MODEL DATA INTELLIGENCE (BACKEND READY)
class SecurityIncidentReport {
  final String incidentId;
  final String timestamp;
  final String deviceId;
  final String attackType;
  final String originalAmount;
  final String manipulatedAmount;
  final String status;

  SecurityIncidentReport({
    required this.incidentId,
    required this.timestamp,
    required this.deviceId,
    required this.attackType,
    required this.originalAmount,
    required this.manipulatedAmount,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'timestamp': timestamp,
    'device_fingerprint': deviceId,
    'threat_intel': {
      'type': attackType,
      'original_val': originalAmount,
      'manipulated_val': manipulatedAmount,
      'severity': 'CRITICAL',
    },
    'action_taken': status,
  };
}

class LockScreen extends StatefulWidget {
  final String systemName;
  final String originalAmount;
  final bool isHacked;

  const LockScreen({
    super.key,
    required this.systemName,
    required this.originalAmount,
    this.isHacked = false,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _controller = ClaController(
      const ClaConfig(
        secret: [1, 7, 3, 9, 2],
        minShake: 0.4, 
        botDetectionSensitivity: 0.25,  
        thresholdAmount: 0.25, 
        minSolveTime: Duration(milliseconds: 600),
        maxAttempts: 5,  
        jamCooldown: Duration(seconds: 10), 
        enableSensors: true, 
        clientId: 'Z_KINETIC_CLEAN_INTEL',
        clientSecret: 'intel_clean_v1',
      ),
    );
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🦸‍♂️ FUNGSI REPORTING (INTELLIGENCE HUB)
  Future<void> _handleReportAndCancel() async {
    HapticFeedback.heavyImpact();
    
    // 1. CAPTURE DATA
    final report = SecurityIncidentReport(
      incidentId: "INC-${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now().toIso8601String(),
      deviceId: "DEVICE-ID-${(DateTime.now().millisecondsSinceEpoch % 1000)}",
      attackType: "MITM_AMOUNT_MANIPULATION",
      originalAmount: widget.originalAmount,
      manipulatedAmount: "RM 50,000.00",
      status: "BLOCKED_BY_USER",
    );

    // 2. GENERATE JSON PAYLOAD
    final String jsonPayload = jsonEncode(report.toJson());
    print("📡 SENDING INTEL TO HQ:\n$jsonPayload");

    // 3. UI LOADING
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 15),
            Text("SECURING...", style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        content: const Text("Encrypting forensic data...\nAlerting Bank Protocol...", style: TextStyle(color: Colors.white70, fontSize: 12)),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context);

    // 4. SUCCESS
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.white),
            SizedBox(width: 10),
            Text("SECURED", style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        content: Text(
          "✅ REPORT #${report.incidentId} SENT\n✅ THREAT BLOCKED",
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onSuccess() {
    if (widget.isHacked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ WARNING: COMPROMISED!"), backgroundColor: Colors.red));
    } else {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ACCESS GRANTED"), backgroundColor: Colors.green));
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("INVALID CREDENTIALS (${_controller.failedAttempts}/5)"), backgroundColor: Colors.red));
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("LOCKED: ${_controller.remainingLockoutSeconds}s"), backgroundColor: Colors.deepOrange));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("SECURE GATEWAY", style: TextStyle(color: Colors.cyanAccent, fontSize: 14, fontFamily: 'monospace', letterSpacing: 2)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                // 1️⃣ LOGIK PAPARAN (INTELLIGENT UI)
                if (widget.isHacked)
                  _buildHackedNotice()
                else
                  _buildSafeNotice(),
                
                const SizedBox(height: 50),

                // 2️⃣ CRYPTEX LOCK (FOKUS UTAMA)
                CryptexLock(
                  controller: _controller,
                  onSuccess: _onSuccess,
                  onFail: _onFail,
                  onJammed: _onJammed,
                ),

                // TIADA LAGI SENSOR SEMAK DI BAWAH NI! 🧹✨
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🟢 SAFE UI
  Widget _buildSafeNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Text(
            "VERIFIED: ${widget.systemName}",
            style: TextStyle(color: Colors.green.shade300, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  // 🔴 HACKED UI (INTELLIGENCE TRIGGER)
  Widget _buildHackedNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text("DATA MANIPULATION DETECTED!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "ALERT: Original amount (RM 50) changed to RM 50,000 via MITM Attack.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 20),
          
          // 🔥 BUTANG HERO (REPORT)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleReportAndCancel,
              icon: const Icon(Icons.cloud_upload, color: Colors.white),
              label: const Text("CAPTURE DATA & REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
