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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'CRYPTEX LOCK',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _attemptUnlock,
          child: const Text('UNLOCK'),
        ),
      ],
    );
  }
}
