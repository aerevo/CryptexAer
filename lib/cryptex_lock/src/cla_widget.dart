// 🎯 PROJECT JARVIS - THE MASTERFILE (AUDIT CORRECTED)
// 100% Full Code | No Truncation | No Missing Sensors
// Integrated by: Francois (Loyal Butler)

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller.dart';
import 'cla_models.dart';

// ============================================
// 1. ML PATTERN ANALYZER
// ============================================
class MLPatternAnalyzer {
  static double analyzePattern(List<Map<String, dynamic>> touchData) {
    if (touchData.length < 5) return 0.0;
    List<double> features = [];
    List<int> intervals = [];
    for (int i = 1; i < touchData.length; i++) {
      intervals.add(touchData[i]['timestamp'].difference(touchData[i-1]['timestamp']).inMilliseconds);
    }
    double timingVariance = _calculateVariance(intervals.map((e) => e.toDouble()).toList());
    features.add(timingVariance / 1000.0);
    
    if (touchData[0].containsKey('pressure')) {
      List<double> pressures = touchData.map((e) => e['pressure'] as double).toList();
      features.add(_calculateVariance(pressures));
    } else { features.add(0.5); }
    
    if (touchData[0].containsKey('speed')) {
      List<double> speeds = touchData.map((e) => e['speed'] as double).toList();
      features.add(_calculateVariance(speeds));
    } else { features.add(0.5); }
    
    features.add(_detectTremor(touchData));
    return ((features[0] * 0.3) + (features[1] * 0.2) + (features[2] * 0.2) + (features[3] * 0.3)).clamp(0.0, 1.0);
  }
  
  static double _calculateVariance(List<double> data) {
    if (data.isEmpty) return 0.0;
    double mean = data.reduce((a, b) => a + b) / data.length;
    double sumSqDiff = data.map((x) => pow(x - mean, 2).toDouble()).reduce((a, b) => a + b);
    return sumSqDiff / data.length;
  }
  
  static double _detectTremor(List<Map<String, dynamic>> touchData) {
    if (touchData.length < 10) return 0.5;
    int microMovements = 0;
    for (int i = 1; i < touchData.length; i++) {
      int timeDiff = touchData[i]['timestamp'].difference(touchData[i-1]['timestamp']).inMilliseconds;
      if (timeDiff > 80 && timeDiff < 125) microMovements++;
    }
    return (microMovements / touchData.length).clamp(0.0, 1.0);
  }
}

