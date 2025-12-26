// lib/cryptex_lock/src/cla_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';

class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback onSuccess;
  final VoidCallback onFail;
  final VoidCallback onJammed;
  final double amount;

  const CryptexLock({
    super.key,
    required this.controller,
    required this.onSuccess,
    required this.onFail,
    required this.onJammed,
    required this.amount,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _shakeSum = 0.0;
  int _shakeCount = 0;
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startListening();
  }

  void _startListening() {
    // Menggunakan accelerometerEvents dari sensors_plus
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      // Mengira magnitud mutlak
      final double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 3.0;
      
      setState(() {
        _shakeSum += magnitude;
        _shakeCount++;
      });
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _attemptUnlock() {
    // Semak sama ada perlu kunci atau tidak berdasarkan amaun
    if (!widget.controller.shouldRequireLock(widget.amount)) {
      widget.onSuccess();
      return;
    }

    // Semak jika sistem sedang 'jammed'
    if (widget.controller.isJammed) {
      widget.onJammed();
      return;
    }

    final elapsed = DateTime.now().difference(_startTime);
    
    // PENGIRAAN KRITIKAL: Pastikan hasil bahagi adalah double
    final double avgShake = _shakeCount == 0 ? 0.0 : (_shakeSum / _shakeCount).toDouble();

    // Validasi Kelakuan Manusia (Masa & Gegaran)
    // Note: validateShake di controller mungkin perlu akses config, pastikan controller update
    // Di sini kita hantar avgShake yang sudah pasti double
    if (!widget.controller.validateSolveTime(elapsed) ||
        !widget.controller.validateShake(avgShake)) {
      
      // Jika gagal kriteria manusia -> anggap bot -> JAM!
      widget.controller.jam();
      widget.onJammed();
      return;
    }

    // Jika semua lulus
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CRYPTEX SECURITY',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 30),
          // Placeholder untuk UI Roda 5-Column (Akan datang)
          Container(
            height: 100,
            alignment: Alignment.center,
            child: const Text(
              '[ 5-WHEEL INTERFACE ]',
              style: TextStyle(color: Colors.white24),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: _attemptUnlock,
              child: const Text(
                'VERIFY IDENTITY',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
