import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Wajib untuk Haptic
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_models.dart';

class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback onSuccess;
  final VoidCallback onFail;
  final VoidCallback onJammed;

  const CryptexLock({
    super.key,
    required this.controller,
    required this.onSuccess,
    required this.onFail,
    required this.onJammed,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  
  double _lastX = 0, _lastY = 0, _lastZ = 0;
  double _humanScore = 0.0; // Ini yang "Chatgpt upgrade" buang tadi
  bool _isHuman = false;

  static const double MOVEMENT_THRESHOLD = 0.3; 
  static const double DECAY_RATE = 0.5;

  late List<FixedExtentScrollController> _scrollControllers;

  // WARNA STATUS (Canggih)
  final Color _colLocked = const Color(0xFFFFD700); 
  final Color _colFail = const Color(0xFFFF9800);   
  final Color _colJam = const Color(0xFFFF3333);    
  final Color _colUnlock = const Color(0xFF00E676); 
  final Color _colDead = Colors.grey;               

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

      _lastX = e.x; _lastY = e.y; _lastZ = e.z;
      double totalDelta = deltaX + deltaY + deltaZ;

      // Logik "Nadi" Manusia
      if (totalDelta > MOVEMENT_THRESHOLD) {
        _humanScore += totalDelta;
      } else {
        _humanScore -= DECAY_RATE;
      }

      _humanScore = _humanScore.clamp(0.0, 50.0);
      bool detectedHuman = _humanScore > 10.0;

      // Hantar data mentah ke Controller juga
      widget.controller.registerShake(totalDelta);

      if (mounted && _isHuman != detectedHuman) {
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

  void _triggerHaptic() {
    // Guna Native Haptic (Build lulus, Rasa sedap)
    HapticFeedback.selectionClick();
  }

  void _handleAuth() {
    widget.controller.validateAttempt(hasPhysicalMovement: _isHuman);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        // Callback UI Logic
        if (widget.controller.state == SecurityState.UNLOCKED) {
           Future.delayed(Duration.zero, widget.onSuccess);
        }
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
          statusText = "DEVICE STATIC"; // Kesan letak atas meja
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
      case SecurityState.UNLOCKED:
        activeColor = _colUnlock;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.lock_open;
        isInputDisabled = true;
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
              Text(statusText, style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 20),
          // Bar Sensor yang Canggih
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isInputDisabled ? Colors.grey[900] : activeColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: isInputDisabled ? null : _handleAuth,
              child: Text(state == SecurityState.HARD_LOCK ? "LOCKED" : "AUTHENTICATE", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
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
            Text("BIO-SIGMA DETECTOR", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            Text(_humanScore.toStringAsFixed(1), style: TextStyle(color: _isHuman ? _colUnlock : _colJam, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: _humanScore / 50.0,
          backgroundColor: Colors.grey[900],
          color: _isHuman ? _colUnlock : _colJam,
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildLiabilityWaiverUI() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 50),
          const SizedBox(height: 10),
          const Text("SECURITY COMPROMISED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () => widget.controller.userAcceptsRisk(), child: const Text("RISK ACCEPTED"))
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
          _triggerHaptic(); // Tik!
          widget.controller.updateWheel(index, val % 10);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            final num = i % 10;
            return Center(child: Text('$num', style: TextStyle(color: disabled ? Colors.grey : Colors.white, fontSize: 26, fontWeight: FontWeight.bold)));
          },
        ),
      ),
    );
  }
}