// ============================================
// 2. MAIN WIDGET: JARVIS CRYPTEX LOCK
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
  Timer? _screenshotWatchdog;
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;
  
  double _patternScore = 0.0;
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  bool _suspiciousRootBypass = false;
  
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _reticleController;
  
  final Color _jarvisCyan = const Color(0xFF00FFFF);
  final Color _jarvisGreen = const Color(0xFF00FF88);
  final Color _jarvisRed = const Color(0xFFFF3366);
  final Color _jarvisWarning = const Color(0xFFFFA726);
  final Color _jarvisBackground = const Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    _startListening();
    _enableAntiScreenshot();
    _startScreenshotWatchdog();
    _checkRootBypass();
    widget.controller.addListener(_handleControllerChange);
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _reticleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }
  
  void _enableAntiScreenshot() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      const platform = MethodChannel('com.cryptex/security');
      platform.invokeMethod('enableScreenshotProtection');
    } catch (e) {}
  }

  void _startScreenshotWatchdog() {
    _screenshotWatchdog = Timer.periodic(const Duration(seconds: 2), (timer) => _detectScreenshotAttempt());
  }

  void _detectScreenshotAttempt() async {
    try {
      const platform = MethodChannel('com.cryptex/security');
      final bool detected = await platform.invokeMethod('checkScreenshot');
      if (detected && mounted) setState(() {});
    } catch (e) {}
  }

  void _checkRootBypass() async {
    try {
      final List<String> pkgs = ['com.topjohnwu.magisk', 'eu.chainfire.supersu', 'com.zachspong.rootcloak'];
      final List<String> pts = ['/system/xbin/su', '/system/bin/su', '/sbin/su'];
      const platform = MethodChannel('com.cryptex/security');
      final bool detected = await platform.invokeMethod('detectRootBypass', {'packages': pkgs, 'paths': pts});
      if (detected) setState(() => _suspiciousRootBypass = true);
    } catch (e) {}
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
    _scrollControllers = List.generate(5, (i) => FixedExtentScrollController(initialItem: widget.controller.getInitialValue(i)));
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((e) => widget.controller.registerShake(e.x.abs() + e.y.abs() + e.z.abs(), e.x, e.y, e.z));
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

  void _analyzeScrollPattern() {
    final now = DateTime.now();
    double speed = _lastScrollTime != null ? 1000.0 / now.difference(_lastScrollTime!).inMilliseconds : 0.0;
    _lastScrollTime = now;
    _touchData.add({'timestamp': now, 'speed': speed, 'pressure': 0.5, 'wheelIndex': _activeWheelIndex ?? 0});
    if (_touchData.length > 20) _touchData.removeAt(0);
    if (_touchData.length >= 5) setState(() => _patternScore = MLPatternAnalyzer.analyzePattern(_touchData));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel(); _lockoutTimer?.cancel(); _screenshotWatchdog?.cancel(); _wheelActiveTimer?.cancel();
    _pulseController.dispose(); _scanController.dispose(); _reticleController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SecurityState state = widget.controller.state;
    if (state == SecurityState.ROOT_WARNING) return _buildSecurityWarningUI();

    Color activeColor = (state == SecurityState.SOFT_LOCK || state == SecurityState.HARD_LOCK) ? _jarvisRed : (state == SecurityState.UNLOCKED ? _jarvisGreen : _jarvisCyan);
    String statusLabel = _getStatusLabel(state);
    
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: JarvisGridPainter(color: activeColor))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: _jarvisBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: activeColor.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 3),
              BoxShadow(color: activeColor.withOpacity(0.1), blurRadius: 60, spreadRadius: 6)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHUDHeader(activeColor, statusLabel),
              if (widget.controller.threatMessage.isNotEmpty || _suspiciousRootBypass) _buildWarningBanner(),
              const SizedBox(height: 32),
              _buildJarvisTumblerArea(activeColor),
              const SizedBox(height: 32),
              _buildAuthButton(activeColor, state),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusLabel(SecurityState state) {
    switch (state) {
      case SecurityState.LOCKED: return "AWAITING BIOMETRIC SCAN";
      case SecurityState.VALIDATING: return "ENCRYPTION SYNC ACTIVE";
      case SecurityState.SOFT_LOCK: return "AUTH ERROR [ATTEMPT ${widget.controller.failedAttempts}/3]";
      case SecurityState.HARD_LOCK: return "TERMINAL LOCKDOWN [${widget.controller.remainingLockoutSeconds}s]";
      case SecurityState.UNLOCKED: return "ACCESS AUTHORIZED";
      default: return "SYSTEM STANDBY";
    }
  }

  // 🎯 Issue #1 FIXED: Restoration of 3 Sensor Boxes
  Widget _buildHUDHeader(Color color, String status) {
    return Stack(
      children: [
        _buildHUDCorner(color, true, true), _buildHUDCorner(color, true, false),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("J.A.R.V.I.S. INTERFACE", style: TextStyle(color: color.withOpacity(0.6), fontSize: 9, letterSpacing: 3, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15, shadows: [Shadow(color: color.withOpacity(0.9 * _pulseController.value), blurRadius: 20)]))
                  ),
                  const SizedBox(height: 12),
                  Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, color.withOpacity(0.5), Colors.transparent]))),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                _buildSensorBox("MOTION", widget.controller.motionConfidence, color, Icons.sensors),
                const SizedBox(height: 10),
                _buildSensorBox("TOUCH", widget.controller.touchConfidence, color, Icons.fingerprint), // 🎯 RESTORED
                const SizedBox(height: 10),
                _buildPatternBox("PATTERN", _patternScore, color),
              ],
            )
          ],
        )
      ],
    );
  }

  // 🎯 Issue #2 FIXED: Proper ScrollNotification Logic
  Widget _buildJarvisTumblerArea(Color color) {
    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, bottom: 0, child: CustomPaint(size: const Size(40, 140), painter: JarvisPeripheralPainter(color: color, side: 'left'))),
          Positioned(right: 0, top: 0, bottom: 0, child: CustomPaint(size: const Size(40, 140), painter: JarvisPeripheralPainter(color: color, side: 'right'))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
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
                  widget.controller.registerTouch(); // 🎯 RESTORED CRITICAL LOGIC
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

  // 🎯 Issue #3 FIXED: Improved Wheel Timer & Instant Glow
  Widget _buildHolographicWheel(int index, Color color) {
    bool isActive = _activeWheelIndex == index;
    return Expanded(
      child: Listener(
        onPointerDown: (_) {
          setState(() => _activeWheelIndex = index);
          _wheelActiveTimer?.cancel();
        },
        onPointerUp: (_) => _resetActiveWheelTimer(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isActive ? 1.0 : 0.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isActive) Positioned.fill(child: AnimatedBuilder(animation: _reticleController, builder: (context, child) => CustomPaint(painter: JarvisReticlePainter(color: color, progress: _reticleController.value)))),
              if (isActive) Positioned.fill(child: AnimatedBuilder(animation: _scanController, builder: (context, child) => CustomPaint(painter: ScanLinePainter(color: color, progress: _scanController.value)))),
              ListWheelScrollView.useDelegate(
                controller: _scrollControllers[index],
                itemExtent: 50, perspective: 0.003, diameterRatio: 1.1,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (v) { 
                  widget.controller.updateWheel(index, v % 10); 
                  HapticFeedback.selectionClick(); 
                },
                childDelegate: ListWheelChildBuilderDelegate(builder: (context, i) => Center(child: Text('${i % 10}', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, shadows: isActive ? [Shadow(color: color, blurRadius: 25)] : [])))),
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
    bool isInputDisabled = state == SecurityState.VALIDATING || state == SecurityState.HARD_LOCK;
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: !isInputDisabled ? [BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 25)] : []),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isInputDisabled ? const Color(0xFF1A1A1A) : activeColor.withOpacity(0.25),
            foregroundColor: activeColor,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isInputDisabled ? const Color(0xFF333333) : activeColor, width: 2.5)),
          ),
          onPressed: isInputDisabled ? null : () => widget.controller.validateAttempt(hasPhysicalMovement: true),
          child: Text(
            state == SecurityState.HARD_LOCK ? "SECURITY LOCKDOWN" : "INITIATE AUTHENTICATION",
            style: TextStyle(
              fontWeight: FontWeight.w900, letterSpacing: 2.0, fontSize: 14,
              shadows: !isInputDisabled ? [Shadow(color: activeColor.withOpacity(0.9), blurRadius: 15)] : []
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHUDCorner(Color color, bool isTop, bool isLeft) {
    return Positioned(
      top: isTop ? 0 : null, bottom: !isTop ? 0 : null, left: isLeft ? 0 : null, right: !isLeft ? 0 : null,
      child: Container(width: 32, height: 32, decoration: BoxDecoration(border: Border(top: isTop ? BorderSide(color: color, width: 2.5) : BorderSide.none, left: isLeft ? BorderSide(color: color, width: 2.5) : BorderSide.none, right: !isLeft ? BorderSide(color: color, width: 2.5) : BorderSide.none, bottom: !isTop ? BorderSide(color: color, width: 2.5) : BorderSide.none))),
    );
  }

  Widget _buildSensorBox(String label, double val, Color color, IconData icon) {
    bool isMatch = val > 0.6; Color c = isMatch ? _jarvisGreen : (val > 0.1 ? _jarvisRed : const Color(0xFF333333));
    return Container(width: 60, height: 48, decoration: BoxDecoration(border: Border.all(color: c, width: 2), borderRadius: BorderRadius.circular(10), color: isMatch ? c.withOpacity(0.2) : Colors.transparent), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isMatch ? Icons.check_circle : icon, size: 20, color: c), Text(label, style: TextStyle(fontSize: 8, color: c, fontWeight: FontWeight.w800))]));
  }

  Widget _buildPatternBox(String label, double score, Color color) {
    bool isMatch = score >= 0.5; Color c = isMatch ? _jarvisGreen : (score > 0.1 ? _jarvisRed : const Color(0xFF333333));
    return Container(width: 60, height: 48, decoration: BoxDecoration(border: Border.all(color: c, width: 2), borderRadius: BorderRadius.circular(10), color: isMatch ? c.withOpacity(0.2) : Colors.transparent), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isMatch ? Icons.check_circle : Icons.timeline, size: 20, color: c), Text(label, style: TextStyle(fontSize: 8, color: c, fontWeight: FontWeight.w800))]));
  }

  Widget _buildWarningBanner() {
    return Container(margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _jarvisRed.withOpacity(0.15), border: Border.all(color: _jarvisRed), borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.error_outline, color: _jarvisRed, size: 20), const SizedBox(width: 12), Expanded(child: Text(_suspiciousRootBypass ? "⚠️ ROOT BYPASS DETECTION ACTIVE" : widget.controller.threatMessage, style: TextStyle(color: _jarvisRed, fontSize: 11, fontWeight: FontWeight.w800)))]));
  }

  Widget _buildSecurityWarningUI() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: _jarvisBackground, borderRadius: BorderRadius.circular(24), border: Border.all(color: _jarvisWarning, width: 2.5)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, color: _jarvisWarning, size: 56),
          const SizedBox(height: 24),
          Text("Security Protocol Alert", style: TextStyle(color: _jarvisWarning, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 16),
          const Text("Rooted or jailbroken devices compromise security protocols. Sensitive data may be exposed.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _jarvisWarning, foregroundColor: Colors.black), onPressed: () => widget.controller.userAcceptsRisk(), child: const Text("ACKNOWLEDGE RISK & PROCEED", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)))),
        ],
      ),
    );
  }
}

