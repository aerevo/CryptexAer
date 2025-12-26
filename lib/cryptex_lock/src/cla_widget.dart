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
  double _shakeSum = 0.0;
  int _shakeCount = 0;
  late final DateTime _startTime;

  // Warna Tema (Emas Cyberpunk)
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
      // Mengira magnitud mutlak
      final double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 3.0;
      
      if (mounted) {
        setState(() {
          _shakeSum += magnitude;
          _shakeCount++;
        });
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _attemptUnlock() {
    // 1. Bypass jika amaun kecil
    if (!widget.controller.shouldRequireLock(widget.amount)) {
      widget.onSuccess();
      return;
    }

    // 2. Semak status JAM
    if (widget.controller.isJammed) {
      HapticFeedback.heavyImpact(); // Gegar kuat tanda ralat
      widget.onJammed();
      return;
    }

    final elapsed = DateTime.now().difference(_startTime);
    final double avgShake = _shakeCount == 0 ? 0.0 : (_shakeSum / _shakeCount).toDouble();

    // 3. Validasi Manusia (Inersia Masa & Gegaran Fizikal)
    if (!widget.controller.validateSolveTime(elapsed) ||
        !widget.controller.validateShake(avgShake)) {
      
      // Gagal ujian manusia -> Bot dikesan -> JAM!
      widget.controller.jam();
      HapticFeedback.heavyImpact();
      widget.onJammed();
      return;
    }

    // 4. Validasi Kod Roda & Perangkap Zero
    if (widget.controller.verifyCode()) {
      HapticFeedback.success(); // Gegar kejayaan
      widget.onSuccess();
    } else {
      // Jika salah kod ATAU terkena perangkap Zero
      if (widget.controller.isJammed) {
         widget.onJammed(); // Kena trap
      } else {
         HapticFeedback.vibrate(); // Gegar ralat biasa
         widget.onFail();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Jika Jammed, tunjuk UI Merah (Lockdown)
    if (widget.controller.isJammed) {
      return _buildJammedUI();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Dark Metal Grey
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person, color: _goldColor, size: 24),
              const SizedBox(width: 10),
              Text(
                'CRYPTEX VERIFICATION',
                style: TextStyle(
                  color: _goldColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontFamily: 'Courier', // Monospace font nampak teknikal
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          Text(
            'Rotate to match sequence. Avoid ZERO.',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
          
          const SizedBox(height: 30),

          // --- 5-WHEEL INTERFACE ---
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) => _buildSingleWheel(index)),
            ),
          ),
          
          const SizedBox(height: 30),

          // Unlock Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _goldColor,
                foregroundColor: Colors.black,
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _attemptUnlock,
              child: const Text(
                'ENGAGE LOCK',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget Roda Individu
  Widget _buildSingleWheel(int wheelIndex) {
    return SizedBox(
      width: 45,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 50,
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          // Bunyi "Tik" halus bila pusing (Haptic)
          HapticFeedback.selectionClick();
          
          // Dapatkan nilai sebenar (0-9)
          final value = index % 10;
          widget.controller.updateWheel(wheelIndex, value);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final number = index % 10;
            // Highlight '0' dengan warna merah samar (Amaran visual)
            final isZero = number == 0;
            
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
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

  // UI bila sistem JAMMED
  Widget _buildJammedUI() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF200000), // Dark Red
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dangerColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_encryption_gmailerrorred, color: _dangerColor, size: 50),
          const SizedBox(height: 20),
          Text(
            'SYSTEM JAMMED',
            style: TextStyle(
              color: _dangerColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Non-human behavior detected.\nTry again in 2 minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
