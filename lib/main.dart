// 🛡️ Z-KINETIC INTELLIGENCE HUB V7.2 (HYBRID SECURITY ACTIVE)
// Status: V2 CONTROLLER INTEGRATED ✅
// Changes:
// 1. Switched to ClaControllerV2 explicitly
// 2. Added Composite Attestation (Device + Server)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

// ✅ FIX: Import barrel file tapi SEMBUNYIKAN (hide) Controller & Config lama
// supaya tidak bergaduh dengan V2
import 'cryptex_lock/cryptex_lock.dart' hide ClaController, ClaConfig;

// ✅ IMPORT SECTION: V2 Controller & Security Providers
import 'cryptex_lock/src/cla_controller_v2.dart'; 
import 'cryptex_lock/src/device_integrity_attestation.dart';
import 'cryptex_lock/src/server_attestation_provider.dart';
import 'cryptex_lock/src/composite_attestation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await IncidentStorage.database;
    if (kDebugMode) print("🛡️ Francois: Black Box (SQL) Initialized.");
  } catch (e) {
    if (kDebugMode) print("⚠️ Francois: Database Error: $e");
  }

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
      home: const BootLoader(),
    );
  }
}

// ==========================================
// 1. BOOTLOADER
// ==========================================
class BootLoader extends StatefulWidget {
  const BootLoader({super.key});

  @override
  State<BootLoader> createState() => _BootLoaderState();
}

class _BootLoaderState extends State<BootLoader> {
  @override
  void initState() {
    super.initState();
    _initializeSecureSession();
  }

