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
// 🔥 V22.0 - FIXED LAYOUT COMPLETELY 🔥
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
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildHeader(activeColor, state),
            ),
            
            // Sensor Row
            _buildSensorRow(activeColor),
            
            const SizedBox(height: 20),
            
            // Wheels - FIXED SIZE
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primaryOrange, width: 2),
              ),
              child: Stack(
                children: [
                  // Background image
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/z_wheel.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.red.withOpacity(0.3),
                            child: const Center(
                              child: Icon(Icons.error, color: Colors.red, size: 40),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // Numbers overlay
                  Row(
                    children: List.generate(5, (i) => _buildNumberOverlay(i, activeColor)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildConfirmButton(activeColor, state),
            ),
            
            // Warning
            if (_localAttemptCount >= 3)
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildWarningBanner(),
              ),
              
            const Spacer(),
          ],
        ),
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

  Widget _buildNumberOverlay(int index, Color color) {
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
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: ListWheelScrollView.useDelegate(
            controller: _scrollControllers[index],
            itemExtent: 50,
            perspective: 0.005,
            diameterRatio: 1.2,
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
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      shadows: [
                        Shadow(
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.8),
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
          size: 20,
          color: isActive ? _successGreen : Colors.white38,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? _successGreen : Colors.white38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildForensicPanel() {
    return Container(
      width: 60,
      height: 200,
      color: Colors.black,
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
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
    // Simplified for now
  }
}
