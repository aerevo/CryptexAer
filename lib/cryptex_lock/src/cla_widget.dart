import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Color _hudColor = const Color(0xFF00FF00); // Hijau Hacker

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startListening();
  }

  void _startListening() {
    // Mula dengar sensor
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      // Formula magnitud mudah
      final double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 9.8; // Normalize ke ~1G (roughly)
      
      // Tolak 1.0 (graviti) untuk dapatkan gegaran bersih (motion only)
      // Jika telefon diam, magnitude ~1.0 (graviti). Kita nak perbezaan.
      double shakeForce = (magnitude - 1.0).abs();

      widget.controller.recordShakeSample(shakeForce);
      // Controller akan notify listeners, jadi UI akan rebuild automatik
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _attemptUnlock() {
    if (!widget.controller.shouldRequireLock(widget.amount)) {
      widget.onSuccess();
      return;
    }

    if (widget.controller.isJammed) {
      HapticFeedback.vibrate();
      widget.onJammed();
      return;
    }

    final elapsed = DateTime.now().difference(_startTime);
    
    // DEBUG LOG
    print("ATTEMPT: Time=${elapsed.inSeconds}s | Human=${widget.controller.validateHumanBehavior()}");

    // 1. VALIDASI MANUSIA
    if (!widget.controller.validateSolveTime(elapsed) ||
        !widget.controller.validateHumanBehavior()) {
      
      // Jika gagal pengesahan manusia
      widget.controller.jam();
      HapticFeedback.vibrate();
      
      // Tunjuk snackbar untuk debug kenapa gagal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BOT DETECTED: No significant movement!'), backgroundColor: Colors.red),
      );
      
      widget.onJammed();
      return;
    }

    // 2. VALIDASI KOD
    if (widget.controller.verifyCode()) {
      HapticFeedback.vibrate(); 
      widget.onSuccess();
    } else {
      if (widget.controller.isJammed) {
         HapticFeedback.vibrate();
         widget.onJammed();
      } else {
         HapticFeedback.vibrate();
         
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WRONG CODE'), backgroundColor: Colors.orange),
         );
         
         widget.onFail();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild bila controller update (untuk sensor text)
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
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person, color: _goldColor, size: 24),
              const SizedBox(width: 10),
              Text('CLA SECURE V3', style: TextStyle(color: _goldColor, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
            ],
          ),
          
          // SENSOR HUD (DEBUG MODE) - SUPAYA KAPTEN NAMPAK
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSensorValue("FORCE", widget.controller.debugCurrentShake),
                _buildSensorValue("PEAK", widget.controller.debugMaxShake),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // WHEELS
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) => _buildSingleWheel(index)),
            ),
          ),
          
          const SizedBox(height: 30),

          // BUTTON
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _goldColor, foregroundColor: Colors.black),
              onPressed: _attemptUnlock,
              child: const Text('ENGAGE LOCK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorValue(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Text(
          value.toStringAsFixed(3), 
          style: TextStyle(
            color: value > 0.15 ? _hudColor : Colors.red, // Hijau jika cukup kuat
            fontFamily: 'Courier', 
            fontWeight: FontWeight.bold
          ),
        ),
      ],
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
          // PAKSA VIBRATE (Kuat)
          HapticFeedback.vibrate(); 
          
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
      color: const Color(0xFF200000),
      child: Center(
        child: Text(
          'JAMMED\nBOT DETECTED',
          textAlign: TextAlign.center,
          style: TextStyle(color: _dangerColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
