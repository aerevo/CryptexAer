import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller_v2.dart';
import 'cla_models.dart';

// ============================================
// 🔥 Z-KINETIC CORE - INDUSTRIAL SECURITY UI
// FIXED: Full compatibility + Centered layout + Working wheels
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

class SuccessScreen extends StatelessWidget {
  final String message;

  const SuccessScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF607D8B),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 70,
                ),
              ),
              const SizedBox(height: 40),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'BERJAYA!',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.green[700],
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactFailDialog extends StatefulWidget {
  final String message;
  final Color accentColor;

  const CompactFailDialog({
    super.key,
    required this.message,
    required this.accentColor,
  });

  @override
  State<CompactFailDialog> createState() => _CompactFailDialogState();
}

class _CompactFailDialogState extends State<CompactFailDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
    
    _controller.repeat(reverse: true);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cancel,
                    color: widget.accentColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF263238),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥 MAIN WIDGET - INDUSTRIAL CENTERED CARD LAYOUT
class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;
  final VoidCallback? onJammed;

  const CryptexLock({
    super.key, 
    required this.controller,
    this.onSuccess,
    this.onFail,
    this.onJammed,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin {
  final List<FixedExtentScrollController> _scrollControllers = [];
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _showTutorial = true;
  bool _isDisposed = false;

  late AnimationController _scanController;
  late AnimationController _glowPulseController;
  
  Timer? _interactionTimeout;
  final ValueNotifier<double> _motionScoreNotifier = ValueNotifier(0.0);
  double _patternScore = 0.0;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  final List<Offset> _interactionBuffer = [];

  static const Color _accentOrange = Color(0xFFFF6F00);
  static const Color _accentRed = Color(0xFFD32F2F);
  static const Color _successGreen = Color(0xFF4CAF50);

  static const double _imageWidth = 1080.0;
  static const double _imageHeight = 610.0;

  final List<List<double>> _wheelCoords = [
    [32, 111, 174, 483],
    [242, 111, 384, 483],
    [452, 111, 594, 483],
    [662, 111, 804, 483],
    [872, 111, 1014, 483],
  ];

  final List<double> _phantomButtonCoords = [478, 520, 570, 570];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initSensors();
    
    widget.controller.addListener(_controllerListener);
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showTutorial = false);
    });
  }

  void _initControllers() {
    for (int i = 0; i < 5; i++) {
      _scrollControllers.add(FixedExtentScrollController());
    }
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _initSensors() {
    _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.normalInterval).listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > 1.5) {
        double score = (magnitude / 10.0).clamp(0.0, 1.0);
        _motionScoreNotifier.value = (_motionScoreNotifier.value * 0.85 + score * 0.15).clamp(0.0, 1.0);
        widget.controller.updateMotion(score);
      }
    });
    
    _accelSub = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > 10.0) {
        double score = ((magnitude - 9.8).abs() / 5.0).clamp(0.0, 1.0);
        widget.controller.updateMotion(score);
      }
    });
  }

  void _controllerListener() {
    if (!mounted) return;
    if (widget.controller.state == SecurityState.UNLOCKED) {
      _onSuccess();
    } else if (widget.controller.state == SecurityState.HARD_LOCK) {
      _onJammed();
    } else if (widget.controller.state == SecurityState.ATTEMPT_FAILED) {
      _onFail();
    }
  }

  void _onSuccess() {
    HapticFeedback.heavyImpact();
    widget.onSuccess?.call();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SuccessScreen(message: "Kinetic lock disengaged")),
    );
  }

  void _onFail() {
    HapticFeedback.vibrate();
    widget.onFail?.call();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CompactFailDialog(
        message: "CODE INVALID",
        accentColor: _accentRed,
      ),
    );
  }

  void _onJammed() {
    HapticFeedback.heavyImpact();
    widget.onJammed?.call();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CompactFailDialog(
        message: "SYSTEM JAMMED",
        accentColor: _accentRed,
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _wheelActiveTimer?.cancel();
    _interactionTimeout?.cancel();
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _scanController.dispose();
    _glowPulseController.dispose();
    _motionScoreNotifier.dispose();
    for (var c in _scrollControllers) {
      c.dispose();
    }
    widget.controller.removeListener(_controllerListener);
    super.dispose();
  }

  void _userInteracted(Offset position) {
    _interactionBuffer.add(position);
    if (_interactionBuffer.length > 10) _interactionBuffer.removeAt(0);
    
    _interactionTimeout?.cancel();
    _interactionTimeout = Timer(const Duration(milliseconds: 800), () {
      double score = widget.controller.touchScore.value;
      widget.controller.updateTouch(score);
    });
    
    _analyzeScrollPattern();
  }

  void _analyzeScrollPattern() {
    if (_interactionBuffer.length < 3) return;
    
    double totalDistance = 0.0;
    for (int i = 1; i < _interactionBuffer.length; i++) {
      totalDistance += (_interactionBuffer[i] - _interactionBuffer[i - 1]).distance;
    }
    
    double normalizedPattern = (totalDistance / 500.0).clamp(0.0, 1.0);
    setState(() => _patternScore = normalizedPattern);
    widget.controller.updatePattern(normalizedPattern);
  }

  List<int> _getCurrentCode() {
    return List.generate(
      5,
      (i) => _scrollControllers[i].selectedItem % 10,
    );
  }

  void _handlePhantomButtonTap() {
    HapticFeedback.mediumImpact();
    _userInteracted(const Offset(300, 350));
    List<int> code = _getCurrentCode();
    widget.controller.verify(code);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        Color activeColor = state == SecurityState.HARD_LOCK ? _accentRed : _accentOrange;

        return Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.96,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.security,
                            color: const Color(0xFFFF6F00),
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Z-KINETIC",
                            style: TextStyle(
                              color: Color(0xFFFF6F00),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),
                      _buildWheelSystem(activeColor, state),
                      const SizedBox(height: 20),
                      _buildSensorRow(activeColor),
                      if (state == SecurityState.HARD_LOCK) ...[
                        const SizedBox(height: 12),
                        _buildWarningBanner(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: TutorialOverlay(
                isVisible: _showTutorial && state == SecurityState.LOCKED,
                color: activeColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWheelSystem(Color activeColor, SecurityState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double aspectRatio = _imageWidth / _imageHeight;
        double calculatedHeight = availableWidth / aspectRatio;

        return SizedBox(
          width: availableWidth,
          height: calculatedHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/z_wheel.png',
                  fit: BoxFit.contain,
                ),
              ),
              ..._buildWheelOverlays(availableWidth, calculatedHeight, activeColor, state),
              _buildPhantomButton(availableWidth, calculatedHeight),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhantomButton(double screenWidth, double screenHeight) {
    double left = _phantomButtonCoords[0];
    double top = _phantomButtonCoords[1];
    double right = _phantomButtonCoords[2];
    double bottom = _phantomButtonCoords[3];

    double actualLeft = screenWidth * (left / _imageWidth);
    double actualTop = screenHeight * (top / _imageHeight);
    double actualWidth = screenWidth * ((right - left) / _imageWidth);
    double actualHeight = screenHeight * ((bottom - top) / _imageHeight);

    return Positioned(
      left: actualLeft,
      top: actualTop,
      width: actualWidth,
      height: actualHeight,
      child: GestureDetector(
        onTap: _handlePhantomButtonTap,
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  List<Widget> _buildWheelOverlays(double screenWidth, double screenHeight, Color activeColor, SecurityState state) {
    List<Widget> wheels = [];
    
    for (int i = 0; i < 5; i++) {
      double left = _wheelCoords[i][0];
      double top = _wheelCoords[i][1];
      double right = _wheelCoords[i][2];
      double bottom = _wheelCoords[i][3];
      
      double actualLeft = screenWidth * (left / _imageWidth);
      double actualTop = screenHeight * (top / _imageHeight);
      double actualWidth = screenWidth * ((right - left) / _imageWidth);
      double actualHeight = screenWidth * ((bottom - top) / _imageHeight);
      
      wheels.add(
        Positioned(
          left: actualLeft,
          top: actualTop,
          width: actualWidth,
          height: actualHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                if (_scrollControllers[i].position == notification.metrics) {
                  if (mounted && !_isDisposed) setState(() => _activeWheelIndex = i);
                  _wheelActiveTimer?.cancel();
                }
              } else if (notification is ScrollUpdateNotification) {
                _analyzeScrollPattern();
              } else if (notification is ScrollEndNotification) {
                _resetActiveWheelTimer();
              }
              return false;
            },
            child: _buildAdvancedWheel(i, actualHeight, activeColor),
          ),
        ),
      );
    }
    
    return wheels;
  }

  Widget _buildAdvancedWheel(int index, double wheelHeight, Color activeColor) {
    bool isActive = _activeWheelIndex == index;
    double itemExtent = wheelHeight * 0.40;
    
    return GestureDetector(
      onTapDown: (details) {
        if (_isDisposed) return;
        setState(() => _activeWheelIndex = index);
        _wheelActiveTimer?.cancel();
        _userInteracted(details.localPosition);
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) => _resetActiveWheelTimer(),
      onTapCancel: () => _resetActiveWheelTimer(),
      child: AnimatedScale(
        scale: isActive ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            ListWheelScrollView.useDelegate(
              controller: _scrollControllers[index],
              itemExtent: itemExtent,
              perspective: 0.003,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
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
                        fontSize: wheelHeight * 0.30,
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
            if (isActive)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activeColor.withOpacity(0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            if (isActive)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) => CustomPaint(
                    painter: KineticScanLinePainter(
                      color: activeColor,
                      progress: _scanController.value,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _motionScoreNotifier,
            builder: (context, val, _) => _buildMiniSensor("MOTION", val, color, Icons.sensors),
          ),
          ValueListenableBuilder<double>(
            valueListenable: widget.controller.touchScore,
            builder: (context, val, _) => _buildMiniSensor("TOUCH", val, color, Icons.fingerprint),
          ),
          _buildMiniSensor("PATTERN", _patternScore, color, Icons.timeline),
        ],
      ),
    );
  }

  Widget _buildMiniSensor(String label, double val, Color color, IconData icon) {
    bool isActive = val > 0.3;
    return Column(
      children: [
        Icon(
          isActive ? Icons.check_circle : icon,
          size: 20,
          color: isActive ? _successGreen : Colors.grey[400],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? _successGreen : Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
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
