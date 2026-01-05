import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_wheel.dart';

class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback onSuccess;
  final VoidCallback onFail;
  final VoidCallback onJammed;

  // NOTA: Tiada lagi parameter 'amount' di sini. Ia dalam Config.
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
  final List<int> _input = List.filled(5, 0);
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _lastX = 0, _lastY = 0, _lastZ = 0;

  @override
  void initState() {
    super.initState();
    _startSensors();
  }

  void _startSensors() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      double delta = (e.x - _lastX).abs() + (e.y - _lastY).abs() + (e.z - _lastZ).abs();
      _lastX = e.x; _lastY = e.y; _lastZ = e.z;
      widget.controller.registerShake(delta);
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _tryUnlock() {
    final ok = widget.controller.attempt(_input);
    
    if (ok) {
      widget.onSuccess();
    } else if (widget.controller.state.jammed) {
      widget.onJammed();
    } else {
      widget.onFail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return ClaWheel(
                items: const ['0','1','2','3','4','5','6','7','8','9'],
                onChanged: (v) => _input[i] = v,
              );
            }),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _tryUnlock,
              child: const Text("AUTHENTICATE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }
}