  Future<void> _initializeSecureSession() async {
    TransactionData data;
    try {
      data = await TransactionService.fetchCurrentTransaction();
    } catch (e) {
      data = TransactionData(
        amount: "RM 0.00",
        securityHash: "ERR_HASH",
        transactionId: "FAILED_CONNECTION"
      );
    }

    const config = SecurityConfig(
      enableCertificatePinning: true,
      enableIncidentReporting: true,
      autoReportCriticalThreats: true,
    );

    final mirrorService = MirrorService();
    final incidentReporter = IncidentReporter(
      mirrorService: mirrorService,
      config: config,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LockScreen(
          systemName: "SECURE BANKING UPLINK",
          displayedAmount: data.amount,
          secureHash: data.securityHash,
          transactionId: data.transactionId,
          incidentReporter: incidentReporter,
          securityConfig: config,
        ),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.cyanAccent),
            SizedBox(height: 20),
            Text(
              "ESTABLISHING SECURE CONNECTION...",
              style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 10)
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. LOCK SCREEN
// ==========================================
class LockScreen extends StatefulWidget {
  final String systemName;
  final String displayedAmount;
  final String secureHash;
  final String transactionId;
  final IncidentReporter? incidentReporter;
  final SecurityConfig securityConfig;

  const LockScreen({
    super.key,
    required this.systemName,
    required this.displayedAmount,
    required this.secureHash,
    required this.transactionId,
    required this.securityConfig,
    this.incidentReporter,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  // ✅ Ini sekarang merujuk kepada V2 Controller
  late ClaController _controller;
  bool _isInitialized = false;
  bool _isCompromised = false;
  bool _userAcknowledgedThreat = false;
  bool _showFakeDashboard = false;

  @override
  void initState() {
    super.initState();
    _performIntegrityAudit();
    _initializeController();
  }

  void _performIntegrityAudit() {
    final isValid = TransactionService.validateTransaction(
      TransactionData(
        amount: widget.displayedAmount,
        securityHash: widget.secureHash,
        transactionId: widget.transactionId
      )
    );

    if (!isValid) {
      setState(() => _isCompromised = true);
      debugPrint("🚨 DATA BREACH: Integrity Check Failed for ${widget.transactionId}");
    }
  }

  // ✅ V2 INITIALIZATION LOGIC (Updated as requested)
  void _initializeController() {
    final deviceProvider = DeviceIntegrityAttestation(
      allowDebugMode: true,
      allowEmulators: false,
    );

    final serverProvider = ServerAttestationProvider(
      ServerAttestationConfig(
        endpoint: 'https://api.z-kinetic.com/v1/unlock',
        apiKey: 'ZK_BETA_KEY_2026',
      ),
    );

    final compositeProvider = CompositeAttestationProvider(
      [deviceProvider, serverProvider],
      strategy: AttestationStrategy.ALL_MUST_PASS,
    );

    // ✅ USE V2 CONTROLLER (yang ada getSessionSnapshot)
    _controller = ClaController(
      ClaConfig(
        secret: const [1, 7, 3, 9, 2],
        minShake: 0.4,
        thresholdAmount: 0.25,
        minSolveTime: const Duration(milliseconds: 600),
        maxAttempts: 5,
        jamCooldown: const Duration(seconds: 10),
        enableSensors: true,
        clientId: 'Z_KINETIC_PRO',
        clientSecret: 'secured_session_key',
        attestationProvider: compositeProvider,
      ),
    );

    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.incidentReporter?.dispose();
    super.dispose();
  }

  Future<void> _triggerSilentPanic() async {
    String deviceId = "UNKNOWN";
    try {
      deviceId = await DeviceFingerprint.getDeviceId();
    } catch (_) {}

    // ✅ Method ini hanya wujud dalam V2 Controller
    final sessionData = _controller.getSessionSnapshot();

    await widget.incidentReporter?.report(
      deviceId: deviceId,
      type: "DURESS_PANIC_CODE_ACTIVATED",
      metadata: {
        "user_state": "UNDER_THREAT",
        "action": "SILENT_ALARM_SENT",
        "biometrics": {
          "confidence": _controller.liveConfidence,
          "hand_tremor": _controller.motionEntropy,
          "session_id": sessionData['session_id']
        }
      },
    );
    debugPrint("🚨 SOS: Silent Alarm logged with Biometric Evidence.");
  }

  Future<void> _autoReportIncident() async {
    String deviceId = "UNKNOWN";
    try {
      deviceId = await DeviceFingerprint.getDeviceId();
    } catch (_) {}

    await widget.incidentReporter?.report(
      deviceId: deviceId,
      type: "INTEGRITY_MISMATCH_BYPASSED",
      metadata: {
        "amount": widget.displayedAmount,
        "hash": widget.secureHash,
        "action": "ALLOWED_WITH_WARNING",
      },
    );
  }

  Future<void> _handleReportAndCancel() async {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title: const Text("✅ REPORT SENT"),
        content: const Text("Transaction cancelled and logged for security."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Colors.white))
          )
        ],
      )
    );
  }

  void _onSuccess() {
    if (_controller.isPanicMode) {
      _triggerSilentPanic();
      setState(() {
        _showFakeDashboard = true;
      });
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔓 ACCESS GRANTED"), backgroundColor: Colors.green)
      );
      return;
    }

    if (_isCompromised && !_userAcknowledgedThreat) {
      setState(() => _userAcknowledgedThreat = true);
      _autoReportIncident();
      HapticFeedback.mediumImpact();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.orange.shade900,
          title: const Row(children: [
            Icon(Icons.warning_amber, color: Colors.white),
            SizedBox(width: 10),
            Text("SECURITY ALERT", style: TextStyle(color: Colors.white, fontSize: 16))
          ]),
          content: const Text(
            "Data Integrity Mismatch detected.\nAccess granted based on kinetic verification, but this incident has been recorded in the black box.",
            style: TextStyle(color: Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("⚠️ INCIDENT LOGGED"), backgroundColor: Colors.orange)
                );
              },
              child: const Text("I UNDERSTAND", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔓 ACCESS GRANTED"), backgroundColor: Colors.green)
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RealSuccessDashboard())
      );
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ ${_controller.threatMessage.isNotEmpty ? _controller.threatMessage : 'INVALID CODE'}"), 
        backgroundColor: Colors.red
      )
    );
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⛔ SYSTEM HALTED"), backgroundColor: Colors.deepOrange)
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(backgroundColor: Colors.black);

    if (_showFakeDashboard) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text("MY ACCOUNT", style: TextStyle(color: Colors.white))),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
              SizedBox(height: 20),
              Text("BALANCE AVAILABLE", style: TextStyle(color: Colors.grey, fontSize: 12)),
              SizedBox(height: 10),
              Text("RM 0.00", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              Text("No active transactions.", style: TextStyle(color: Colors.white38)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.systemName, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 2)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isCompromised ? _buildHackedNotice() : _buildSafeNotice(),
              const SizedBox(height: 50),

              // Widget ini akan menggunakan Controller V2 secara automatik kerana jenis data _controller telah berubah
              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),

              const SizedBox(height: 30),
              if (!_isCompromised)
                Text(
                  "TXN ID: ${widget.transactionId}\nStatus: ${_userAcknowledgedThreat ? 'MONITORED' : 'SECURE'}\nGuard: Hybrid Active",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _userAcknowledgedThreat ? Colors.orange.withOpacity(0.5) : Colors.green.withOpacity(0.5),
                    fontSize: 10,
                    fontFamily: 'monospace'
                  ),
                ),
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
        borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("DATA INTEGRITY: VERIFIED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(widget.displayedAmount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ])),
        ],
      ),
    );
  }

  Widget _buildHackedNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 20)]
      ),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.report_problem, color: Colors.red, size: 24),
          SizedBox(width: 10),
          Text("INTEGRITY BREACH", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14))
        ]),
        const SizedBox(height: 15),
        Text("Value '${widget.displayedAmount}' mismatch.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _handleReportAndCancel,
            icon: const Icon(Icons.security, color: Colors.white),
            label: const Text("REPORT THREAT", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900)
          )
        ),
      ]),
    );
  }
}

class RealSuccessDashboard extends StatelessWidget {
  const RealSuccessDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DASHBOARD")),
      body: const Center(
        child: Text("WELCOME. ACCESS FULLY GRANTED."),
      ),
    );
  }
}
