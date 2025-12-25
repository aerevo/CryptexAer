import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  bool _shakeDetected = true;
  bool _zeroTrap = false;

  @override
  void initState() {
    super.initState();
    widget.controller.start();
  }

  void _submit() {
    final result = widget.controller.validate(
      shakeDetected: _shakeDetected,
      zeroTrapHit: _zeroTrap,
    );

    switch (result) {
      case ClaResult.success:
        widget.onSuccess();
        break;
      case ClaResult.jammed:
        widget.onJammed();
        break;
      case ClaResult.fail:
      default:
        widget.onFail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade900, Colors.black],
        ),
        border: Border.all(color: Colors.amber, width: 3),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CRYPTEX LOCK',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoPicker(
            itemExtent: 36,
            onSelectedItemChanged: (i) {
              if (i == 0) _zeroTrap = true;
            },
            children: const [
              Text('KOSONG'),
              Text('API'),
              Text('AIR'),
              Text('KILAT'),
              Text('TANAH'),
              Text('BAYANG'),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('UNLOCK'),
          ),
        ],
      ),
    );
  }
}