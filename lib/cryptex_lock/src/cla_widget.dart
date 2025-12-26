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
  double _maxShake = 0.0;
  bool _hasMoved = false;

  // Warna Tema Mewah
  final Color _goldStart = const Color(0xFFFFD700);
  final Color _goldEnd = const Color(0xFFFFA500);
  final Color _dangerColor = const Color(0xFFFF3333);
  final Color _botColor = const Color(0xFF00BCD4); // Biru Cyber untuk Bot

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 9.8;
      double movement = (magnitude - 1.0).abs();

      if (movement > _maxShake) {
        _maxShake = movement;
      }
      if (movement > 0.10) {
        setState(() {
          _hasMoved = true;
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
    // Jika bot sedang berjalan, jangan ganggu
    if (widget.controller.isBotRunning) return;

    if (widget.controller.isJammed) {
      HapticFeedback.vibrate();
      widget.onJammed();
      return;
    }

    // DEAD BOT CHECK: Kalau telefon tak pernah bergerak -> BOT
    if (!_hasMoved) {
      widget.controller.jam();
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BOT DETECTED: No physical movement!'), backgroundColor: Colors.red),
      );
      widget.onJammed();
      return;
    }

    // HONEYPOT CHECK
    if (widget.controller.isTrapTriggered()) {
      widget.controller.jam();
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TRAP TRIGGERED: Avoid Zero!'), backgroundColor: Colors.red),
      );
      widget.onJammed();
      return;
    }

    // CODE CHECK
    if (widget.controller.isCodeCorrect()) {
      HapticFeedback.mediumImpact();
      widget.onSuccess();
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WRONG CODE'), backgroundColor: Colors.orange),
      );
      widget.onFail();
    }
  }

  @override
  Widget build(BuildContext context) {
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
    bool isBot = widget.controller.isBotRunning;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Lebih gelap untuk kontras emas
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBot ? _botColor : _goldStart.withOpacity(0.6), 
          width: 3
        ),
        boxShadow: [
          BoxShadow(
            color: isBot ? _botColor.withOpacity(0.2) : _goldStart.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header dengan status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isBot ? Icons.smart_toy : Icons.lock_outline_rounded, 
                   color: isBot ? _botColor : _goldStart, size: 28),
              const SizedBox(width: 10),
              Text(
                isBot ? 'BOT ATTACKING...' : 'GOLD CRYPTEX',
                style: TextStyle(
                  color: isBot ? _botColor : _goldStart,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),

          // --- RODA EMAS 3D ---
          SizedBox(
            height: 180, // Lebih tinggi untuk nampak curve
            child: Stack(
              children: [
                // Highlight Tengah (Magnifying Glass Effect)
                Center(
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: _goldStart.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _goldStart.withOpacity(0.3)),
                    ),
                  ),
                ),
                // Roda Sebenar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) => _build3DGoldWheel(index)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),

          // Butang Utama (Unlock Manusia)
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _goldStart,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 8,
                shadowColor: _goldStart.withOpacity(0.5),
              ),
              onPressed: isBot ? null : _attemptUnlock, // Disable jika bot tengah jalan
              child: const Text('ENGAGE PROTOCOL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),

          const SizedBox(height: 16),

          // BUTANG BARU: SIMULASI BOT
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _dangerColor,
                side: BorderSide(color: _dangerColor.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.bug_report),
              label: const Text('SIMULATE BOT ATTACK (TEST)'),
              onPressed: isBot ? null : () {
                // Reset sensor movement dulu untuk simulasi bot sebenar (meja mati)
                 setState(() { _hasMoved = false; _maxShake = 0.0; });
                 
                 // Jalankan simulasi
                 widget.controller.simulateBotAttack(_attemptUnlock);
              },
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET RODA 3D EMAS
  Widget _build3DGoldWheel(int wheelIndex) {
    return SizedBox(
      width: 55,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 60,
        perspective: 0.003, // Efek 3D (semakin kecil semakin melengkung)
        diameterRatio: 1.5,
        offAxisFraction: -0.4, // Ini yang buat dia melengkung macam iOS calendar
        physics: widget.controller.isBotRunning 
            ? const NeverScrollableScrollPhysics() // Kunci roda bila bot jalan
            : const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          if (!widget.controller.isBotRunning) {
            HapticFeedback.selectionClick(); // Tik halus ala iOS
            widget.controller.updateWheel(wheelIndex, index % 10);
          }
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final number = index % 10;
            final isZero = number == 0;
            
            // Bina Teks Emas menggunakan ShaderMask (Kecerunan Logam)
            Widget goldText = ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isZero 
                    ? [_dangerColor, _dangerColor.withOpacity(0.7)] // Merah untuk Zero
                    : [_goldStart, _goldEnd, _goldStart], // Emas pantul cahaya
              ).createShader(bounds),
              child: Text(
                '$number',
                style: TextStyle(
                  // Warna putih di sini hanya placeholder untuk shader
                  color: Colors.white, 
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  shadows: [
                     Shadow(blurRadius: 10, color: isZero ? Colors.red : Colors.amber, offset: const Offset(0, 2))
                  ]
                ),
              ),
            );

            return Center(child: goldText);
          },
        ),
      ),
    );
  }

  Widget _buildJammedUI() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF2A0000), // Merah darah gelap
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dangerColor, width: 3),
        boxShadow: [BoxShadow(color: _dangerColor.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_encryption_gmailerrorred, color: _dangerColor, size: 60),
          const SizedBox(height: 20),
          Text(
            'INTRUSION DETECTED',
            style: TextStyle(color: _dangerColor, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0),
          ),
          const SizedBox(height: 15),
          const Text(
            'Automated attack pattern recognized.\nSystem locked for 60 seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
