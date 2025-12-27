import 'dart:async';
import 'dart:math'; // WAJIB untuk kira sudut
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
  
  // --- ALGORITMA BARU: DELTA MOVEMENT (Sudut + Gegar) ---
  // Kita simpan bacaan accelerometer sebelumnya
  double _lastX = 0;
  double _lastY = 0;
  double _lastZ = 0;
  
  // Markah Kemanusiaan (0.0 - 100.0)
  double _humanScore = 0.0; 
  bool _isHuman = false;

  // SENSITIVITI (Boleh ubah jika terlalu susah/senang)
  // Lantai (ketuk): Score naik lambat (< 0.5 per frame)
  // Tangan: Score naik laju (> 2.0 per frame)
  static const double MOVEMENT_THRESHOLD = 0.3; 
  static const double DECAY_RATE = 0.5; // Markah turun kalau diam

  // WARNA
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
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      // 1. Kira perbezaan (Delta) dari bacaan terakhir
      // Ini mengukur PERUBAHAN SUDUT, bukan sekadar gegaran hentakan.
      double deltaX = (e.x - _lastX).abs();
      double deltaY = (e.y - _lastY).abs();
      double deltaZ = (e.z - _lastZ).abs();

      // Kemaskini data terakhir
      _lastX = e.x;
      _lastY = e.y;
      _lastZ = e.z;

      // 2. Jumlahkan semua perubahan
      double totalDelta = deltaX + deltaY + deltaZ;

      // 3. Sistem Pemarkahan (Score Accumulator)
      if (totalDelta > MOVEMENT_THRESHOLD) {
        // Kalau bergerak (tangan), markah naik
        _humanScore += totalDelta;
      } else {
        // Kalau diam (lantai), markah turun (reput)
        _humanScore -= DECAY_RATE;
      }

      // Kunci markah antara 0 hingga 50
      _humanScore = _humanScore.clamp(0.0, 50.0);

      // 4. Penentuan Mutlak
      // Markah mesti lebih 10.0 untuk dianggap manusia.
      // Ketuk skrin di lantai cuma bagi spike sekejap (markah naik sikit, lepas tu turun balik).
      // Pegang di tangan sentiasa bagi markah tinggi.
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
    super.dispose();
  }

  void _handleUnlock() {
    // Hantar keputusan ke Controller
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

    // Logik Paparan
    switch (state) {
      case SecurityState.LOCKED:
        if (_isHuman) {
          activeColor = _colLocked;
          statusText = "BIO-LOCK: ACTIVE";
          statusIcon = Icons.fingerprint;
        } else {
          activeColor = _colDead;
          statusText = "DEVICE STATIC (TILT PHONE)";
          statusIcon = Icons.screen_rotation; // Icon suruh pusing sikit
        }
        break;
        
      case SecurityState.VALIDATING:
        activeColor = Colors.white;
        statusText = "VERIFYING BIOMETRICS...";
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

          // --- BAR DEBUG SENSITIVITI ---
          // Ini untuk Kapten nampak beza ketuk lantai vs pegang tangan
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
                  value: _humanScore / 50.0, // Skala penuh 50
                  backgroundColor: Colors.grey[900],
                  color: _isHuman ? _colUnlock : _colJam,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "REQUIRED: 10.0", 
                style: TextStyle(color: Colors.grey[600], fontSize: 9)
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
