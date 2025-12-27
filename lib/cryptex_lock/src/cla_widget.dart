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
  bool _hasMoved = false;

  // Warna Status (Indikator Paling Jelas)
  final Color _colLocked = const Color(0xFFFFD700); // Emas
  final Color _colFail = const Color(0xFFFF9800);   // Oren
  final Color _colJam = const Color(0xFFFF3333);    // Merah Darah
  final Color _colUnlock = const Color(0xFF00E676); // Hijau

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 9.8;
      if ((magnitude - 1.0).abs() > 0.05) {
        if (mounted) setState(() => _hasMoved = true);
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _handleUnlock() {
    // Panggil Enjin Validasi
    widget.controller.validateAttempt(hasPhysicalMovement: _hasMoved);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        // Bina UI berdasarkan State Mesin
        return _buildStateUI(widget.controller.state);
      },
    );
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor;
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;

    // --- LOGIK STATUS VISUAL ---
    switch (state) {
      case SecurityState.LOCKED:
        activeColor = _colLocked;
        statusText = "SECURE LOCK ACTIVE";
        statusIcon = Icons.lock_outline;
        break;
        
      case SecurityState.VALIDATING:
        activeColor = Colors.white;
        statusText = "VERIFYING...";
        statusIcon = Icons.hourglass_empty;
        isInputDisabled = true;
        break;
        
      case SecurityState.SOFT_LOCK: // FAIL
        activeColor = _colFail;
        // Tunjuk baki nyawa (PENTING)
        statusText = "FAILED (${widget.controller.failedAttempts}/3)";
        statusIcon = Icons.warning_amber_rounded;
        break;
        
      case SecurityState.HARD_LOCK: // JAM
        activeColor = _colJam;
        statusText = "SYSTEM JAMMED (${widget.controller.remainingLockoutSeconds}s)";
        statusIcon = Icons.block;
        isInputDisabled = true; // Roda & Button mati
        break;
        
      case SecurityState.UNLOCKED:
        activeColor = _colUnlock;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.check_circle_outline;
        isInputDisabled = true;
        // Panggil callback kejayaan selepas UI render
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
        border: Border.all(color: activeColor, width: 2), // Border bertukar warna ikut status
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 15)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. HEADER STATUS
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

          // 2. RODA (Input)
          SizedBox(
            height: 120,
            child: IgnorePointer(
              ignoring: isInputDisabled, // Matikan input jika JAMMED/VALIDATING
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) => _buildWheel(index, activeColor, isInputDisabled)),
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          // 3. BUTANG (Action)
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
