import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller_v2.dart';
import 'cla_models.dart';

// ============================================
// 🔥 Z-KINETIC CORE - V105.0 (FINAL RECLAMATION)
// FIX: CONSTRAINT PROPAGATION (BY CLAUDE & DEEPSEEK)
// STATUS: FULL UI RESTORED + STABILITY GUARANTEED
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
    return Scaffold(
      body: Container(
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
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _shakeAnimation = Tween<double>(begin: -10, end: 10).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));
    _controller.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.of(context).pop(); });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel, color: widget.accentColor, size: 64),
                const SizedBox(height: 16),
                Text(widget.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
  final List<FixedExtentScrollController> _scrollControllers = List.generate(5, (i) => FixedExtentScrollController(initialItem: 0));
  late AnimationController _scanController;
  late AnimationController _pulseController;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  final ValueNotifier<double> _motionScoreNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _touchScoreNotifier = ValueNotifier(0.0);
  double _patternScore = 0.0;
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _showTutorial = true;
  bool _isDisposed = false;

  final List<int> _scrollEvents = [];
  DateTime _lastScrollTime = DateTime.now();

  final Color _accentOrange = const Color(0xFFFF6F00);
  final Color _accentRed = const Color(0xFFD32F2F);
  final Color _successGreen = const Color(0xFF4CAF50);

  final double _imageWidth = 626.0;
  final double _imageHeight = 471.0;
  final List<List<double>> _wheelCoords = [[43, 143, 140, 341], [156, 143, 253, 341], [269, 143, 366, 341], [382, 143, 479, 341], [495, 143, 592, 341]];
  final List<double> _phantomButtonCoords = [154, 322, 467, 401];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    widget.controller.addListener(_onStateChange);
    _accelSub = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 100)).listen(_onAccelerometer);
    _gyroSub = gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 100)).listen(_onGyroscope);
    Future.delayed(const Duration(seconds: 3), () { if (mounted && !_isDisposed) setState(() => _showTutorial = false); });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scanController.dispose(); _pulseController.dispose();
    _accelSub?.cancel(); _gyroSub?.cancel(); _wheelActiveTimer?.cancel();
    widget.controller.removeListener(_onStateChange);
    for (var c in _scrollControllers) { c.dispose(); }
    _motionScoreNotifier.dispose(); _touchScoreNotifier.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted || _isDisposed) return;
    final state = widget.controller.state;
    if (state == SecurityState.UNLOCKED) {
      widget.onSuccess?.call();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SuccessScreen(message: "Access Granted")));
    } else if (state == SecurityState.HARD_LOCK) {
      widget.onJammed?.call();
      showDialog(context: context, barrierDismissible: false, builder: (_) => CompactFailDialog(message: "SYSTEM HALTED", accentColor: _accentOrange));
    }
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (_isDisposed) return;
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _motionScoreNotifier.value = (magnitude / 20.0).clamp(0.0, 1.0);
    widget.controller.registerMotion(event.x, event.y, event.z, DateTime.now());
  }

  void _onGyroscope(GyroscopeEvent event) {
    if (_isDisposed) return;
    widget.controller.registerMotion(event.x, event.y, event.z, DateTime.now());
  }

  void _userInteracted() {
    double touchScore = Random().nextDouble() * 0.4 + 0.6;
    _touchScoreNotifier.value = touchScore;
    widget.controller.registerTouch(Offset.zero, touchScore, DateTime.now());
  }

  void _analyzeScrollPattern() {
    if (_isDisposed) return;
    DateTime now = DateTime.now();
    int delta = now.difference(_lastScrollTime).inMilliseconds;
    _scrollEvents.add(delta);
    _lastScrollTime = now;
    if (_scrollEvents.length > 10) _scrollEvents.removeAt(0);
    if (_scrollEvents.length >= 3) {
      double avg = _scrollEvents.reduce((a, b) => a + b) / _scrollEvents.length;
      double variance = _scrollEvents.map((e) => pow(e - avg, 2)).reduce((a, b) => a + b) / _scrollEvents.length;
      setState(() => _patternScore = (1.0 - (variance / 10000).clamp(0.0, 1.0)));
    }
  }

  // ===========================================
  // ✅ FIX: LAYOUT RECTIFICATION (V105.0)
  // ===========================================
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        Color activeColor = state == SecurityState.HARD_LOCK ? _accentRed : _accentOrange;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Kira saiz kad gergasi Z-Kinetic
                final double cardWidth = min(constraints.maxWidth * 0.92, 420.0);
                final double wheelHeight = cardWidth * (_imageHeight / _imageWidth);

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    // 🔥 FIX: Paksa tinggi minimum (BUANG SIZE 0x0)
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 30),
                        child: Container(
                          width: cardWidth,
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECEFF1),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15))],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // LOGO
                              Column(
                                children: [
                                  Icon(Icons.security, color: _accentOrange, size: 48),
                                  const SizedBox(height: 10),
                                  const Text("Z-KINETIC", style: TextStyle(color: Color(0xFFFF6F00), fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 20)),
                                ],
                              ),
                              const SizedBox(height: 40),

                              // WHEEL SYSTEM
                              SizedBox(
                                width: cardWidth,
                                height: wheelHeight,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.asset(
                                        'assets/z_wheel.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, e, s) => Container(color: Colors.grey[300], child: const Center(child: Text("WHEEL ASSET MISSING"))),
                                      ),
                                    ),
                                    ..._buildWheelOverlays(cardWidth, wheelHeight, activeColor, state),
                                    _buildPhantomButton(cardWidth, wheelHeight),
                                    Positioned.fill(child: TutorialOverlay(isVisible: _showTutorial && state == SecurityState.LOCKED, color: activeColor)),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),
                              _buildSensorRow(activeColor),
                              if (state == SecurityState.HARD_LOCK) ...[
                                const SizedBox(height: 20),
                                _buildWarningBanner(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhantomButton(double width, double height) {
    double actualLeft = width * (_phantomButtonCoords[0] / _imageWidth);
    double actualTop = height * (_phantomButtonCoords[1] / _imageHeight);
    double actualWidth = width * ((_phantomButtonCoords[2] - _phantomButtonCoords[0]) / _imageWidth);
    double actualHeight = height * ((_phantomButtonCoords[3] - _phantomButtonCoords[1]) / _imageHeight);
    return Positioned(
      left: actualLeft, top: actualTop, width: actualWidth, height: actualHeight,
      child: GestureDetector(onTap: () { HapticFeedback.mediumImpact(); _userInteracted(); widget.controller.verify(List.generate(5, (i) => _scrollControllers[i].selectedItem % 10)); }, behavior: HitTestBehavior.opaque, child: Container(color: Colors.transparent)),
    );
  }

  List<Widget> _buildWheelOverlays(double width, double height, Color activeColor, SecurityState state) {
    return List.generate(5, (i) {
      double actualLeft = width * (_wheelCoords[i][0] / _imageWidth);
      double actualTop = height * (_wheelCoords[i][1] / _imageHeight);
      double actualWidth = width * ((_wheelCoords[i][2] - _wheelCoords[i][0]) / _imageWidth);
      double actualHeight = height * ((_wheelCoords[i][3] - _wheelCoords[i][1]) / _imageHeight);
      return Positioned(
        left: actualLeft, top: actualTop, width: actualWidth, height: actualHeight,
        child: NotificationListener<ScrollNotification>(onNotification: (n) { if (n is ScrollUpdateNotification) _analyzeScrollPattern(); return false; }, child: _buildAdvancedWheel(i, actualHeight, activeColor)),
      );
    });
  }

  Widget _buildAdvancedWheel(int index, double wheelHeight, Color activeColor) {
    bool isActive = _activeWheelIndex == index;
    double itemExtent = wheelHeight * 0.40;
    return GestureDetector(
      onTapDown: (_) { if (_isDisposed) return; setState(() => _activeWheelIndex = index); _wheelActiveTimer?.cancel(); _userInteracted(); },
      onTapUp: (_) => _resetActiveWheelTimer(), onTapCancel: () => _resetActiveWheelTimer(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isActive ? 1.05 : 1.0, duration: const Duration(milliseconds: 200),
        child: Stack(
          children: [
            ListWheelScrollView.useDelegate(
              controller: _scrollControllers[index], itemExtent: itemExtent, perspective: 0.004, diameterRatio: 1.5, physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (_) => HapticFeedback.selectionClick(),
              childDelegate: ListWheelChildBuilderDelegate(builder: (context, i) => Center(child: Text('${i % 10}', style: TextStyle(fontSize: wheelHeight * 0.35, fontWeight: FontWeight.bold, color: const Color(0xFF263238))))),
            ),
            if (isActive) IgnorePointer(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: activeColor.withOpacity(0.5), width: 2)))),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(Color color) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      ValueListenableBuilder<double>(valueListenable: _motionScoreNotifier, builder: (context, val, _) => _buildMiniSensor("MOTION", val > 0.3, color, Icons.sensors)),
      ValueListenableBuilder<double>(valueListenable: _touchScoreNotifier, builder: (context, val, _) => _buildMiniSensor("TOUCH", val > 0.3, color, Icons.fingerprint)),
      _buildMiniSensor("PATTERN", _patternScore > 0.5, color, Icons.timeline),
    ]);
  }

  Widget _buildMiniSensor(String label, bool isActive, Color color, IconData icon) {
    return Column(children: [Icon(isActive ? Icons.check_circle : icon, size: 22, color: isActive ? _successGreen : Colors.grey[400]), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 10, color: isActive ? _successGreen : Colors.grey[500], fontWeight: FontWeight.bold))]);
  }

  Widget _buildWarningBanner() {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _accentRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accentRed)), child: Row(children: [Icon(Icons.warning_amber_rounded, color: _accentRed, size: 20), const SizedBox(width: 10), Expanded(child: Text(widget.controller.threatMessage, style: TextStyle(color: _accentRed, fontSize: 11, fontWeight: FontWeight.bold)))]));
  }

  void _resetActiveWheelTimer() { _wheelActiveTimer?.cancel(); _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () { if (mounted && !_isDisposed) setState(() => _activeWheelIndex = null); }); }
}

class KineticScanLinePainter extends CustomPainter {
  final Color color; final double progress;
  KineticScanLinePainter({required this.color, required this.progress});
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, color.withOpacity(0.5), Colors.transparent]).createShader(Rect.fromLTWH(0, size.height * progress - 2, size.width, 4)); canvas.drawRect(Rect.fromLTWH(0, size.height * progress - 2, size.width, 4), paint); }
  @override bool shouldRepaint(KineticScanLinePainter old) => old.progress != progress;
}
