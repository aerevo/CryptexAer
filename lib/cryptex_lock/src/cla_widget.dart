import 'dart:async';
import 'dart:math';
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
  
  double _lastX = 0;
  double _lastY = 0;
  double _lastZ = 0;
  double _humanScore = 0.0; 
  bool _isHuman = false;

  static const double MOVEMENT_THRESHOLD = 0.3; 
  static const double DECAY_RATE = 0.5;

  late List<FixedExtentScrollController> _scrollControllers;

  // WARNA STATUS
  final Color _colLocked = const Color(0xFFFFD700); 
  final Color _colFail = const Color(0xFFFF9800);   
  final Color _colJam = const Color(0xFFFF3333);    
  final Color _colUnlock = const Color(0xFF00E676); 
  final Color _colDead = Colors.grey;               
  final Color _colWarning = Colors.redAccent;       // Merah Garang

  @override
  void initState() {
    super.initState();
    _initScrollControllers();
    _startListening();
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      int startVal = widget.controller.getInitialValue(index);
      return FixedExtentScrollController(initialItem: startVal);
    });
  }

  void _startListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      double deltaX = (e.x - _lastX).abs();
      double deltaY = (e.y - _lastY).abs();
      double deltaZ = (e.z - _lastZ).abs();

      _lastX = e.x;
      _lastY = e.y;
      _lastZ = e.z;

      double totalDelta = deltaX + deltaY + deltaZ;

      if (totalDelta > MOVEMENT_THRESHOLD) {
        _humanScore += totalDelta;
      } else {
        _humanScore -= DECAY_RATE;
      }

      _humanScore = _humanScore.clamp(0.0, 50.0);
      bool detectedHuman = _humanScore > 10.0;

      if (mounted) {
        setState(() {
          _isHuman = detectedHuman;
        });
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _handleUnlock() {
    widget.controller.validateAttempt(hasPhysicalMovement: _isHuman);
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

    switch (state) {
      case SecurityState.LOCKED:
        if (_isHuman) {
          activeColor = _colLocked;
          statusText = "BIO-LOCK: ACTIVE";
          statusIcon = Icons.fingerprint;
        } else {
          activeColor = _colDead;
          statusText = "DEVICE STATIC";
          statusIcon = Icons.screen_rotation; 
        }
        break;
        
      case SecurityState.VALIDATING:
        activeColor = Colors.white;
        statusText = "VERIFYING...";
        statusIcon = Icons.radar;
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
      
      // --- PAPARAN BORANG INDEMNITY ---
      case SecurityState.ROOT_WARNING:
        return _buildLiabilityWaiverUI();

      case SecurityState.COMPROMISED:
        activeColor = Colors.purple;
        statusText = "SYSTEM COMPROMISED";
        statusIcon = Icons.phonelink_erase;
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

    if (state == SecurityState.COMPROMISED) {
        return _buildCompromisedUI();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor, width: 2),
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 20)],
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
                style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("MOVEMENT SCORE", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  Text(
                    _humanScore.toStringAsFixed(1), 
                    style: TextStyle(
                      color: _isHuman ? _colUnlock : _colJam, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _humanScore / 50.0,
                  backgroundColor: Colors.grey[900],
                  color: _isHuman ? _colUnlock : _colJam,
                  minHeight: 6,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

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
                backgroundColor: isInputDisabled ? Colors.grey[900] : activeColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isInputDisabled ? null : _handleUnlock,
              child: Text(
                state == SecurityState.HARD_LOCK ? "SYSTEM LOCKED" : "AUTHENTICATE",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI BARU: AMARAN KERAS (BAPA GARANG) ---
  Widget _buildLiabilityWaiverUI() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF150505), // Merah Gelap
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent, width: 2),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.report_problem, color: Colors.redAccent, size: 50),
          const SizedBox(height: 20),
          const Text(
            "AMARAN KESELAMATAN KRITIKAL",
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.grey[800]!),
              borderRadius: BorderRadius.circular(8),
            ),
            // TEKS PEDAS DI SINI
            child: const Text(
              "Peranti ini telah dikesan TIDAK SESUAI untuk transaksi keselamatan tinggi (Rooted/Jailbroken). Sistem AerSecurity seboleh-bolehnya MENOLAK penggunaan persekitaran yang telah dikompromi ini.\n\nKami memberi akses KALI INI SAHAJA atas risiko anda sendiri. Sila dapatkan bantuan sokongan di cawangan berhampiran untuk memulihkan peranti anda ke tetapan kilang yang selamat.",
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 20),
          
          // Butang Setuju
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                // Panggil fungsi Controller untuk terima risiko
                widget.controller.userAcceptsRisk();
              },
              child: const Text(
                "SAYA SETUJU & TANGGUNG RISIKO",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onFail, // Keluar app
            child: const Text("BATAL & KELUAR", style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
    );
  }

  Widget _buildCompromisedUI() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.purple, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, color: Colors.purple, size: 40),
          SizedBox(height: 20),
          Text("AKSES DIHALANG KEKAL", style: TextStyle(color: Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildWheel(int index, Color color, bool disabled) {
    return SizedBox(
      width: 40,
      child: ListWheelScrollView.useDelegate(
        controller: _scrollControllers[index],
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
                  color: disabled ? Colors.grey[800] : (num == 0 ? _colJam : Colors.white),
                  fontSize: 26,
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
