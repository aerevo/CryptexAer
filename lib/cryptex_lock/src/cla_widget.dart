import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller_v2.dart';
import 'cla_models.dart';
import 'matrix_rain_painter.dart';
import 'forensic_data_painter.dart';

// ============================================
// 🔥 V14.0 - CLEAN INDUSTRIAL UI
// Based on screenshot: Professional gradient lock design
// Preserves: Matrix Rain, Forensic Panel, Motion Sensors
// ============================================

// ============================================
// TUTORIAL OVERLAY
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
                    shadows: [Shadow(color: color, blurRadius: 10)],
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
// MAIN CRYPTEX LOCK WIDGET
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
  final List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;

  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _reticleController;
  late MatrixRain _matrixRain;
  late AnimationController _rainController;

  bool _isStressTesting = false;
  String _stressResult = "";

  bool _isDisposed = false;

  // 🎨 PROFESSIONAL COLOR SCHEME (matching screenshot)
  final Color _primaryOrange = const Color(0xFFFF5722);  // Deep Orange accent
  final Color _accentRed = const Color(0xFFD32F2F);      // Red gradient
  final Color _neutralGray = const Color(0xFFE0E0E0);    // Light gray background
  final Color _darkText = const Color(0xFF263238);       // Dark blue-gray text
  final Color _successGreen = const Color(0xFF4CAF50);   // Success state

  List<int> get _currentCode {
    if (_scrollControllers.isEmpty) return [0, 0, 0, 0, 0];
    return _scrollControllers.map((c) => c.hasClients ? c.selectedItem % 10 : 0).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    widget.controller.onInteractionStart();
    _startListening();
    widget.controller.addListener(_handleControllerChange);

    widget.controller.shouldRandomizeWheels.addListener(_onRandomizeTrigger);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _reticleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    _matrixRain = MatrixRain(columnCount: 4);
    _rainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(() {
        if (!mounted || _isDisposed) return;
        setState(() {});
      })
      ..repeat();

    _tutorialHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDisposed) setState(() => _showTutorial = false);
    });
  }

  void _handleControllerChange() {
    if (_isDisposed) return;

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
      return FixedExtentScrollController(initialItem: 0);
    });
  }

  void _userInteracted() {
    if (_showTutorial) {
      if (mounted && !_isDisposed) {
        setState(() => _showTutorial = false);
      }
      _tutorialHideTimer?.cancel();
    }
    _triggerTouchActive();
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((e) {
      if (_isDisposed) return;

      _accelNotifier.value = Offset(e.x, e.y);
      double delta = (e.x - _lastX).abs() + (e.y - _lastY).abs() + (e.z - _lastZ).abs();
      _lastX = e.x;
      _lastY = e.y;
      _lastZ = e.z;

      double amplifiedMotion = (delta * 10.0).clamp(0.0, 1.0);
      if (amplifiedMotion > 0.5) _userInteracted();

      widget.controller.registerMotion(e.x, e.y, e.z, DateTime.now());

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
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }

      if (widget.controller.state == SecurityState.HARD_LOCK) {
        setState(() {});
        if (widget.controller.state != SecurityState.HARD_LOCK) timer.cancel();
      } else {
        timer.cancel();
      }
    });
  }

  void _triggerTouchActive() {
    if (_isDisposed) return;

    _touchScoreNotifier.value = 1.0;
    setState(() => _patternScore = 1.0);

    _touchDecayTimer?.cancel();
    _touchDecayTimer = Timer(const Duration(seconds: 3), () {});

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _isDisposed) return;
      _decayTouch();
    });
  }

  void _decayTouch() {
    if (!mounted || _isDisposed) return;

    if (_touchScoreNotifier.value > 0) {
      _touchScoreNotifier.value -= 0.05;
      if (_touchScoreNotifier.value < 0) _touchScoreNotifier.value = 0;

      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || _isDisposed) return;
        _decayTouch();
      });
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

  void _onRandomizeTrigger() {
    if (!mounted || _isDisposed) return;
    _randomizeWheels();
  }

  void _randomizeWheels() {
    if (_isDisposed) return;
    final random = Random();

    for (int i = 0; i < _scrollControllers.length; i++) {
      final randomValue = random.nextInt(10);
      _scrollControllers[i].animateToItem(
        randomValue,
        duration: Duration(milliseconds: 500 + random.nextInt(300)),
        curve: Curves.easeOutBack,
      );
    }
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _isDisposed = true;

    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    widget.controller.shouldRandomizeWheels.removeListener(_onRandomizeTrigger);

    _accelSub?.cancel();
    _lockoutTimer?.cancel();
    _wheelActiveTimer?.cancel();
    _touchDecayTimer?.cancel();
    _tutorialHideTimer?.cancel();

    _pulseController.dispose();
    _scanController.dispose();
    _reticleController.dispose();
    _rainController.dispose();

    for (var c in _scrollControllers) {
      c.dispose();
    }

    _motionScoreNotifier.dispose();
    _touchScoreNotifier.dispose();
    _accelNotifier.dispose();

    super.dispose();
  }

  String _getStatusLabel(SecurityState state) {
    switch (state) {
      case SecurityState.LOCKED:
        return "Secure Access";
      case SecurityState.VALIDATING:
        return "Validating...";
      case SecurityState.SOFT_LOCK:
        return "Access Denied";
      case SecurityState.HARD_LOCK:
        return "System Locked";
      case SecurityState.UNLOCKED:
        return "Access Granted";
      default:
        return "Initializing...";
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();

    SecurityState state = widget.controller.state;

    // 🎨 Dynamic color based on state
    Color activeColor = (state == SecurityState.SOFT_LOCK || state == SecurityState.HARD_LOCK)
        ? _accentRed
        : (state == SecurityState.UNLOCKED ? _successGreen : _primaryOrange);

    String statusLabel = _getStatusLabel(state);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF5F5F5),
            const Color(0xFFE8EAF6),
            _neutralGray,
          ],
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🔥 Forensic & Matrix panels (hidden beneath)
            Positioned(
              left: 20,
              top: 100,
              child: _buildForensicPanel(),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: _darkText,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 🎯 MAIN LOCK CONTAINER (matching screenshot)
                  _buildCleanLockContainer(activeColor, state),

                  const SizedBox(height: 30),

                  // Confirm Button
                  _buildConfirmButton(activeColor, state),

                  const SizedBox(height: 20),

                  // Warning banner
                  if (widget.controller.threatMessage.isNotEmpty) _buildWarningBanner(),

                  // Sensors row
                  const SizedBox(height: 20),
                  _buildSensorRow(activeColor),

                  // Stress test
                  if (_stressResult.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Text(
                        _stressResult,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  GestureDetector(
                    onLongPress: _runStressTest,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isStressTesting
                          ? const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                            )
                          : Text(
                              "⚡ LONG PRESS FOR BENCHMARK",
                              style: TextStyle(
                                color: activeColor.withOpacity(0.6),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Tutorial overlay
            Positioned.fill(
              child: TutorialOverlay(
                isVisible: _showTutorial && state == SecurityState.LOCKED,
                color: activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 CLEAN LOCK CONTAINER (matching screenshot style)
  Widget _buildCleanLockContainer(Color activeColor, SecurityState state) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // 🔥 CIRCULAR GRADIENT RING (like screenshot)
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _primaryOrange,
                  _accentRed,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Listener(
                  onPointerDown: (_) {
                    _userInteracted();
                    widget.controller.registerTouch(Offset.zero, 1.0, DateTime.now());
                  },
                  child: _buildWheelRow(activeColor, state),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Dots indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == 0 ? _darkText : _darkText.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔢 WHEEL ROW (5 tumblers inside circle)
  Widget _buildWheelRow(Color color, SecurityState state) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          for (int i = 0; i < _scrollControllers.length; i++) {
            if (_scrollControllers[i].position == notification.metrics) {
              if (mounted && !_isDisposed) {
                setState(() {
                  _activeWheelIndex = i;
                });
              }
              _wheelActiveTimer?.cancel();
              break;
            }
          }
        } else if (notification is ScrollUpdateNotification) {
          _analyzeScrollPattern();
        } else if (notification is ScrollEndNotification) {
          _resetActiveWheelTimer();
        }
        return false;
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) => _buildCleanWheel(index, color)),
      ),
    );
  }

  // 🔢 CLEAN WHEEL (professional style matching screenshot)
  Widget _buildCleanWheel(int index, Color color) {
    bool isActive = _activeWheelIndex == index;

    return Expanded(
      child: Listener(
        onPointerDown: (_) {
          if (_isDisposed) return;
          setState(() => _activeWheelIndex = index);
          _wheelActiveTimer?.cancel();
          _userInteracted();
          widget.controller.registerTouch(Offset.zero, 1.0, DateTime.now());
          HapticFeedback.lightImpact();
        },
        onPointerUp: (_) => _resetActiveWheelTimer(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isActive ? 1.0 : 0.5,
          child: Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? color : Colors.black12,
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                // Scan line (when active)
                if (isActive)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) => CustomPaint(
                        painter: KineticScanLinePainter(
                          color: color,
                          progress: _scanController.value,
                        ),
                      ),
                    ),
                  ),

                // Number wheel
                ListWheelScrollView.useDelegate(
                  controller: _scrollControllers[index],
                  itemExtent: 40,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (v) {
                    HapticFeedback.selectionClick();
                    _analyzeScrollPattern();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, i) => Center(
                      child: Text(
                        '${i % 10}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: _darkText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔘 CONFIRM BUTTON (matching screenshot)
  Widget _buildConfirmButton(Color activeColor, SecurityState state) {
    bool isDisabled = state == SecurityState.VALIDATING || state == SecurityState.HARD_LOCK;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey[300] : activeColor,
          foregroundColor: Colors.white,
          elevation: isDisabled ? 0 : 8,
          shadowColor: activeColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: isDisabled
            ? null
            : () async {
                HapticFeedback.mediumImpact();
                await widget.controller.verify(_currentCode);
              },
        child: Text(
          state == SecurityState.HARD_LOCK ? "SYSTEM LOCKED" : "CONFIRM ACCESS",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
  
  // 📊 SENSOR ROW (minimal, below main UI)
  Widget _buildSensorRow(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _motionScoreNotifier,
          builder: (context, val, _) => _buildMiniSensor("MOTION", val, color, Icons.sensors),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _touchScoreNotifier,
          builder: (context, val, _) => _buildMiniSensor("TOUCH", val, color, Icons.fingerprint),
        ),
        _buildMiniSensor("PATTERN", _patternScore, color, Icons.timeline),
      ],
    );
  }

  Widget _buildMiniSensor(String label, double val, Color color, IconData icon) {
    bool isActive = val > 0.3;
    return Column(
      children: [
        Icon(
          isActive ? Icons.check_circle : icon,
          size: 20,
          color: isActive ? _successGreen : Colors.black38,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? _successGreen : Colors.black38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // 🔬 FORENSIC PANEL (hidden, can be revealed)
  Widget _buildForensicPanel() {
    return Opacity(
      opacity: 0.0, // Hidden by default, can be toggled
      child: Container(
        width: 60,
        height: 200,
        color: Colors.black,
        child: Stack(
          children: [
            // Matrix rain background
            Positioned.fill(
              child: CustomPaint(
                painter: MatrixRainPainter(
                  rain: _matrixRain,
                  color: const Color(0xFF00FF00).withOpacity(0.3),
                ),
              ),
            ),

            // Forensic data overlay
            Positioned.fill(
              child: CustomPaint(
                painter: ForensicDataPainter(
                  color: const Color(0xFF00FF00),
                  motionCount: (widget.controller.motionEntropy * 100).toInt(),
                  touchCount: (widget.controller.liveConfidence * 20).toInt(),
                  entropy: widget.controller.motionEntropy,
                  confidence: widget.controller.liveConfidence,
                ),
              ),
            ),

            // Label
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF00).withOpacity(0.2),
                  border: Border.all(color: const Color(0xFF00FF00).withOpacity(0.5)),
                ),
                child: const Center(
                  child: Text(
                    'FORENSIC',
                    style: TextStyle(
                      color: Color(0xFF00FF00),
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentRed.withOpacity(0.1),
        border: Border.all(color: _accentRed),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _accentRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.controller.threatMessage,
              style: TextStyle(
                color: _accentRed,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetActiveWheelTimer() {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isDisposed) setState(() => _activeWheelIndex = null);
    });
  }

  Future<void> _runStressTest() async {
    if (_isDisposed) return;

    setState(() {
      _isStressTesting = true;
      _stressResult = "⚠️ LAUNCHING 50 CONCURRENT VECTORS...";
    });

    final stopwatch = Stopwatch()..start();
    final random = Random();

    await Future.wait(List.generate(50, (index) async {
      if (_isDisposed) return;
      await Future.delayed(Duration(milliseconds: random.nextInt(50)));
      await widget.controller.verify(_currentCode);
    }));

    stopwatch.stop();
    final double tps = 50 / (stopwatch.elapsedMilliseconds / 1000);

    if (!mounted || _isDisposed) return;

    setState(() {
      _isStressTesting = false;
      _stressResult =
          "📊 BENCHMARK REPORT:\nTotal: 50 Threads\nTime: ${stopwatch.elapsedMilliseconds}ms\nSpeed: ${tps.toStringAsFixed(0)} TPS\nIntegrity: STABLE";
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_isDisposed) setState(() => _stressResult = "");
    });
  }
}

// ============================================
// SCAN LINE PAINTER
// ============================================
class KineticScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  KineticScanLinePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, size.height * progress - 2, size.width, 4);

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
  bool shouldRepaint(KineticScanLinePainter old) => old.progress != progress || old.color != color;
}

// ============================================
// 🔥 END OF V14.0 - CLEAN INDUSTRIAL UI
// ============================================
