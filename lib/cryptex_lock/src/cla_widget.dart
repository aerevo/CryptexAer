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
  double _lastX = 0, _lastY = 0, _lastZ = 0, _humanScore = 0.0;
  bool _isHuman = false;
  late List<FixedExtentScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    _initScrollControllers();
    _startListening();
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      return FixedExtentScrollController(initialItem: widget.controller.getInitialValue(index));
    });
  }

  void _startListening() {
    _accelSub = accelerometerEvents.listen((e) {
      double delta = (e.x - _lastX).abs() + (e.y - _lastY).abs() + (e.z - _lastZ).abs();
      _lastX = e.x; _lastY = e.y; _lastZ = e.z;
      if (delta > 0.3) _humanScore += delta; else _humanScore -= 0.5;
      _humanScore = _humanScore.clamp(0.0, 50.0);
      bool detected = _humanScore > 10.0;
      if (mounted && _isHuman != detected) setState(() => _isHuman = detected);
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  // --- FUNGSI GETARAN NATIVE (FORCE) ---
  void _triggerHaptic() {
    // HapticFeedback.vibrate() akan paksa motor bergetar (pendek & solid)
    HapticFeedback.vibrate(); 
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) => _buildStateUI(widget.controller.state),
    );
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor = (state == SecurityState.UNLOCKED) ? Colors.green : (_isHuman ? Colors.amber : Colors.grey);
    bool isDisabled = (state == SecurityState.VALIDATING || state == SecurityState.HARD_LOCK);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_isHuman ? "BIO-LOCK: ACTIVE" : "DEVICE STATIC", style: TextStyle(color: activeColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) => _buildWheel(index, activeColor, isDisabled)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: activeColor, foregroundColor: Colors.black),
            onPressed: isDisabled ? null : () => widget.controller.validateAttempt(hasPhysicalMovement: _isHuman),
            child: const Text("AUTHENTICATE"),
          ),
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
          _triggerHaptic(); // Getaran Native
          widget.controller.updateWheel(index, val % 10);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            int num = i % 10;
            return Center(child: Text('$num', style: TextStyle(color: disabled ? Colors.grey : Colors.white, fontSize: 26, fontWeight: FontWeight.bold)));
          },
        ),
      ),
    );
  }
}
