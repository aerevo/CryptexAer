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
  
  // SENSOR BARU: HUMAN TREMOR AVERAGING
  // Kita simpan 50 data terakhir untuk cari purata
  final List<double> _shakeHistory = [];
  double _averageShake = 0.0;
  bool _isStableSurface = true; // Default anggap di meja (Safety First)

  // Warna Status
  final Color _colLocked = const Color(0xFFFFD700);
  final Color _colFail = const Color(0xFFFF9800);
  final Color _colJam = const Color(0xFFFF3333);
  final Color _colUnlock = const Color(0xFF00E676);
  final Color _colDead = Colors.grey; 

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    // Sampling rate accelerometer biasanya 60Hz (60 kali sesaat)
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      // 1. Kira magnitud gegaran
      double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 9.8;
      double shake = (magnitude - 1.0).abs();

      // 2. Masukkan dalam sejarah (Rolling Buffer)
      _shakeHistory.add(shake);
      if (_shakeHistory.length > 50) {
        _shakeHistory.removeAt(0); // Buang data lama
      }

      // 3. Kira Purata (Average)
      // Ini yang membezakan 'Ketuk Skrin' vs 'Pegang Tangan'
      // Ketuk skrin = Spike sekejap, tapi purata rendah.
      // Pegang tangan = Sentiasa ada gegaran kecil, purata tinggi.
      double sum = _shakeHistory.fold(0, (p, c) => p + c);
      double avg = _shakeHistory.isEmpty ? 0 : sum / _shakeHistory.length;

      // THRESHOLD MAUT: 0.02
      // Di lantai: avg biasanya 0.001 - 0.005 (Sangat rendah)
      // Di tangan: avg biasanya 0.02 - 0.05 (Walaupun cuba diam)
      bool detectedSurface = avg < 0.02;

      if (mounted) {
        setState(() {
          _averageShake = avg;
          _isStableSurface = detectedSurface;
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
    // JIKA SURFACE STABIL (MEJA/LANTAI) -> GAGAL
    // Kita hantar 'false' ke controller jika ia dikesan stabil
    bool hasHumanTremor = !_isStableSurface;
    
    widget.controller.validateAttempt(hasPhysicalMovement: hasHumanTremor);
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

    // Logik Paparan Status (Real-time)
    bool isHuman = !_isStableSurface;

    switch (state) {
      case SecurityState.LOCKED:
        if (isHuman) {
          activeColor = _colLocked;
          statusText = "BIO-ID: HUMAN DETECTED";
          statusIcon = Icons.fingerprint;
        } else {
          activeColor = _colDead;
          statusText = "SURFACE DETECTED (LIFT PHONE)";
          statusIcon = Icons.phonelink_erase;
        }
        break;
        
      case SecurityState.VALIDATING:
        activeColor = Colors.white;
        statusText = "ANALYZING MICRO-TREMORS...";
        statusIcon = Icons.graphic_eq;
        isInputDisabled = true;
        break;
        
      case SecurityState.SOFT_LOCK:
        activeColor = _colFail;
        statusText = "FAILED (${widget.controller.failedAttempts}/3)";
        statusIcon = Icons.warning_amber_rounded;
        break;
        
      case SecurityState.HARD_LOCK:
        activeColor = _colJam;
        statusText = "JAMMED (${widget.controller.remainingLockoutSeconds}s)";
        statusIcon = Icons.block;
        isInputDisabled = true;
        break;
        
      case SecurityState.UNLOCKED:
        activeColor = _colUnlock;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.lock_open;
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

          // DEBUG BAR (WAJIB TENGOK)
          // Bar ini akan penuh kalau ada tangan, kosong kalau di lantai
          Column(
            children: [
              Text(
                "STABILITY INDEX: ${_averageShake.toStringAsFixed(4)}",
                style: TextStyle(
                  color: isHuman ? Colors.green : Colors.red,
                  fontSize: 10,
                  fontFamily: 'monospace'
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (_averageShake * 20).clamp(0.0, 1.0), // Scale up visual
                  backgroundColor: Colors.grey[900],
                  color: isHuman ? Colors.green : Colors.red,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                 isHuman ? "PASS" : "FAIL (TOO STABLE)",
                 style: TextStyle(color: isHuman ? Colors.green : Colors.red, fontSize: 10),
              )
            ],
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
