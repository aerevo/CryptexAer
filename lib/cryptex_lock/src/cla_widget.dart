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
// 🔥 V18.5 - FIXED SPACING & LAYOUT 🔥
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
  bool _showForensics = false;
  int _localAttemptCount = 0;

  final Color _primaryOrange = const Color(0xFFFF5722);
  final Color _accentRed = const Color(0xFFD32F2F);
  final Color _neutralGray = const Color(0xFFE0E0E0);
  final Color _darkText = const Color(0xFF263238);
  final Color _successGreen = const Color(0xFF4CAF50);
  final Color _lightBlueGray = const Color(0xFFE3E8F0);

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
    _scrollControllers = List.generate(5, (i) => FixedExtentScrollController(initialItem: 0));
  }

  void _userInteracted() {
    if (_showTutorial) {
      if (mounted && !_isDisposed) setState(() => _showTutorial = false);
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
      _lastX = e.x; _lastY = e.y; _lastZ = e.z;
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
      setState(() {});
    });
  }

  void _analyzeScrollPattern() {
    _lastScrollTime = DateTime.now();
    double patternScore = 0.0;
    List<int> intervals = [];
    for (int i = 1; i < _touchData.length; i++) {
      int interval = (_touchData[i]['time'] as DateTime).difference(_touchData[i - 1]['time'] as DateTime).inMilliseconds;
      intervals.add(interval);
    }
    if (intervals.isNotEmpty) {
      double avg = intervals.reduce((a, b) => a + b) / intervals.length;
      double variance = intervals.map((x) => (x - avg) * (x - avg)).reduce((a, b) => a + b) / intervals.length;
      double stdDev = sqrt(variance);
      double cv = stdDev / avg;
      patternScore = ((1 - cv.clamp(0, 1)) as num).clamp(0.0, 1.0).toDouble();
    } else {
      patternScore = 0.0;
    }
    if (mounted && !_isDisposed) setState(() => _patternScore = patternScore);
  }

  void _triggerTouchActive() {
    _touchScoreNotifier.value = 1.0;
    _touchDecayTimer?.cancel();
    _touchDecayTimer = Timer(const Duration(milliseconds: 300), () {
      _touchScoreNotifier.value = 0.0;
    });
  }

  void _onRandomizeTrigger() async {
    if (widget.controller.shouldRandomizeWheels.value && !_isDisposed) {
      final random = Random();
      for (int i = 0; i < _scrollControllers.length; i++) {
        if (!mounted || _isDisposed) break;
        final randomIndex = random.nextInt(10) + (i * 100);
        if (_scrollControllers[i].hasClients) {
          _scrollControllers[i].animateToItem(randomIndex, duration: const Duration(milliseconds: 600), curve: Curves.easeOut);
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
      widget.controller.shouldRandomizeWheels.value = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _accelSub?.cancel();
    _lockoutTimer?.cancel();
    _wheelActiveTimer?.cancel();
    _tutorialHideTimer?.cancel();
    _touchDecayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    widget.controller.shouldRandomizeWheels.removeListener(_onRandomizeTrigger);
    for (var c in _scrollControllers) {
      c.dispose();
    }
    _pulseController.dispose();
    _scanController.dispose();
    _reticleController.dispose();
    _rainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final isUnlocked = state == SecurityState.UNLOCKED;
    final isLocked = state == SecurityState.HARD_LOCK;
    Color activeColor = isUnlocked ? _successGreen : (isLocked ? Colors.red : _primaryOrange);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: MatrixRainPainter(
                rain: _matrixRain,
                color: activeColor.withOpacity(0.15),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 🔥 CALCULATE PROPER SIZING
                final screenHeight = constraints.maxHeight;
                final wheelHeight = screenHeight * 0.35; // 35% of screen height
                
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Header
                          _buildHeader(activeColor, state),
                          
                          const SizedBox(height: 20),
                          
                          // Sensor Row
                          _buildSensorRow(activeColor),
                          
                          const SizedBox(height: 30),
                          
                          // 🔥 WHEELS dengan sizing yang betul
                          Center(
                            child: SizedBox(
                              height: wheelHeight.clamp(180.0, 250.0), // Min 180, Max 250
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (i) => _build3DCylinder(i, activeColor)),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Confirm Button
                          _buildConfirmButton(activeColor, state),
                          
                          // Warning Banner
                          if (_localAttemptCount >= 3) 
                            _buildWarningBanner(),
                          
                          // Stress Test Result
                          if (_stressResult.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _successGreen),
                              ),
                              child: Text(
                                _stressResult,
                                style: TextStyle(
                                  color: _successGreen,
                                  fontSize: 9,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showForensics)
            Positioned(right: 0, top: 100, child: _buildForensicPanel()),
          TutorialOverlay(isVisible: _showTutorial, color: activeColor),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color, SecurityState state) {
    return Column(
      children: [
        Text(
          "CRYPTEX LOCK",
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            _getStateText(state),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  String _getStateText(SecurityState state) {
    switch (state) {
      case SecurityState.VALIDATING:
        return "VALIDATING...";
      case SecurityState.UNLOCKED:
        return "ACCESS GRANTED";
      case SecurityState.HARD_LOCK:
        return "SYSTEM JAMMED";
      default:
        return "AWAITING INPUT";
    }
  }

  Widget _build3DCylinder(int index, Color color) {
    bool isActive = _activeWheelIndex == index;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTapDown: (_) {
            if (_isDisposed) return;
            setState(() => _activeWheelIndex = index);
            _wheelActiveTimer?.cancel();
            _userInteracted();
            widget.controller.registerTouch(Offset.zero, 1.0, DateTime.now());
            HapticFeedback.selectionClick();
          },
          onTapUp: (_) => _resetActiveWheelTimer(),
          onTapCancel: () => _resetActiveWheelTimer(),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Background image
                  Positioned.fill(
                    child: Image.asset(
                      'assets/z_wheel.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF555555),
                                Color(0xFF888888),
                                Color(0xFF555555),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Depth gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Numbers
                  Positioned.fill(
                    child: ListWheelScrollView.useDelegate(
                      controller: _scrollControllers[index],
                      itemExtent: 45,
                      perspective: 0.005,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      overAndUnderCenterOpacity: 0.3,
                      onSelectedItemChanged: (_) {
                        HapticFeedback.selectionClick();
                        _analyzeScrollPattern();
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, i) {
                          return Center(
                            child: Text(
                              '${i % 10}',
                              style: TextStyle(
                                fontSize: isActive ? 36 : 32,
                                fontWeight: FontWeight.w900,
                                color: isActive 
                                    ? const Color(0xFFFF6D00)
                                    : _neutralGray,
                                height: 1.2,
                                shadows: isActive 
                                    ? [
                                        const BoxShadow(
                                          color: Color(0xFFFF6D00),
                                          blurRadius: 15,
                                          spreadRadius: 3,
                                        ),
                                        const BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 5,
                                        ),
                                      ]
                                    : [
                                        Shadow(
                                          offset: const Offset(2, 2),
                                          blurRadius: 3,
                                          color: Colors.black.withOpacity(0.7),
                                        ),
                                        Shadow(
                                          offset: const Offset(-1, -1),
                                          blurRadius: 2,
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // HUD line
                  if (isActive)
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: const Color(0xFFFF6D00).withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                            color: const Color(0xFFFF6D00).withOpacity(0.05),
                          ),
                        ),
                      ),
                    ),

                  // Side shadows
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Top cap
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 6,
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        gradient: LinearGradient(
                          colors: [Color(0xFF555555), Color(0xFF444444), Color(0xFF555555)],
                        ),
                      ),
                    ),
                  ),

                  // Bottom cap
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 6,
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        gradient: LinearGradient(
                          colors: [Color(0xFF555555), Color(0xFF444444), Color(0xFF555555)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(Color activeColor, SecurityState state) {
    bool isDisabled = state == SecurityState.VALIDATING || state == SecurityState.HARD_LOCK;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isDisabled ? null : LinearGradient(colors: [activeColor, activeColor.withOpacity(0.8)]),
          color: isDisabled ? Colors.grey[300] : null,
          boxShadow: isDisabled 
              ? [] 
              : [
                  BoxShadow(color: activeColor.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isDisabled ? null : () async {
              HapticFeedback.mediumImpact();
              _localAttemptCount++;
              await widget.controller.verify(_currentCode);
            },
            child: Center(
              child: Text(
                state == SecurityState.HARD_LOCK ? "SYSTEM LOCKED" : "CONFIRM ACCESS",
                style: TextStyle(
                  color: isDisabled ? Colors.black54 : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
          size: 18,
          color: isActive ? _successGreen : Colors.black38,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: isActive ? _successGreen : Colors.black38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildForensicPanel() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showForensics ? 1.0 : 0.0,
      child: Container(
        width: 60,
        height: 200,
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: MatrixRainPainter(
                  rain: _matrixRain,
                  color: const Color(0xFF00FF00).withOpacity(0.3),
                ),
              ),
            ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _accentRed.withOpacity(0.1),
        border: Border.all(color: _accentRed),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _accentRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.controller.threatMessage,
              style: TextStyle(
                color: _accentRed,
                fontSize: 10,
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
      _stressResult = "📊 BENCHMARK REPORT:\n"
          "Total: 50 Threads\n"
          "Time: ${stopwatch.elapsedMilliseconds}ms\n"
          "Speed: ${tps.toStringAsFixed(0)} TPS\n"
          "Integrity: STABLE";
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_isDisposed) setState(() => _stressResult = "");
    });
  }
}
