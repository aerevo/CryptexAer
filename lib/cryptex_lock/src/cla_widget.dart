import 'dart:async';
import 'package:flutter/material.dart';
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
  late final StreamSubscription _accelSub;
  double _shakeSum = 0;
  int _shakeCount = 0;
  late final DateTime _startTime;

  final List<String> _wheelItems = [
    'API',
    'AIR',
    'ZERO', // ⛔ TRAP
    'KILAT',
    'TANAH',
  ];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    _accelSub = accelerometerEvents.listen((e) {
      final magnitude =
          (e.x.abs() + e.y.abs() + e.z.abs()) / 3.0;
      _shakeSum += magnitude;
      _shakeCount++;
    });
  }

  @override
  void dispose() {
    _accelSub.cancel();
    super.dispose();
  }

  void _attemptUnlock() {
    if (!widget.controller.shouldRequireLock(widget.amount)) {
      widget.onSuccess();
      return;
    }

    if (widget.controller.isJammed) {
      widget.onJammed();
      return;
    }

    final elapsed = DateTime.now().difference(_startTime);
    final avgShake =
        _shakeCount == 0 ? 0 : _shakeSum / _shakeCount;

    // ZERO trap
    if (_wheelItems[_selectedIndex] == 'ZERO') {
      widget.controller.jam();
      widget.onJammed();
      return;
    }

    if (!widget.controller.validateSolveTime(elapsed) ||
        !widget.controller.validateShake(avgShake)) {
      widget.controller.jam();
      widget.onJammed();
      return;
    }

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A002B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CRYPTEX LOCK',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: ListWheelScrollView.useDelegate(
              itemExtent: 40,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) {
                _selectedIndex = i;
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _wheelItems.length,
                builder: (context, index) {
                  return Center(
                    child: Text(
                      _wheelItems[index],
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: _attemptUnlock,
            child: const Text('UNLOCK'),
          ),
        ],
      ),
    );
  }
}
