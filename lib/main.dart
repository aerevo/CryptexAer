// 🛡️ Z-KINETIC INTELLIGENCE HUB V3.2 (FIREBASE BLACK BOX)
// Status: PRODUCTION READY WITH FIREBASE ✅

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

// 🔥 FIREBASE INITIALIZATION (NEW!)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cryptex_lock/cryptex_lock.dart' hide ClaController;
import 'cryptex_lock/src/cla_controller_v2.dart';
import 'cryptex_lock/src/device_integrity_attestation.dart';
import 'cryptex_lock/src/server_attestation_provider.dart';
import 'cryptex_lock/src/composite_attestation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INITIALIZE FIREBASE
  await Firebase.initializeApp();
  
  // 🔥 ANONYMOUS AUTHENTICATION (Required for Cloud Functions)
  try {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    if (kDebugMode) {
      print('🔥 Firebase authenticated: ${userCredential.user?.uid}');
    }
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const BootLoader(),
    );
  }
}

// REST OF THE CODE REMAINS THE SAME
// (BootLoader, LockScreen, etc - no changes needed!)

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
          systemName: "FIREBASE BLACK BOX SECURE",
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
              "INITIALIZING FIREBASE BLACK BOX...",
              style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 10)
            ),
          ],
        ),
      ),
    );
  }
}

// NOTE: LockScreen and other widgets remain UNCHANGED
// They automatically use the new FirebaseBlackBoxClient through ClaController
