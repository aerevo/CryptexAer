// CREATE FILE BARU: lib/screens/fake_bank_screen.dart

import 'package:flutter/material.dart';

class FakeBankScreen extends StatefulWidget {
  const FakeBankScreen({super.key});

  @override
  State<FakeBankScreen> createState() => _FakeBankScreenState();
}

class _FakeBankScreenState extends State<FakeBankScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-redirect after 3 hours (simulate "processing")
    Future.delayed(const Duration(hours: 3), () {
      if (mounted) {
        Navigator.of(context).pop(); // Kembali ke lock screen
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FAKE SUCCESS ICON
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 100,
            ),
            const SizedBox(height: 30),
            
            // FAKE MESSAGE
            Text(
              "TRANSACTION SUCCESSFUL",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              "Processing your request...",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 40),
            
            // FAKE LOADING
            CircularProgressIndicator(color: Colors.green),
          ],
        ),
      ),
    );
  }
}
