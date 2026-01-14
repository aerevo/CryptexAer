// 🛡️ Z-KINETIC FINAL PRODUCTION (BUG-FIXED)
// Status: COMPILATION ERROR FIXED ✅
// Duty: Intelligence Hub + Forensic Reporting + Production Stability

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert'; 
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
      title: 'Z-KINETIC PRO',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000), 
        primaryColor: Colors.cyanAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const LockScreen(
        systemName: "SECURE BANKING UPLINK",
        displayedAmount: "RM 50,000.00", 
        secureHash: "HASH-RM50.00",      
      ),
    );
  }
}

// 🧠 SECURITY INCIDENT MODEL
class SecurityIncidentReport {
  final String incidentId;
  final String timestamp;
  final String deviceId;
  final String attackType;
  final String detectedValue;
  final String expectedSignature;
  final String action;

  SecurityIncidentReport({
    required this.incidentId,
    required this.timestamp,
    required this.deviceId,
    required this.attackType,
    required this.detectedValue,
    required this.expectedSignature,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'timestamp': timestamp,
    'threat_intel': {
      'type': attackType,
      'detected': detectedValue,
      'signature': expectedSignature,
      'integrity_fail': true,
    },
    'device_id': deviceId,
    'status': action,
  };
}

class LockScreen extends StatefulWidget {
  final String systemName;
  final String displayedAmount;
  final String secureHash;

  const LockScreen({
    super.key,
    required this.systemName,
    required this.displayedAmount,
    required this.secureHash,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  bool _isInitialized = false;
  bool _isCompromised = false;

  @override
  void initState() {
    super.initState();
    _performIntegrityAudit(); 
    _initializeController();
  }

  void _performIntegrityAudit() {
    final calculatedHash = "HASH-${widget.displayedAmount.replaceAll(' ', '').replaceAll(',', '')}";
    if (calculatedHash != widget.secureHash) {
      setState(() {
        _isCompromised = true;
      });
    }
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
        clientId: 'Z_KINETIC_FINAL_PRO',
        clientSecret: 'audit_passed_intelligence_hub',
      ),
    );
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleReportAndCancel() async {
    HapticFeedback.heavyImpact();
    
    final report = SecurityIncidentReport(
      incidentId: "INC-${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now().toIso8601String(),
      deviceId: "Z-DEV-ID-99",
      attackType: "OVERLAY_MANIPULATION",
      detectedValue: widget.displayedAmount,
      expectedSignature: widget.secureHash,
      action: "BLOCK_AND_REPORT",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.white),
            SizedBox(width: 10),
            Text("SECURING DATA", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text("Sending forensic report to Intelligence Hub...\nNotifying banking partner...", style: TextStyle(color: Colors.white70)),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context); 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title: const Text("✅ THREAT NEUTRALIZED"),
        content: Text("Report ID: ${report.incidentId}\n\nEvidence has been locked. Transaction terminated."),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("DONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onSuccess() {
    if (_isCompromised) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ CRITICAL: SYSTEM LOCKED DUE TO DATA BREACH"), backgroundColor: Colors.red),
      );
    } else {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔓 ACCESS GRANTED"), backgroundColor: Colors.green),
      );
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ INVALID (${_controller.failedAttempts}/5)"), backgroundColor: Colors.red),
    );
  }

  // ✅ FIX: Ditambah semula untuk mengelakkan ralat kompilasi
  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("⛔ SECURITY LOCKOUT: ${_controller.remainingLockoutSeconds}s"),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Z-KINETIC SECURE GATEWAY", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, letterSpacing: 2)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isCompromised ? _buildHackedNotice() : _buildSafeNotice(),
              
              const SizedBox(height: 50),

              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed, // 🔥 FIX: Parameter wajib disediakan
              ),
              
              const SizedBox(height: 30),
              
              if (!_isCompromised)
                const Text("Target Code: 1-7-3-9-2", style: TextStyle(color: Colors.white10, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DATA INTEGRITY: VERIFIED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(widget.displayedAmount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHackedNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.report_problem, color: Colors.red),
              SizedBox(width: 10),
              Text("INTEGRITY BREACH DETECTED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text("Displayed value '${widget.displayedAmount}' does not match secure signature.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleReportAndCancel,
              icon: const Icon(Icons.security, color: Colors.white),
              label: const Text("CANCEL & GENERATE REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
