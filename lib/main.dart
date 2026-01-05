import 'package:flutter/material.dart';
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptexAer Bank Grade',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
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
    // Konfigurasi Bank Grade
    _controller = ClaController(
      const ClaConfig(
        secret: [1, 2, 3, 4, 5],
        minSolveTime: Duration(seconds: 2),
        minShake: 0.5,
        thresholdAmount: 8000,
        enableSensors: true,
      ),
    );
  }

  void _onSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green[900],
        title: const Text("ACCESS GRANTED", style: TextStyle(color: Colors.white)),
        content: const Text("Biometric & Physics check passed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Colors.white)))
        ],
      ),
    );
  }

  void _onFail() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Authentication Failed"), backgroundColor: Colors.red),
    );
  }

  void _onJammed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Colors.red,
        title: Text("SYSTEM JAMMED", style: TextStyle(color: Colors.white)),
        content: Text("Too many failed attempts. Security lockout active."),
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
              const Icon(Icons.shield, size: 60, color: Colors.amber),
              const SizedBox(height: 20),
              const Text("CRYPTEX AER", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.amber)),
              const SizedBox(height: 40),
              
              // WIDGET UTAMA (Sudah dibetulkan - tiada 'amount')
              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),
              
              const SizedBox(height: 30),
              const Text("SECURED BY FRANCOIS PROTOCOL", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
