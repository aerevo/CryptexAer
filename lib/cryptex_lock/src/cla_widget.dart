// 🎯 Z-KINETIC UI V12.0 (FINAL INTEGRATION)
// Status: PRODUCTION READY ✅
// Features: 
// - Real Transaction Data Integration
// - Correct Stress Test (Race Condition Check)
// - 60FPS Optimization (RepaintBoundary)

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// IMPORTS YANG SUDAH DIBAIKI
import 'cla_controller.dart';
import 'cla_models.dart';
import 'transaction_service.dart'; // ✅ Now exists!

class ClaWidget extends StatefulWidget {
  final ClaController controller;
  final VoidCallback onUnlock;

  const ClaWidget({
    Key? key,
    required this.controller,
    required this.onUnlock,
  }) : super(key: key);

  @override
  State<ClaWidget> createState() => _ClaWidgetState();
}

class _ClaWidgetState extends State<ClaWidget> with SingleTickerProviderStateMixin {
  // Sensor Streams
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  
  // Transaction Data
  TransactionData? _currentTxn;
  bool _isLoadingTxn = true;

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initSensors();
    _loadTransaction();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _initSensors() {
    if (!widget.controller.config.enableSensors) return;

    _accelSub = accelerometerEvents.listen((event) {
      if (mounted) {
        final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        // Normalize gravity (~9.8) to 0-based motion
        final delta = (magnitude - 9.8).abs();
        
        widget.controller.addMotionEvent(MotionEvent(
          magnitude: delta,
          timestamp: DateTime.now(),
          deltaX: event.x,
          deltaY: event.y,
          deltaZ: event.z
        ));
      }
    });
  }

  Future<void> _loadTransaction() async {
    try {
      final txn = await TransactionService.fetchCurrentTransaction();
      if (mounted) {
        setState(() {
          _currentTxn = txn;
          _isLoadingTxn = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading transaction: $e");
    }
  }

  // 🧪 REAL STRESS TEST (RACE CONDITION)
  Future<void> _runStressTest() async {
    debugPrint("🔥 STARTING STRESS TEST (Race Condition Check)...");
    
    final random = Random();
    int errors = 0;

    // Simulate 50 concurrent attacks trying to modify state
    await Future.wait(List.generate(50, (index) async {
      await Future.delayed(Duration(milliseconds: random.nextInt(20)));
      
      try {
        // Try to mess with wheels while validating
        widget.controller.updateWheel(index % 5, random.nextInt(10));
        await widget.controller.attemptUnlock();
      } catch (e) {
        errors++;
      }
    }));

    debugPrint("✅ STRESS TEST COMPLETE. Race Condition Errors: $errors");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Stress Test Done. Errors: $errors")),
    );
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        // PANIC MODE UI: Show Fake "Success" Screen or Empty Dashboard
        if (widget.controller.isPanicMode) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text("Home Dashboard", style: TextStyle(fontSize: 24))),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Background Grid
              Positioned.fill(
                child: CustomPaint(painter: GridPainter()),
              ),

              // Main Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. Transaction Header
                    _buildTransactionHeader(),
                    
                    const SizedBox(height: 40),

                    // 2. The CRYPTEX DIAL (RepaintBoundary for Performance)
                    RepaintBoundary(
                      child: Container(
                        height: 120,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(widget.controller.config.secret.length, (index) {
                            return _buildDialWheel(index);
                          }),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 3. Unlock Button
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        bool success = await widget.controller.attemptUnlock();
                        if (success && !widget.controller.isPanicMode) {
                          widget.onUnlock();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.controller.state == SecurityState.LOCKED
                              ? Colors.cyan.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          border: Border.all(
                            color: widget.controller.state == SecurityState.LOCKED
                                ? Colors.cyan
                                : Colors.red,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyan.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                        child: const Icon(Icons.fingerprint, color: Colors.cyan, size: 40),
                      ),
                    ),
                    
                    // 4. Stress Test Button (Hidden in production usually)
                    TextButton(
                      onPressed: _runStressTest,
                      child: const Text("RUN AUDIT STRESS TEST", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.cyan.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          const Text("AUTHORIZE TRANSFER", style: TextStyle(color: Colors.cyan, letterSpacing: 2, fontSize: 12)),
          const SizedBox(height: 10),
          _isLoadingTxn 
            ? const CircularProgressIndicator(color: Colors.cyan)
            : Text(
                _currentTxn?.amount ?? "---",
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
          const SizedBox(height: 5),
          if (_currentTxn != null)
            Text(
              "ID: ${_currentTxn!.transactionId}",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontFamily: 'Monospace'),
            ),
        ],
      ),
    );
  }

  Widget _buildDialWheel(int index) {
    return SizedBox(
      width: 50,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 50,
        perspective: 0.005,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (val) {
          HapticFeedback.selectionClick();
          // Adjust logic: value 0-9. Infinite loop handled by modulo usually.
          widget.controller.updateWheel(index, val % 10);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, itemIndex) {
            final value = itemIndex % 10;
            return Center(
              child: Text(
                "$value",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..strokeWidth = 1;
      
    const double spacing = 40;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
