import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_models.dart';

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
  
  // SENSOR BARU: TIME-DECAY
  DateTime _lastMovementTime = DateTime.fromMillisecondsSinceEpoch(0); // Zaman purba
  double _currentShake = 0.0;

  // Warna Status
  final Color _colLocked = const Color(0xFFFFD700);
  final Color _colFail = const Color(0xFFFF9800);
  final Color _colJam = const Color(0xFFFF3333);
  final Color _colUnlock = const Color(0xFF00E676);
  final Color _colDead = Colors.grey; // Warna untuk status 'Meja/Mati'

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      // 1. Kira magnitud gegaran (tanpa graviti)
      double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 9.8;
      double shake = (magnitude - 1.0).abs();

      // 2. Tentukan ambang sensitiviti
      // 0.03 adalah sangat sensitif (nafas manusia pun boleh kesan)
      // Meja batu biasanya < 0.01
      if (shake > 0.03) {
        _lastMovementTime = DateTime.now(); // KEMASKINI MASA TERAKHIR BERGERAK
      }

      if (mounted) {
        setState(() {
          _currentShake = shake;
        });
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _handleUnlock() {
    // LOGIK PENENTU: ADAKAH BARU BERGERAK?
    final now = DateTime.now();
    final difference = now.difference(_lastMovementTime).inMilliseconds;

    // Jika kali terakhir bergerak lebih dari 1000ms (1 saat) yang lalu...
    // Bermakna telefon sedang diam di atas meja.
    bool isHoldingPhone = difference < 1000; 

    // Hantar status 'Live' ini ke Controller
    widget.controller.validateAttempt(hasPhysicalMovement: isHoldingPhone);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return _buildStateUI(widget.controller.state);
      },
    );
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor;
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;

    // Semakan Visual: Adakah telefon 'hidup' (dipegang)?
    // Kita guna logik sama (1 saat) untuk visual feedback
    bool isAlive = DateTime.now().difference(_lastMovementTime).inMilliseconds < 1000;

    switch (state) {
      case SecurityState.LOCKED:
        // Jika letak atas meja, warna jadi kelabu (DEAD)
        if (isAlive) {
          activeColor = _colLocked;
          statusText = "SECURE LOCK ACTIVE";
          statusIcon = Icons.lock_outline;
        } else {
          activeColor = _colDead;
          statusText = "LIFT DEVICE TO UNLOCK"; // Arahan jelas
          statusIcon = Icons.downloading; // Icon letak bawah
        }
        break;
        
      case SecurityState.VALIDATING:
        activeColor = Colors.white;
        statusText = "VERIFYING...";
        statusIcon = Icons.hourglass_empty;
        isInputDisabled = true;
        break;
        
      case SecurityState.SOFT_LOCK:
        activeColor = _colFail;
        statusText = "FAILED (${widget.controller.failedAttempts}/3)";
        statusIcon = Icons.warning_amber_rounded;
        break;
        
      case SecurityState.HARD_LOCK:
        activeColor = _colJam;
        statusText = "SYSTEM JAMMED (${widget.controller.remainingLockoutSeconds}s)";
        statusIcon = Icons.block;
        isInputDisabled = true;
        break;
        
      case SecurityState.UNLOCKED:
        activeColor = _colUnlock;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.check_circle_outline;
        isInputDisabled = true;
        Future.delayed(Duration.zero, widget.onSuccess);
        break;
        
      default:
        activeColor = _colLocked;
        statusText = "SYSTEM READY";
        statusIcon = Icons.lock;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeColor, width: 2),
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 15)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: activeColor),
              const SizedBox(width: 10),
              Text(
                statusText,
                style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          // DEBUG SENSOR (Untuk Kapten nampak apa berlaku)
          // Kapten boleh buang ini nanti, tapi sekarang ia penting untuk audit
          Text(
            "SENSOR: ${isAlive ? 'HUMAN HAND' : 'STATIC/TABLE'} (${_currentShake.toStringAsFixed(3)})",
            style: TextStyle(color: isAlive ? Colors.green : Colors.grey, fontSize: 10),
          ),
          
          const SizedBox(height: 10),

          SizedBox(
            height: 120,
            child: IgnorePointer(
              ignoring: isInputDisabled,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) => _buildWheel(index, activeColor, isInputDisabled)),
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isInputDisabled ? Colors.grey[800] : activeColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: isInputDisabled ? null : _handleUnlock,
              child: Text(state == SecurityState.HARD_LOCK ? "LOCKED" : "AUTHENTICATE"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel(int index, Color color, bool disabled) {
    return SizedBox(
      width: 40,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 40,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (val) {
          HapticFeedback.selectionClick();
          widget.controller.updateWheel(index, val % 10);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            final num = i % 10;
            return Center(
              child: Text(
                '$num',
                style: TextStyle(
                  color: disabled ? Colors.grey : (num == 0 ? _colJam : Colors.white),
                  fontSize: 24,
                  fontWeight: FontWeight.bold
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
