import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'cla_controller.dart';
import 'cla_config.dart';

class ClaWidget extends StatefulWidget {
  final ClaController controller;

  const ClaWidget({
    super.key,
    required this.controller,
  });

  @override
  State<ClaWidget> createState() => _ClaWidgetState();
}

class _ClaWidgetState extends State<ClaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  double _shakeSum = 0.0;
  int _shakeCount = 0;

  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_onShakeTick);
  }

  void _onShakeTick() {
    final double value =
        sin(_shakeController.value * pi * 6).abs();

    _shakeSum += value;
    _shakeCount++;

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 300), _evaluateShake);
  }

  void _evaluateShake() {
    if (!mounted) return;

    final double avgShake =
        _shakeCount == 0 ? 0.0 : (_shakeSum / _shakeCount).toDouble();

    _shakeSum = 0.0;
    _shakeCount = 0;

    if (!widget.controller.validateShake(avgShake)) {
      widget.controller.onInvalidShake();
    } else {
      widget.controller.onValidShake();
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (_) {
        if (!_shakeController.isAnimating) {
          _shakeController.forward(from: 0.0);
        }
      },
      child: const SizedBox.expand(),
    );
  }
}
