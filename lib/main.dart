import 'package:flutter/material.dart';
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptexAer Bio-Sigma',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: Colors.amber,
      ),
      home: const LockScreen(),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;

  @override
  void initState() {
    super.initState();
    // Konfigurasi BIO-SIGMA (AUDIT VERSION)
    // Parameter 'humanTremorFrequency' telah dibuang oleh Gemini kerana
    // logik dalaman Controller sekarang mengiranya secara automatik.
    _controller = ClaController(
      const ClaConfig(
        secret: [1, 7, 3, 9, 2],       
        minSolveTime: Duration(seconds: 2),
        minShake: 0.15,                 // Min shake for trigger
        thresholdAmount: 1.0,           
        jamCooldown: Duration(seconds: 5), // Hukuman Jammed: 5 Saat!
        maxAttempts: 3,
        
        // TUNING BARU (Clean Version)
        botDetectionSensitivity: 0.5,   // 0.5 = Balance
        enableSensors: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green[900],
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.white),
            SizedBox(width: 10),
            Text("BIO-SIGMA VERIFIED", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          "Identity Confirmed: HUMAN.\nMicro-tremors analysis passed.\nEntropy check passed.",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.userAcceptsRisk(); // Reset untuk demo
            },
            child: const Text("ENTER VAULT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onFail() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Access Denied: Biometric mismatch or Wrong Code"), 
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onJammed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Colors.red,
        title: Text("SECURITY LOCKOUT", style: TextStyle(color: Colors.white)),
        content: Text("Multiple failures detected.\nSystem locked to prevent brute-force."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 50, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                "AER BIO-VAULT",
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 3,
                  color: Colors.white
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Class 4 Security Protocol",
                style: TextStyle(color: Colors.grey[700], fontSize: 10),
              ),
              const SizedBox(height: 50),
              
              // WIDGET
              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),
              
              const SizedBox(height: 40),
              Text(
                "POWERED BY BIO-SIGMA ENGINE",
                style: TextStyle(color: Colors.grey[800], fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

