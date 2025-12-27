import 'dart:async';
import 'dart:math'; // WAJIB UNTUK FORMULA MATEMATIK
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
  
  // DATA SENSOR
  final List<double> _history = [];
  double _currentStdDev = 0.0; // Nilai Sisihan Piawai Semasa
  bool _isHuman = false;       // Keputusan Akhir

  // CONFIG SENSITIVITI
  // 0.002 adalah sangat rendah. Lantai biasanya < 0.002. Tangan > 0.005.
  static const double HUMAN_THRESHOLD = 0.005; 

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
      // 1. Kira Magnitud Mentah
      // Kita tak tolak 1.0 disini, sebab kita nak tengok variasi, bukan nilai asal.
      double magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

      // 2. Simpan 50 sampel terakhir (kurang 1 saat data)
      _history.add(magnitude);
      if (_history.length > 50) {
        _history.removeAt(0);
      }

      // 3. KIRA SISIHAN PIAWAI (STANDARD DEVIATION)
      // Ini adalah jantung algoritma baru.
      if (_history.length > 2) {
        // A. Cari Min (Purata)
        double mean = _history.reduce((a, b) => a + b) / _history.length;
        
        // B. Cari Varians (Jarak setiap titik dari Min)
        double variance = _history.map((x) => (x - mean) * (x - mean))
                                  .reduce((a, b) => a + b) / _history.length;
        
        // C. Sisihan Piawai = Punca Kuasa Varians
        double stdDev = sqrt(variance);

        // 4. BANDING DENGAN AMBANG
        bool detectedHuman = stdDev > HUMAN_THRESHOLD;

        if (mounted) {
          setState(() {
            _currentStdDev = stdDev;
            _isHuman = detectedHuman;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _handleUnlock() {
    // Hantar status Holding Phone ke Controller
    // Kalau _isHuman FALSE (Lantai), sistem akan JAMMED.
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
          statusText = "BIO-METRIC: ACTIVE";
          statusIcon = Icons.fingerprint;
        } else {
          activeColor = _colDead;
          statusText = "DEVICE IS STATIC (LIFT UP)";
          statusIcon = Icons.place;
        }
        break;
        
      case SecurityState.VALIDATING:
        activeColor = Colors.white;
        statusText = "ANALYZING STABILITY...";
        statusIcon = Icons.query_stats;
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
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor, width: 2),
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.15), blurRadius: 20)],
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

          // --- LIVE DEBUG PANEL (UNTUK KAPTEN) ---
          // Tengok nombor ni. Kalau lantai, dia mesti 0.00something
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("VARIANCE (STD-DEV)", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text(
                      _currentStdDev.toStringAsFixed(5), // Tunjuk 5 titik perpuluhan
                      style: TextStyle(
                        color: _isHuman ? _colUnlock : _colJam,
                        fontSize: 16,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("THRESHOLD", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    const Text("0.00500", style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
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
                  color: disabled ? Colors.grey[700] : (num == 0 ? _colJam : Colors.white),
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
