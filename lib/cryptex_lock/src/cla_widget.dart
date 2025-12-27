import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_models.dart'; // Import Model untuk faham status

class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback onSuccess;
  final VoidCallback onFail;
  final VoidCallback onJammed; // Callback bila Hard Lock (Jammed)
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
  
  // Data Sensor UI
  bool _hasMoved = false; // Adakah manusia pegang phone?
  double _currentShake = 0.0;
  DateTime? _startInteractTime;

  // Warna Tema Diraja (Royal Gold & Deep Black)
  final Color _goldPrimary = const Color(0xFFFFD700);
  final Color _goldAccent = const Color(0xFFFFA000);
  final Color _bgDark = const Color(0xFF0F0F0F);
  final Color _dangerRed = const Color(0xFFFF3B30);
  final Color _warnOrange = const Color(0xFFFF9500);
  final Color _botCyan = const Color(0xFF00F0FF);

  @override
  void initState() {
    super.initState();
    _startListening();
    _startInteractTime = DateTime.now();
  }

  void _startListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      // Normalisasi graviti
      double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 9.8;
      double shake = (magnitude - 1.0).abs();

      if (mounted) {
        setState(() {
          _currentShake = shake;
          // Sensitiviti: 0.05 cukup untuk kesan tangan manusia vs meja
          if (shake > 0.05) {
            _hasMoved = true;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  // Fungsi Utama: Tekan Butang
  void _handleUnlockPress() {
    // 1. Reset interaksi masa jika baru mula
    final duration = DateTime.now().difference(_startInteractTime ?? DateTime.now());

    // 2. Hantar semua data ke Blackbox Controller
    widget.controller.validateAttempt(
      hasPhysicalMovement: _hasMoved,
      solveTime: duration,
    ).then((_) {
      // 3. Semak status selepas validasi selesai
      if (widget.controller.state == SecurityState.UNLOCKED) {
         HapticFeedback.heavyImpact(); // Gegar kejayaan
         widget.onSuccess();
      } else if (widget.controller.state == SecurityState.HARD_LOCK) {
         HapticFeedback.vibrate();
         widget.onJammed(); // Lapor ke main app
      } else {
         HapticFeedback.lightImpact(); // Gagal biasa / Soft lock
         widget.onFail();
      }
    });
  }

  // Fungsi Ujian: Bot Simulation
  void _runBotTest() {
    // Reset sensor seolah-olah diletak di meja (mati)
    setState(() {
      _hasMoved = false;
      _currentShake = 0.0;
    });
    
    // Arahkan controller buat simulasi
    widget.controller.startBotSimulation(() {
      // Bila bot habis pusing, dia akan cuba unlock sendiri
      // Kita akan lihat hasilnya (pasti GAGAL sebab _hasMoved = false)
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        // Bina UI berdasarkan Status Blackbox (State Machine)
        return _buildResponsiveUI(widget.controller.state);
      },
    );
  }

  Widget _buildResponsiveUI(SecurityState state) {
    // Tentukan Warna & Teks Status
    Color statusColor = _goldPrimary;
    String statusText = "SECURE ENCLAVE";
    IconData statusIcon = Icons.lock_outline;
    bool isInputDisabled = false;

    switch (state) {
      case SecurityState.LOCKED:
        statusColor = _goldPrimary;
        statusText = "GOLD CRYPTEX";
        break;
      case SecurityState.VALIDATING:
        statusColor = Colors.white;
        statusText = "VERIFYING...";
        statusIcon = Icons.hourglass_top;
        isInputDisabled = true;
        break;
      case SecurityState.SOFT_LOCK:
        statusColor = _warnOrange;
        statusText = "INVALID CODE";
        statusIcon = Icons.warning_amber;
        break;
      case SecurityState.HARD_LOCK:
        statusColor = _dangerRed;
        statusText = "SYSTEM JAMMED";
        statusIcon = Icons.block;
        isInputDisabled = true;
        break;
      case SecurityState.BOT_SIMULATION:
        statusColor = _botCyan;
        statusText = "BOT ATTACK TEST";
        statusIcon = Icons.smart_toy;
        isInputDisabled = true;
        break;
      case SecurityState.UNLOCKED:
        statusColor = Colors.greenAccent;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.lock_open;
        isInputDisabled = true;
        break;
    }

    // Jika HARD LOCK, tunjuk UI Merah Penuh
    if (state == SecurityState.HARD_LOCK) {
      return _buildHardLockUI();
    }

    // UI Standard (Emas)
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withOpacity(0.5), 
          width: 2
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. STATUS HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 25),

          // 2. THE GOLDEN CYLINDER (iOS STYLE)
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Highlight Bar (Kaca Pembesar)
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _goldPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.symmetric(
                      horizontal: BorderSide(color: _goldPrimary.withOpacity(0.5), width: 1),
                    ),
                  ),
                ),
                
                // Roda Berputar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) => _buildIOSWheel(index, isInputDisabled)),
                ),
                
                // Overlay Kilauan (Glossy Reflection)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.0, 0.4, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),

          // 3. ACTION BUTTON
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.black,
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: isInputDisabled ? null : _handleUnlockPress,
              child: state == SecurityState.VALIDATING
                  ? const SizedBox(
                      height: 20, 
                      width: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                    )
                  : const Text(
                      'AUTHENTICATE',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
            ),
          ),

          // 4. BOT TEST BUTTON (Hidden Feature)
          if (state == SecurityState.LOCKED || state == SecurityState.BOT_SIMULATION)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: TextButton.icon(
                icon: Icon(Icons.bug_report, color: Colors.grey[800], size: 16),
                label: Text(
                  state == SecurityState.BOT_SIMULATION ? "RUNNING SIMULATION..." : "SIMULATE BOT ATTACK",
                  style: TextStyle(color: Colors.grey[800], fontSize: 10),
                ),
                onPressed: state == SecurityState.BOT_SIMULATION ? null : _runBotTest,
              ),
            ),
        ],
      ),
    );
  }

  // WIDGET RODA iOS (3D Curve)
  Widget _buildIOSWheel(int wheelIndex, bool disabled) {
    return SizedBox(
      width: 50,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 50,
        perspective: 0.003, // Efek Lengkung 3D Silinder
        diameterRatio: 1.2, // Roda padat
        useMagnifier: true, // Besar di tengah
        magnification: 1.2,
        physics: disabled 
          ? const NeverScrollableScrollPhysics() 
          : const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          if (!disabled) {
            HapticFeedback.selectionClick(); // Bunyi tik iOS
            widget.controller.updateWheel(wheelIndex, index % 10);
            
            // Reset masa mula interaksi bila user sentuh roda
            _startInteractTime = DateTime.now();
          }
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final number = index % 10;
            final isZero = number == 0;
            
            // Style Nombor
            return Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  // Jika disabled (Bot), warna jadi pudar atau Cyan
                  color: disabled 
                      ? (widget.controller.state == SecurityState.BOT_SIMULATION ? _botCyan : Colors.grey)
                      : (isZero ? _dangerRed : Colors.white), 
                  shadows: [
                    if (!disabled && !isZero)
                      Shadow(color: _goldPrimary.withOpacity(0.5), blurRadius: 10)
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // WIDGET KHAS UNTUK JAMMED (HARD LOCK)
  Widget _buildHardLockUI() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF200000), // Merah Gelap
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _dangerRed, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, color: _dangerRed, size: 48),
          const SizedBox(height: 20),
          Text(
            'SYSTEM LOCKDOWN',
            style: TextStyle(
              color: _dangerRed,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Threat Detected.\nWait ${widget.controller.remainingLockoutTime}s',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(color: _dangerRed, backgroundColor: Colors.black),
        ],
      ),
    );
  }
}
