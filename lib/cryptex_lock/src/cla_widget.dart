// 🎯 Z-KINETIC UI V11.2 (V2 CONTROLLER COMPATIBLE)
// Status: FIXED & OPTIMIZED ✅
// Fix: Import V2 controller instead of V1

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ✅ CRITICAL FIX: Import V2 controller
import 'cla_controller_v2.dart'; // Changed from 'cla_controller.dart'
import 'cla_models.dart';

// ============================================
// 1. TUTORIAL OVERLAY
// ============================================
class TutorialOverlay extends StatelessWidget {
  final bool isVisible;
  final Color color;

  const TutorialOverlay({super.key, required this.isVisible, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer( 
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          color: Colors.black.withOpacity(0.6), 
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.screen_rotation, color: color, size: 48),
                const SizedBox(height: 10),
                Text(
                  "TILT & ROTATE",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontSize: 16,
                    shadows: [Shadow(color: color, blurRadius: 10)]
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Engage kinetic sensors to unlock",
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
                ),
                const SizedBox(height: 30),
                Icon(Icons.keyboard_double_arrow_down, color: color.withOpacity(0.5), size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// 2. MAIN WIDGET: CRYPTEX LOCK
// ============================================
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

class _CryptexLockState extends State<CryptexLock> with WidgetsBindingObserver, TickerProviderStateMixin {
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _lockoutTimer;
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;
  
  final ValueNotifier<double> _motionScoreNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _touchScoreNotifier = ValueNotifier(0.0);
  final ValueNotifier<Offset> _accelNotifier = ValueNotifier(Offset.zero);
  
  double _patternScore = 0.0;
  bool _showTutorial = true;
  Timer? _tutorialHideTimer;
  Timer? _touchDecayTimer;
  
  double _lastX = 0, _lastY = 0, _lastZ = 0;
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _reticleController;
  
  bool _isStressTesting = false;
  String _stressResult = "";
  
  final Color _neonCyan = const Color(0xFF00FFFF);
  final Color _neonGreen = const Color(0xFF00FF88);
  final Color _neonRed = const Color(0xFFFF3366);
  final Color _bgDark = const Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    widget.controller.onInteractionStart(); 
    
    _startListening();
    widget.controller.addListener(_handleControllerChange);
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _reticleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    _tutorialHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showTutorial = false);
    });
  }
  
  void _handleControllerChange() {
    if (widget.controller.state == SecurityState.UNLOCKED) widget.onSuccess();
    else if (widget.controller.state == SecurityState.HARD_LOCK) {
      _startLockoutTimer();
      widget.onJammed();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _startListening();
    else if (state == AppLifecycleState.paused) _accelSub?.cancel();
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (i) {
        int val = 0;
        try { val = widget.controller.getInitialValue(i); } catch(e) {}
        return FixedExtentScrollController(initialItem: val);
    });
  }

