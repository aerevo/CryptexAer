import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk HapticFeedback
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
  late final DateTime _startTime;

  // Warna Tema
  final Color _goldColor = const Color(0xFFFFD700);
  final Color _dangerColor = const Color(0xFFFF3333);

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startListening();
  }

  void _startListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      // Normalisasi graviti (~9.8 m/s²)
      final double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 9.8;
      
      // Ambil nilai perbezaan dari 1.0G (Graviti statik)
      double shakeForce = (magnitude - 1.0).abs();

      // Hantar ke controller untuk analisis
      widget.controller.recordShakeSample(shakeForce);
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _attemptUnlock() {
    // 1. Bypass check
    if (!widget.controller.shouldRequireLock(widget.amount)) {
      widget.onSuccess();
      return;
    }

    // 2. Jammed check
    if (widget.controller.isJammed) {
      HapticFeedback.vibrate();
      widget.onJammed();
      return;
    }

    final elapsed = DateTime.now().difference(_startTime);

    // 3. VALIDASI MANUSIA (Bio-Signature)
    if (!widget.controller.validateSolveTime(elapsed) ||
        !widget.controller.validateHumanBehavior()) {
      
      // Gagal ujian manusia -> Bot dikesan -> JAM!
      widget.controller.jam();
      HapticFeedback.vibrate();
      
      // Visual feedback: Flash merah sebentar (pilihan)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ACCESS DENIED: Bio-signature mismatch'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      widget.onJammed();
      return;
    }

    // 4. VALIDASI KOD & TRAP
    if (widget.controller.verifyCode()) {
      HapticFeedback.vibrate(); // Vibrate tanda berjaya
      widget.onSuccess();
    } else {
      HapticFeedback.vibrate();
      if (widget.controller.isJammed) {
         widget.onJammed(); // Terkena trap
      } else {
         widget.onFail(); // Salah kod
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gunakan AnimatedBuilder untuk kemaskini UI bila controller berubah (cth: Jammed)
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (widget.controller.isJammed) {
          return _buildJammedUI();
        }
        return _buildInterface();
      },
    );
  }

  Widget _buildInterface() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _goldColor.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: _goldColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, color: _goldColor, size: 24),
              const SizedBox(width: 10),
              Text(
                'CRYPTEX SECURE',
                style: TextStyle(
                  color: _goldColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),

          // 5-WHEEL INTERFACE
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) => _buildSingleWheel(index)),
            ),
          ),
          
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _goldColor,
                foregroundColor: Colors.black,
              ),
              onPressed: _attemptUnlock,
              child: const Text(
                'AUTHENTICATE',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleWheel(int wheelIndex) {
    return SizedBox(
      width: 45,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 50,
        perspective: 0.005,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          HapticFeedback.vibrate(); // Haptic setiap pusingan
          final value = index % 10;
          widget.controller.updateWheel(wheelIndex, value);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final number = index % 10;
            final isZero = number == 0;
            return Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: isZero ? _dangerColor : Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildJammedUI() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF200000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dangerColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, color: _dangerColor, size: 50),
          const SizedBox(height: 20),
          Text(
            'SYSTEM LOCKED',
            style: TextStyle(
              color: _dangerColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Suspicious activity detected.\nTry again later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
