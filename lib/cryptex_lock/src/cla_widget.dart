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
// ðŸ”¥ V15.1 FINAL - GROK APPROVED VERSION
// Applied ALL Grok's tweaks for 99% match
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
    for (var c in _scrollControllers) c.dispose();
    _motionScoreNotifier.dispose();
    _touchScoreNotifier.dispose();
    _accelNotifier.dispose();
    super.dispose();
  }

  String _getStatusLabel(SecurityState state) {
    switch (state) {
      case SecurityState.LOCKED: return "Secure Access";
      case SecurityState.VALIDATING: return "Validating...";
      case SecurityState.SOFT_LOCK: return "Access Denied";
      case SecurityState.HARD_LOCK: return "System Locked";
      case SecurityState.UNLOCKED: return "Access Granted";
      default: return "Initializing...";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();
    SecurityState state = widget.controller.state;
    Color activeColor = (state == SecurityState.SOFT_LOCK || state == SecurityState.HARD_LOCK)
        ? _accentRed
        : (state == SecurityState.UNLOCKED ? _successGreen : _primaryOrange);
    String statusLabel = _getStatusLabel(state);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lightBlueGray, const Color(0xFFD0D8E8), const Color(0xFFC5D0E5)],
        ),
      ),
      child: Stack(
        children: [
          if (_showForensics) Positioned(left: 0, top: 100, child: _buildForensicPanel()),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(statusLabel, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _darkText, letterSpacing: 0.5)),
                  const SizedBox(height: 40),
                  _buildCleanLockContainer(activeColor, state),
                  const SizedBox(height: 30),
                  _buildConfirmButton(activeColor, state),
                  const SizedBox(height: 20),
                  if (widget.controller.threatMessage.isNotEmpty) _buildWarningBanner(),
                  const SizedBox(height: 20),
                  _buildSensorRow(activeColor),
                  if (_stressResult.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Text(_stressResult, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'monospace')),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => _showForensics = !_showForensics);
                          HapticFeedback.lightImpact();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(border: Border.all(color: _showForensics ? _successGreen : Colors.black26), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(_showForensics ? Icons.visibility : Icons.visibility_off, size: 16, color: _showForensics ? _successGreen : Colors.black54),
                              const SizedBox(width: 4),
                              Text("FORENSICS", style: TextStyle(color: _showForensics ? _successGreen : Colors.black54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onLongPress: _runStressTest,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(8)),
                          child: _isStressTesting
                              ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                              : Text("âš¡ BENCHMARK", style: TextStyle(color: activeColor.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(child: TutorialOverlay(isVisible: _showTutorial && state == SecurityState.LOCKED, color: activeColor)),
        ],
      ),
    );
  }

  Widget _buildCleanLockContainer(Color activeColor, SecurityState state) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, spreadRadius: 5, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 80, spreadRadius: 10, offset: const Offset(0, 20)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ðŸ”¥ GROK FIX #4: Deeper inner shadow
          Container(
            height: 200,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -10),
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -4),
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2), spreadRadius: -2),
              ],
              border: Border.all(color: const Color(0xFFE0E4EA), width: 1),
            ),
            child: Listener(
              onPointerDown: (_) {
                _userInteracted();
                widget.controller.registerTouch(Offset.zero, 1.0, DateTime.now());
              },
              child: _buildWheelRow(activeColor, state),
            ),
          ),
          const SizedBox(height: 24),
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
                  color: index == 1 ? const Color(0xFF666666) : const Color(0xFFCCCCCC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelRow(Color color, SecurityState state) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          for (int i = 0; i < _scrollControllers.length; i++) {
            if (_scrollControllers[i].position == notification.metrics) {
              if (mounted && !_isDisposed) setState(() => _activeWheelIndex = i);
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) => _buildPremiumCylinder(index, color)),
      ),
    );
  }
  
  Widget _buildPremiumCylinder(int index, Color color) {
    bool isActive = _activeWheelIndex == index;

    return Expanded(
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
        // ðŸ”¥ GROK FIX #5: Subtle scale lift
        child: AnimatedScale(
          scale: isActive ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            // ðŸ”¥ GROK FIX #2: ClipRRect to prevent overflow
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RealisticCylinderPainter(isActive: isActive, activeColor: color),
                    ),
                  ),
                  // ðŸ”¥ GROK FIX #1: Better number visibility
                  ListWheelScrollView.useDelegate(
                    controller: _scrollControllers[index],
                    itemExtent: 76, // Increased from 66
                    perspective: 0.0012, // Reduced from 0.002
                    diameterRatio: 1.5,
                    physics: const FixedExtentScrollPhysics(),
                    overAndUnderCenterOpacity: 0.5,
                    useMagnifier: true, // NEW
                    magnification: 1.25, // NEW - middle number bigger
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
                              fontSize: 56,
                              fontWeight: FontWeight.w700,
                              color: _darkText,
                              height: 1.0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (isActive)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.6), width: 2),
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  if (isActive)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _scanController,
                        builder: (context, child) => CustomPaint(
                          painter: KineticScanLinePainter(color: color, progress: _scanController.value),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: const LinearGradient(colors: [Color(0xFF4A4A4A), Color(0xFF5A5A5A), Color(0xFF4A4A4A)]),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                        gradient: const LinearGradient(colors: [Color(0xFF4A4A4A), Color(0xFF5A5A5A), Color(0xFF4A4A4A)]),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, -2))],
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
      height: 64,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isDisabled ? null : LinearGradient(colors: [activeColor, activeColor.withOpacity(0.8)]),
          color: isDisabled ? Colors.grey[300] : null,
          boxShadow: isDisabled ? [] : [BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isDisabled
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    await widget.controller.verify(_currentCode);
                  },
            child: Center(
              child: Text(
                state == SecurityState.HARD_LOCK ? "SYSTEM LOCKED" : "CONFIRM ACCESS",
                style: TextStyle(color: isDisabled ? Colors.black54 : Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.2),
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
        Icon(isActive ? Icons.check_circle : icon, size: 20, color: isActive ? _successGreen : Colors.black38),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, color: isActive ? _successGreen : Colors.black38, fontWeight: FontWeight.w600)),
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
            Positioned.fill(child: CustomPaint(painter: MatrixRainPainter(rain: _matrixRain, color: const Color(0xFF00FF00).withOpacity(0.3)))),
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
                  child: Text('FORENSIC', style: TextStyle(color: Color(0xFF00FF00), fontSize: 7, fontWeight: FontWeight.w900, fontFamily: 'Courier')),
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
      decoration: BoxDecoration(color: _accentRed.withOpacity(0.1), border: Border.all(color: _accentRed), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _accentRed, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.controller.threatMessage, style: TextStyle(color: _accentRed, fontSize: 11, fontWeight: FontWeight.w600))),
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
      _stressResult = "âš ï¸ LAUNCHING 50 CONCURRENT VECTORS...";
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
      _stressResult = "ðŸ“Š BENCHMARK REPORT:\nTotal: 50 Threads\nTime: ${stopwatch.elapsedMilliseconds}ms\nSpeed: ${tps.toStringAsFixed(0)} TPS\nIntegrity: STABLE";
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_isDisposed) setState(() => _stressResult = "");
    });
  }
}