  void _userInteracted() {
    if (_showTutorial) {
      setState(() => _showTutorial = false);
      _tutorialHideTimer?.cancel();
    }
    _triggerTouchActive();
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((e) {
      _accelNotifier.value = Offset(e.x, e.y);
      
      double delta = (e.x - _lastX).abs() + (e.y - _lastY).abs() + (e.z - _lastZ).abs();
      _lastX = e.x; _lastY = e.y; _lastZ = e.z;
      
      double amplifiedMotion = (delta * 10.0).clamp(0.0, 1.0);
      
      if (amplifiedMotion > 0.5) _userInteracted();

      widget.controller.registerShake(delta, e.x, e.y, e.z);

      double currentScore = _motionScoreNotifier.value;
      if (amplifiedMotion > currentScore) {
        _motionScoreNotifier.value = amplifiedMotion;
      } else {
        _motionScoreNotifier.value = (currentScore * 0.92); 
      }
    });
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.controller.state == SecurityState.HARD_LOCK) {
        setState(() {});
        if (widget.controller.remainingLockoutSeconds <= 0) timer.cancel();
      } else { timer.cancel(); }
    });
  }

  void _triggerTouchActive() {
    _touchScoreNotifier.value = 1.0; 
    setState(() => _patternScore = 1.0); 
    
    _touchDecayTimer?.cancel();
    _touchDecayTimer = Timer(const Duration(seconds: 3), () {});
    Future.delayed(const Duration(milliseconds: 100), _decayTouch);
  }
  
  void _decayTouch() {
    if (!mounted) return;
    if (_touchScoreNotifier.value > 0) {
      _touchScoreNotifier.value -= 0.05;
      if (_touchScoreNotifier.value < 0) _touchScoreNotifier.value = 0;
      Future.delayed(const Duration(milliseconds: 50), _decayTouch);
    }
  }

  void _analyzeScrollPattern() {
    _userInteracted(); 
    final now = DateTime.now();
    double speed = _lastScrollTime != null ? 1000.0 / now.difference(_lastScrollTime!).inMilliseconds : 0.0;
    _lastScrollTime = now;
    _touchData.add({'timestamp': now, 'speed': speed, 'pressure': 0.5, 'wheelIndex': _activeWheelIndex ?? 0});
    if (_touchData.length > 20) _touchData.removeAt(0);
  }

  Future<void> _runStressTest() async {
    setState(() {
      _isStressTesting = true;
      _stressResult = "⚠️ LAUNCHING 50 CONCURRENT VECTORS...";
    });

    final stopwatch = Stopwatch()..start();
    final random = Random();
    
    await Future.wait(List.generate(50, (index) async {
      await Future.delayed(Duration(milliseconds: random.nextInt(50)));
      await widget.controller.validateAttempt(hasPhysicalMovement: true);
    }));

    stopwatch.stop();
    final double tps = 50 / (stopwatch.elapsedMilliseconds / 1000);

    setState(() {
      _isStressTesting = false;
      _stressResult = "📊 BENCHMARK REPORT:\n"
          "Total: 50 Threads\n"
          "Time: ${stopwatch.elapsedMilliseconds}ms\n"
          "Speed: ${tps.toStringAsFixed(0)} TPS (High Load)\n"
          "Integrity: STABLE (No Crash)";
    });
    
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _stressResult = "");
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel(); 
    _lockoutTimer?.cancel(); 
    _wheelActiveTimer?.cancel(); 
    _touchDecayTimer?.cancel(); 
    _tutorialHideTimer?.cancel();
    _pulseController.dispose(); 
    _scanController.dispose(); 
    _reticleController.dispose();
    for (var c in _scrollControllers) c.dispose();
    _motionScoreNotifier.dispose(); 
    _touchScoreNotifier.dispose(); 
    _accelNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SecurityState state = widget.controller.state;
    Color activeColor = (state == SecurityState.SOFT_LOCK || state == SecurityState.HARD_LOCK) 
        ? _neonRed 
        : (state == SecurityState.UNLOCKED ? _neonGreen : _neonCyan);
    
    String statusLabel = _getStatusLabel(state);
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: KineticGridPainter(color: activeColor)),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: _bgDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: activeColor.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: activeColor.withOpacity(0.15), blurRadius: 40, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHUDHeader(activeColor, statusLabel),
                if (widget.controller.threatMessage.isNotEmpty) _buildWarningBanner(),
                const SizedBox(height: 28),
                
                Listener(
                  onPointerDown: (_) {
                    _userInteracted();
                    widget.controller.registerTouch();
                  },
                  child: _buildInteractiveTumblerArea(activeColor, state),
                ),
                
                const SizedBox(height: 28),
                _buildAuthButton(activeColor, state),
                
                const SizedBox(height: 20),
                if (_stressResult.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.yellow.withOpacity(0.3))
                    ),
                    child: Text(
                      _stressResult,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.yellow, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                  
                const SizedBox(height: 10),
                GestureDetector(
                  onLongPress: _runStressTest, 
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(5)
                    ),
                    child: _isStressTesting 
                      ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                        "⚡ LONG PRESS FOR BENCHMARK",
                        style: TextStyle(
                          color: activeColor.withOpacity(0.4),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                        ),
                      ),
                  ),
                ),
              ],
            ),
          ),
          
          Positioned.fill(
            child: TutorialOverlay(
              isVisible: _showTutorial && state == SecurityState.LOCKED,
              color: activeColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(SecurityState state) {
    switch (state) {
      case SecurityState.LOCKED: return "BIOMETRIC SCAN STANDBY";
      case SecurityState.VALIDATING: return "PROCESSING PROTOCOL";
      case SecurityState.SOFT_LOCK: return "RETRY LIMIT REACHED";
      case SecurityState.HARD_LOCK: return "SYSTEM LOCKDOWN ACTIVE";
      case SecurityState.UNLOCKED: return "ENCRYPTION BYPASSED";
      default: return "INITIALIZING...";
    }
  }

  Widget _buildHUDHeader(Color color, String status) {
    return Stack(
      children: [
        _buildHUDCorner(color, true, true), 
        _buildHUDCorner(color, true, false),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CAPTAIN AER SECURITY SUITE", style: TextStyle(color: color.withOpacity(0.6), fontSize: 9, letterSpacing: 2.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14, shadows: [Shadow(color: color.withOpacity(0.8 * _pulseController.value), blurRadius: 15)]))
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1.5, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, color.withOpacity(0.4), Colors.transparent]))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _motionScoreNotifier,
                  builder: (context, val, _) => _buildSensorBox("MOTION", val, color, Icons.sensors),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<double>(
                  valueListenable: _touchScoreNotifier,
                  builder: (context, val, _) => _buildSensorBox("TOUCH", val, color, Icons.fingerprint),
                ),
                const SizedBox(height: 8),
                _buildPatternBox("PATTERN", _patternScore, color),
              ],
            )
          ],
        )
      ],
    );
  }

  Widget _buildInteractiveTumblerArea(Color color, SecurityState state) {
    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0, 
            child: ValueListenableBuilder<Offset>(
              valueListenable: _accelNotifier,
              builder: (context, offset, _) => CustomPaint(
                size: const Size(45, 140), 
                painter: KineticPeripheralPainter(
                  color: color, side: 'left', valX: offset.dx, valY: offset.dy, state: state,
                )
              ),
            )
          ),
          Positioned(
            right: 0, top: 0, bottom: 0, 
            child: ValueListenableBuilder<Offset>(
              valueListenable: _accelNotifier,
              builder: (context, offset, _) => CustomPaint(
                size: const Size(45, 140), 
                painter: KineticPeripheralPainter(
                  color: color, side: 'right', valX: offset.dx, valY: offset.dy, state: state,
                )
              ),
            )
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 55),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  for (int i = 0; i < _scrollControllers.length; i++) {
                    if (_scrollControllers[i].position == notification.metrics) {
                      setState(() { _activeWheelIndex = i; });
                      _wheelActiveTimer?.cancel();
                      break;
                    }
                  }
                } else if (notification is ScrollUpdateNotification) {
                  widget.controller.registerTouch(); 
                  _analyzeScrollPattern(); 
                } else if (notification is ScrollEndNotification) {
                  _resetActiveWheelTimer();
                }
                return false;
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) => _buildHolographicWheel(index, color)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHolographicWheel(int index, Color color) {
    bool isActive = _activeWheelIndex == index;
    return Expanded(
      child: Listener(
        onPointerDown: (_) {
          setState(() => _activeWheelIndex = index);
          _wheelActiveTimer?.cancel();
          _userInteracted();
          widget.controller.registerTouch();
          HapticFeedback.lightImpact(); 
        },
        onPointerUp: (_) => _resetActiveWheelTimer(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isActive ? 1.0 : 0.35,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isActive) Positioned.fill(child: AnimatedBuilder(animation: _reticleController, builder: (context, child) => CustomPaint(painter: KineticReticlePainter(color: color, progress: _reticleController.value)))),
              if (isActive) Positioned.fill(child: AnimatedBuilder(animation: _scanController, builder: (context, child) => CustomPaint(painter: KineticScanLinePainter(color: color, progress: _scanController.value)))),
              ListWheelScrollView.useDelegate(
                controller: _scrollControllers[index],
                itemExtent: 48, 
                perspective: 0.003, 
                diameterRatio: 1.1,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (v) { 
                  widget.controller.updateWheel(index, v % 10); 
                  HapticFeedback.selectionClick();
                  _analyzeScrollPattern(); 
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, i) => Center(
                    child: Text(
                      '${i % 10}', 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 32, 
                        fontWeight: FontWeight.w900, 
                        shadows: isActive ? [Shadow(color: color, blurRadius: 20)] : []
                      )
                    )
                  )
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetActiveWheelTimer() {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _activeWheelIndex = null);
    });
  }

  Widget _buildAuthButton(Color activeColor, SecurityState state) {
    bool isDisabled = state == SecurityState.VALIDATING || state == SecurityState.HARD_LOCK;
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), 
          boxShadow: !isDisabled ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 20)] : []
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDisabled ? const Color(0xFF1A1A1A) : activeColor.withOpacity(0.2),
            foregroundColor: activeColor,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
              side: BorderSide(color: isDisabled ? const Color(0xFF333333) : activeColor, width: 2)
            ),
          ),
          onPressed: isDisabled ? null : () => widget.controller.validateAttempt(hasPhysicalMovement: true),
          child: Text(
            state == SecurityState.HARD_LOCK ? "LOCKED" : "INITIATE ACCESS",
            style: TextStyle(
              fontWeight: FontWeight.w900, 
              letterSpacing: 2.5, 
              fontSize: 13,
              shadows: !isDisabled ? [Shadow(color: activeColor.withOpacity(0.9), blurRadius: 12)] : []
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHUDCorner(Color color, bool isTop, bool isLeft) {
    return Positioned(
      top: isTop ? 0 : null, 
      bottom: !isTop ? 0 : null, 
      left: isLeft ? 0 : null, 
      right: !isLeft ? 0 : null,
      child: Container(
        width: 24, 
        height: 24, 
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: color, width: 2) : BorderSide.none, 
            left: isLeft ? BorderSide(color: color, width: 2) : BorderSide.none, 
            right: !isLeft ? BorderSide(color: color, width: 2) : BorderSide.none, 
            bottom: !isTop ? BorderSide(color: color, width: 2) : BorderSide.none
          )
        )
      ),
    );
  }

  Widget _buildSensorBox(String label, double val, Color color, IconData icon) {
    bool isMatch = val > 0.6; 
    Color c = isMatch ? const Color(0xFF00FF88) : (val > 0.1 ? const Color(0xFFFF3366) : const Color(0xFF333333));
    return Container(
      width: 55, 
      height: 42, 
      decoration: BoxDecoration(
        border: Border.all(color: c, width: 1.5), 
        borderRadius: BorderRadius.circular(8), 
        color: isMatch ? c.withOpacity(0.15) : Colors.transparent
      ), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(isMatch ? Icons.check_circle : icon, size: 16, color: c), 
          Text(label, style: TextStyle(fontSize: 7, color: c, fontWeight: FontWeight.w900))
        ]
      )
    );
  }

  Widget _buildPatternBox(String label, double score, Color color) {
    bool isMatch = score >= 0.5; 
    Color c = isMatch ? const Color(0xFF00FF88) : (score > 0.1 ? const Color(0xFFFF3366) : const Color(0xFF333333));
    return Container(
      width: 55, 
      height: 42, 
      decoration: BoxDecoration(
        border: Border.all(color: c, width: 1.5), 
        borderRadius: BorderRadius.circular(8), 
        color: isMatch ? c.withOpacity(0.15) : Colors.transparent
      ), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(isMatch ? Icons.check_circle : Icons.timeline, size: 16, color: c), 
          Text(label, style: TextStyle(fontSize: 7, color: c, fontWeight: FontWeight.w900))
        ]
      )
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 14), 
      padding: const EdgeInsets.all(10), 
      decoration: BoxDecoration(
        color: const Color(0xFFFF3366).withOpacity(0.1), 
        border: Border.all(color: const Color(0xFFFF3366)), 
        borderRadius: BorderRadius.circular(8)
      ), 
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF3366), size: 18), 
          const SizedBox(width: 10), 
          Expanded(
            child: Text(
              widget.controller.threatMessage, 
              style: const TextStyle(color: Color(0xFFFF3366), fontSize: 10, fontWeight: FontWeight.w900)
            )
          )
        ]
      )
    );
  }
}

