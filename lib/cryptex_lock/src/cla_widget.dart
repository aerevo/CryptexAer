import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller_v2.dart';
import 'cla_models.dart';

// ============================================
// 🎯 Z-KINETIC RESET - V102.0 (EMERGENCY FLARE)
// TUJUAN: PAKSA VISIBILITI KONTENA
// STATUS: FORCED FULL-SCREEN TEST
// ============================================

// Placeholder tetap ada supaya main.dart tidak meraung
class TutorialOverlay extends StatelessWidget {
  final bool isVisible;
  final Color color;
  const TutorialOverlay({super.key, required this.isVisible, required this.color});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SuccessScreen extends StatelessWidget {
  final String message;
  const SuccessScreen({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.green, body: Center(child: Text(message)));
  }
}

class CompactFailDialog extends StatelessWidget {
  final String message;
  final Color accentColor;
  const CompactFailDialog({super.key, required this.message, required this.accentColor});
  @override
  Widget build(BuildContext context) => const AlertDialog(title: Text("FAILED"));
}

// 🔥 WIDGET UTAMA YANG DIPANGGIL main.dart
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
    // Hamba guna ColoredBox dan Align untuk elakkan Scaffold bug
    return Container(
      color: Colors.blue, // JIKA CAPTAIN NAMPAK BIRU, WIDGET INI BERFUNGSI
      child: SizedBox.expand(
        child: Stack(
          children: [
            // KOTAK UJIAN DI TENGAH
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.yellow, // WARNA PALING TERANG
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, color: Colors.black, size: 80),
                      SizedBox(height: 20),
                      Text(
                        "V102.0",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 40,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        "TARGET ACQUIRED",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // INDIKATOR PENJURU (UNTUK CHECK ALIGNMENT)
            Positioned(
              top: 40,
              left: 20,
              child: _debugLabel("TOP-LEFT"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _debugLabel(String text) {
    return Container(
      padding: const EdgeInsets.all(4),
      color: Colors.black,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, decoration: TextDecoration.none),
      ),
    );
  }
}