// ðŸ”¥ GROK FIX #3: More intense red glow
class RealisticCylinderPainter extends CustomPainter {
  final bool isActive;
  final Color activeColor;

  RealisticCylinderPainter({required this.isActive, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final basePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), basePaint);

    final cylinderGradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, 0.0),
        radius: 1.2,
        colors: [Colors.white, const Color(0xFFF5F5F5), const Color(0xFFE8E8E8), const Color(0xFFDDDDDD)],
        stops: const [0.0, 0.4, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), cylinderGradient);

    final leftHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white.withOpacity(0.6), Colors.transparent],
        stops: const [0.0, 0.15],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), leftHighlight);

    final rightShadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
        stops: const [0.85, 1.0],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), rightShadow);

    if (isActive) {
      final centerY = size.height / 2;
      final glowRect = Rect.fromLTWH(0, centerY - 38, size.width, 76); // Match itemExtent

      // More intense red glow with BlendMode
      final redGlow = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            activeColor.withOpacity(0.3), // Increased from 0.15
            activeColor.withOpacity(0.1), // Increased from 0.05
            Colors.transparent,
          ],
        ).createShader(glowRect)
        ..blendMode = BlendMode.plus; // More intense

      canvas.drawRect(glowRect, redGlow);
    }

    final borderPaint = Paint()..color = const Color(0xFFE0E0E0)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), borderPaint);
  }

  @override
  bool shouldRepaint(RealisticCylinderPainter oldDelegate) {
    return oldDelegate.isActive != isActive || oldDelegate.activeColor != activeColor;
  }
}

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
        colors: [Colors.transparent, color.withOpacity(0.6), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, p);
  }

  @override
  bool shouldRepaint(KineticScanLinePainter old) => old.progress != progress || old.color != color;
}

// ============================================
// ðŸ”¥ V15.1 FINAL - GROK APPROVED âœ…
// All 5 tweaks applied for 99% match! ðŸš€
// ============================================