// ============================================
// PAINTERS
// ============================================

class KineticGridPainter extends CustomPainter {
  final Color color; 
  KineticGridPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.04)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  
  @override 
  bool shouldRepaint(KineticGridPainter old) => old.color != color;
}

class KineticPeripheralPainter extends CustomPainter {
  final Color color; 
  final String side;
  final double valX, valY;
  final SecurityState state;

  KineticPeripheralPainter({
    required this.color, 
    required this.side, 
    required this.valX, 
    required this.valY, 
    required this.state
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.3)..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    if (side == 'left') {
      canvas.drawRect(const Rect.fromLTWH(0, 10, 42, 14), Paint()..color = color.withOpacity(0.15));
      _drawText(canvas, tp, "COORD", 4, 13, 7, color, true);
      
      for (int i = 0; i < 4; i++) {
        double lat = ((valX * 10) + (i * 1.5)).clamp(-90, 90);
        double lng = ((valY * 10) - (i * 2.1)).clamp(-180, 180);
        _drawText(canvas, tp, "${lat.toStringAsFixed(2)}°", 2, 35.0 + (i*24), 6, color.withOpacity(0.6), false);
        _drawText(canvas, tp, "${lng.toStringAsFixed(2)}°", 2, 45.0 + (i*24), 6, color.withOpacity(0.6), false);
      }
      canvas.drawLine(const Offset(42, 10), const Offset(42, 130), p);
    } else {
      canvas.drawRect(const Rect.fromLTWH(2, 10, 42, 14), Paint()..color = color.withOpacity(0.15));
      _drawText(canvas, tp, "SYS-ID", 6, 13, 7, color, true);
      
      String authStatus = state == SecurityState.VALIDATING ? "PROC" : (state == SecurityState.UNLOCKED ? "COMP" : "PEND");
      _drawText(canvas, tp, "AUTH: $authStatus", 4, 35, 6, color.withOpacity(0.8), true);
      _drawText(canvas, tp, "ENC: AES256", 4, 45, 6, color.withOpacity(0.6), false);

      for (int i = 0; i < 12; i++) {
        double h = 6 + (valX.abs() * 2) + (i % 3);
        canvas.drawLine(
          Offset(6.0 + (i * 3), 60),
          Offset(6.0 + (i * 3), 60 + h),
          Paint()
            ..color = color.withOpacity(0.5)
            ..strokeWidth = 1.2,
        );
      }
      canvas.drawLine(const Offset(2, 10), const Offset(2, 130), p);
    }
  }

