import 'dart:math';
import 'package:flutter/cupertino.dart';
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

class _CryptexLockState extends State<CryptexLock>
    with SingleTickerProviderStateMixin {
  static const elements = ['KOSONG', 'API', 'AIR', 'KILAT', 'TANAH', 'BAYANG'];
  final List<int> _selected = [1, 1, 1, 1, 1];

  late final StreamSubscription _accelSub;
  late final AnimationController _jamAnim;

  @override
  void initState() {
    super.initState();
    widget.controller.start();

    // Accelerometer (sederhana)
    _accelSub = accelerometerEvents.listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      widget.controller.registerMotion(mag);
    });

    _jamAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _accelSub.cancel();
    _jamAnim.dispose();
    super.dispose();
  }

  Widget _wheel(int index) {
    return SizedBox(
      width: 60,
      height: 120,
      child: CupertinoPicker(
        itemExtent: 32,
        selectionOverlay: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.amber, width: 1),
              bottom: BorderSide(color: Colors.amber, width: 1),
            ),
          ),
        ),
        onSelectedItemChanged: (i) {
          _selected[index] = i;
        },
        children: elements
            .map(
              (e) => Center(
                child: Text(
                  e,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _submit() {
    final result = widget.controller.validate(_selected);

    switch (result) {
      case ClaResult.success:
        widget.onSuccess();
        break;

      case ClaResult.jammed:
        HapticFeedback.heavyImpact();
        _jamAnim.forward(from: 0);
        widget.onJammed();
        break;

      case ClaResult.fail:
      default:
        HapticFeedback.mediumImpact();
        widget.onFail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _jamAnim,
      builder: (context, child) {
        final shake = sin(_jamAnim.value * pi * 10) * 8;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1A72), Colors.black],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.amber, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CRYPTEX LOCK',
              style: TextStyle(
                color: Colors.amber,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, _wheel),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.controller.isJammed ? null : _submit,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text('UNLOCK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