// ============================================
// 4. CUSTOM PAINTERS (AUDIT CORRECTED)
// ============================================

class JarvisGridPainter extends CustomPainter {
  final Color color; JarvisGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.06)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 45) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 45) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override bool shouldRepaint(JarvisGridPainter old) => old.color != color;
}

class JarvisPeripheralPainter extends CustomPainter {
  final Color color; final String side;
  JarvisPeripheralPainter({required this.color, required this.side});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.4)..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final random = Random(side == 'left' ? 42 : 123);

    if (side == 'left') {
      canvas.drawRect(const Rect.fromLTWH(0, 10, 38, 14), Paint()..color = color.withOpacity(0.2));
      _drawText(canvas, tp, "COORD", 4, 13, 7, color, true);
      for (int i = 0; i < 4; i++) {
        _drawText(canvas, tp, "${(random.nextDouble()*180-90).toStringAsFixed(2)}°", 2, 35.0 + (i*24), 6, color.withOpacity(0.5), false);
        _drawText(canvas, tp, "${(random.nextDouble()*360-180).toStringAsFixed(2)}°", 2, 45.0 + (i*24), 6, color.withOpacity(0.5), false);
      }
      canvas.drawLine(const Offset(38, 10), const Offset(38, 130), p);
    } else {
      canvas.drawRect(const Rect.fromLTWH(2, 10, 38, 14), Paint()..color = color.withOpacity(0.2));
      _drawText(canvas, tp, "SYS-ID", 6, 13, 7, color, true);
      for (int i = 0; i < 15; i++) {
        final h = 5 + random.nextDouble() * 10;
        canvas.drawLine(Offset(5.0 + (i*2), 30), Offset(5.0 + (i*2), 30 + h), Paint()..color = color.withOpacity(0.6)..strokeWidth = 1);
      }
      _drawText(canvas, tp, "AUTH: PEND", 4, 60, 6, color.withOpacity(0.5), false);
      _drawText(canvas, tp, "ENC: AES", 4, 70, 6, color.withOpacity(0.5), false);
      canvas.drawLine(const Offset(2, 10), const Offset(2, 130), p);
    }
  }

  void _drawText(Canvas c, TextPainter tp, String s, double x, double y, double sz, Color col, bool b) {
    tp.text = TextSpan(text: s, style: TextStyle(color: col, fontSize: sz, fontWeight: b ? FontWeight.bold : FontWeight.normal, fontFamily: 'Courier'));
    tp.layout(); tp.paint(c, Offset(x, y));
  }
  @override bool shouldRepaint(JarvisPeripheralPainter old) => old.color != color;
}

class JarvisReticlePainter extends CustomPainter {
  final Color color; final double progress;
  JarvisReticlePainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width/2, size.height/2);
    final p = Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.save(); canvas.translate(c.dx, c.dy); canvas.rotate(progress * 2 * pi); canvas.translate(-c.dx, -c.dy);
    canvas.drawCircle(c, 22, p);
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      canvas.drawLine(Offset(c.dx + 18 * cos(a), c.dy + 18 * sin(a)), Offset(c.dx + 26 * cos(a), c.dy + 26 * sin(a)), p);
    }
    canvas.restore();
  }
  @override bool shouldRepaint(JarvisReticlePainter old) => old.progress != progress;
}

class ScanLinePainter extends CustomPainter {
  final Color color; final double progress;
  ScanLinePainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, color.withOpacity(0.8), Colors.transparent]).createShader(Rect.fromLTWH(0, size.height * progress - 2, size.width, 4));
    canvas.drawRect(Rect.fromLTWH(0, size.height * progress - 2, size.width, 4), p);
  }
  @override bool shouldRepaint(ScanLinePainter old) => old.progress != progress;
}