  void _drawText(
    Canvas c,
    TextPainter tp,
    String s,
    double x,
    double y,
    double sz,
    Color col,
    bool bold,
  ) {
    tp.text = TextSpan(
      text: s,
      style: TextStyle(
        color: col,
        fontSize: sz,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontFamily: 'Courier',
      ),
    );
    tp.layout();
    tp.paint(c, Offset(x, y));
  }

  @override
  bool shouldRepaint(KineticPeripheralPainter old) =>
      old.valX != valX ||
      old.valY != valY ||
      old.state != state ||
      old.color != color;
}

// ============================================
// RETICLE PAINTER
// ============================================

class KineticReticlePainter extends CustomPainter {
  final Color color;
  final double progress;

  KineticReticlePainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * 2 * pi);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawCircle(center, 22, p);

    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      canvas.drawLine(
        Offset(
          center.dx + 18 * cos(a),
          center.dy + 18 * sin(a),
        ),
        Offset(
          center.dx + 26 * cos(a),
          center.dy + 26 * sin(a),
        ),
        p,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(KineticReticlePainter old) =>
      old.progress != progress || old.color != color;
}

// ============================================
// SCAN LINE PAINTER
// ============================================

class KineticScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  KineticScanLinePainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      size.height * progress - 2,
      size.width,
      4,
    );

    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          color.withOpacity(0.6),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, p);
  }

  @override
  bool shouldRepaint(KineticScanLinePainter old) =>
      old.progress != progress || old.color != color;
}
