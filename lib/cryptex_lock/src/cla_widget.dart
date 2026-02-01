import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller_v2.dart';
import 'cla_models.dart';

// ============================================
// 🎯 Z-KINETIC RESET - PLACEHOLDER MODE
// VERSION: V101.0 (BACK TO BASICS)
// STATUS: PREVENTING MAIN.DART ERRORS
// ============================================

// Placeholder untuk TutorialOverlay supaya main.dart tidak error
class TutorialOverlay extends StatelessWidget {
  final bool isVisible;
  final Color color;
  const TutorialOverlay({super.key, required this.isVisible, required this.color});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// Placeholder untuk SuccessScreen supaya navigation tidak crash
class SuccessScreen extends StatelessWidget {
  final String message;
  const SuccessScreen({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text("SUCCESS: $message")),
    );
  }
}

// Placeholder untuk CompactFailDialog
class CompactFailDialog extends StatelessWidget {
  final String message;
  final Color accentColor;
  const CompactFailDialog({super.key, required this.message, required this.accentColor});
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(message));
}

// 🔥 MAIN WIDGET - ENTRY POINT FOR main.dart
class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;
  final VoidCallback? onJammed;

  const CryptexLock({
    super.key, 
    required this.controller,
    this.onSuccess,
    this.onFail,
    this.onJammed,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Latar belakang hitam pekat
      backgroundColor: Colors.black, 
      
      // Memastikan content duduk di tengah-tengah skrin
      body: Center(
        child: Container(
          // Hardcoded size untuk memastikan ia tidak 'collapse'
          width: 300,
          height: 300,
          
          decoration: BoxDecoration(
            color: Colors.deepOrange, // Warna pilihan Francois
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 5,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 60),
                SizedBox(height: 20),
                Text(
                  "BASE RESET",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Z-KINETIC PROJECT",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
