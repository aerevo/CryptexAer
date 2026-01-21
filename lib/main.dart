// 🛡️ Z-KINETIC V3.2 (FIREBASE BLACK BOX)
// Status: BUILD FIXED ✅

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

// 🔥 FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // ✅ DITAMBAH: Kunci Pintu Utama

import 'cryptex_lock/cryptex_lock.dart' hide ClaController;
import 'cryptex_lock/src/cla_controller_v2.dart';
import 'cryptex_lock/src/device_integrity_attestation.dart';
import 'cryptex_lock/src/server_attestation_provider.dart';
import 'cryptex_lock/src/composite_attestation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ DIKEMASKINI: Memuatkan konfigurasi dari firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  try {
    await FirebaseAuth.instance.signInAnonymously();
    if (kDebugMode) print('🔥 Firebase authenticated');
  } catch (e) {
    if (kDebugMode) print('⚠️ Firebase auth error: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await IncidentStorage.database;
    if (kDebugMode) print("🛡️ Local storage initialized.");
  } catch (e) {
    if (kDebugMode) print("⚠️ Database Error: $e");
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
      ),
      home: const BootLoader(),
    );
  }
}

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
          systemName: "FIREBASE BLACK BOX",
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
            Text("FIREBASE BLACK BOX...", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

// ============================================
// LOCK SCREEN (UNCHANGED)
// ============================================

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
  late ClaController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final deviceProvider = DeviceIntegrityAttestation(
      allowDebugMode: kDebugMode,
      allowEmulators: false,
    );

    final serverProvider = ServerAttestationProvider(
      ServerAttestationConfig(
        endpoint: const String.fromEnvironment(
          'ZK_API_ENDPOINT',
          defaultValue: 'https://api.z-kinetic.com/v1/unlock'
        ),
        apiKey: const String.fromEnvironment(
          'ZK_API_KEY',
          defaultValue: ''
        ),
      ),
    );

    final compositeProvider = CompositeAttestationProvider(
      [deviceProvider, serverProvider],
      strategy: AttestationStrategy.ALL_MUST_PASS,
    );

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
        clientSecret: const String.fromEnvironment(
          'ZK_CLIENT_SECRET',
          defaultValue: 'DEV_MODE_UNSECURED'
        ),
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

  void _onSuccess() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🔓 ACCESS GRANTED"), backgroundColor: Colors.green)
    );
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ INVALID CODE"), backgroundColor: Colors.red)
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

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.systemName, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
