import 'package:flutter/material.dart';
// IMPORT YANG BETUL (Kita buang cla_config.dart sebab dah delete)
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart'; // Config duduk sini sekarang

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptexAer Legacy',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
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
    // Konfigurasi Canggih (Legacy)
    _controller = ClaController(
      const ClaConfig(
        secret: [1, 7, 3, 9, 2],       // PASSWORD
        minSolveTime: Duration(seconds: 2),
        minShake: 1.5,                 // Sensitiviti Gegaran
        jamCooldown: Duration(seconds: 30),
        thresholdAmount: 5000.0,
        enableSensors: true,           // Hidupkan Sensor Delta
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
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text("ACCESS GRANTED", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Welcome back, Captain Aer.\nIdentity Verified: HUMAN.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.userAcceptsRisk(); // Reset untuk demo
            },
            child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onFail() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Authentication Failed"), 
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onJammed() {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        backgroundColor: Colors.red,
        title: Text("SYSTEM JAMMED", style: TextStyle(color: Colors.white)),
        content: Text("Too many attempts or Bot Detected.\nSystem locked for 30 seconds."),
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
              const Icon(Icons.shield_moon, size: 60, color: Colors.amber),
              const SizedBox(height: 20),
              const Text(
                "AER SECURITY VAULT",
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 2,
                  color: Colors.amber
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Legacy Protocol v1.0",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 40),
              
              // WIDGET UTAMA
              CryptexLock(
                controller: _controller,
                amount: 5000, // Trigger amount
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),
              
              const SizedBox(height: 30),
              const Text(
                "SECURED BY FRANCOIS PROTOCOL",
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
