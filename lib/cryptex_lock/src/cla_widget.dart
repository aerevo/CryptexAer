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
  final Color _colWarning = Colors.redAccent;

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
          _buildScoreBar(activeColor),
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
          _buildAuthButton(state, activeColor, isInputDisabled),
        ],
      ),
    );
  }

  Widget _buildScoreBar(Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("MOVEMENT SCORE", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            Text(
              _humanScore.toStringAsFixed(1), 
              style: TextStyle(color: _isHuman ? _colUnlock : _colJam, fontWeight: FontWeight.bold)
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
    );
  }

  Widget _buildAuthButton(SecurityState state, Color activeColor, bool isInputDisabled) {
    return SizedBox(
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
    );
  }

  // --- BORANG MAUT VERSI AER KORPORAT ---
  Widget _buildLiabilityWaiverUI() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF150505),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent, width: 2),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 30)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gpp_maybe, color: Colors.redAccent, size: 60),
          const SizedBox(height: 20),
          const Text(
            "PERANTI TIDAK DISOKONG",
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "Sistem AerSecurity mengesan persekitaran peranti anda telah diubahsuai (Root/Developer Mode). Kami seboleh-bolehnya MENOLAK akses bagi menjamin keselamatan data perbankan.\n\n"
              "Akses ini diberikan KALI INI SAHAJA sebagai kelonggaran khas. Sila MATIKAN 'Developer Settings' dan pastikan peranti anda tidak di-root untuk penggunaan masa hadapan.\n\n"
              "Sila dapatkan sokongan teknikal di cawangan (Branch) berhampiran jika masalah berterusan.",
              style: TextStyle(color: Colors.white, fontSize: 12, height: 1.6),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => widget.controller.userAcceptsRisk(),
              child: const Text("SAYA FAHAM & SETUJU TANGGUNG RISIKO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onFail,
            child: const Text("KELUAR DARI SISTEM", style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
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
          // BILLION DOLLAR TOUCH: Guna mediumImpact untuk rasa 'solid'
          HapticFeedback.mediumImpact(); 
          widget.controller.updateWheel(index, val % 10);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            final num = i % 10;
            return Center(
              child: Text(
                '$num',
                style: TextStyle(
                  color: disabled ? Colors.grey[800] : (num == 0 ? Colors.red : Colors.white),
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

  Widget _buildCompromisedUI() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.purple, width: 2), borderRadius: BorderRadius.circular(20)),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security_update_warning, color: Colors.purple, size: 50),
          SizedBox(height: 20),
          Text("SYSTEM HARD-LOCKED", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text("Peranti anda tidak lagi dibenarkan mengakses perisian ini.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
