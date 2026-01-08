import 'dart:async';
import 'dart:math';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_models.dart';

// 🔥 ML PATTERN ANALYZER
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
    double tremorScore = _detectTremor(touchData);
    features.add(tremorScore);
    
    double humanScore = (features[0] * 0.4) + (features[1] * 0.6);
    return humanScore.clamp(0.0, 1.0);
  }
  
  static double _calculateVariance(List<double> data) {
    if (data.isEmpty) return 0.0;
    double mean = data.reduce((a, b) => a + b) / data.length;
    double sumSquaredDiff = data.map((x) => pow(x - mean, 2).toDouble()).reduce((a, b) => a + b);
    return sumSquaredDiff / data.length;
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

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _screenshotWatchdog;
  
  int? _activeWheelIndex;
  Timer? _wheelResetTimer;
  late List<FixedExtentScrollController> _scrollControllers;
  
  double _patternScore = 0.0;
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  bool _suspiciousRootBypass = false;
  
  late AnimationController _pulseController;
  late AnimationController _scanController;
  
  final Color _colNeon = const Color(0xFF00FFFF); 
  final Color _colPass = const Color(0xFF00FF88); 
  final Color _colFail = const Color(0xFFFF3333); 
  final Color _colDark = const Color(0xFF050A10); 

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
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }
  
  void _enableAntiScreenshot() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      const platform = MethodChannel('com.cryptex/security');
      platform.invokeMethod('enableScreenshotProtection');
    } catch (e) {}
  }

  void _startScreenshotWatchdog() {
    _screenshotWatchdog = Timer.periodic(const Duration(seconds: 2), (timer) {
      _detectScreenshotAttempt();
    });
  }

  void _detectScreenshotAttempt() async {
    try {
      const platform = MethodChannel('com.cryptex/security');
      final bool screenshotDetected = await platform.invokeMethod('checkScreenshot');
      if (screenshotDetected && mounted) setState(() {});
    } catch (e) {}
  }

  void _checkRootBypass() async {
    try {
      final List<String> suspiciousPackages = ['com.topjohnwu.magisk', 'eu.chainfire.supersu'];
      final List<String> suspiciousPaths = ['/system/xbin/su', '/system/bin/su'];
      const platform = MethodChannel('com.cryptex/security');
      final bool detected = await platform.invokeMethod('detectRootBypass', {
        'packages': suspiciousPackages,
        'paths': suspiciousPaths,
      });
      if (detected) setState(() => _suspiciousRootBypass = true);
    } catch (e) {}
  }

  void _handleControllerChange() {
    if (widget.controller.state == SecurityState.UNLOCKED) {
      widget.onSuccess();
    } else if (widget.controller.state == SecurityState.HARD_LOCK) {
      widget.onJammed(); 
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _accelSub?.cancel();
      _accelSub = null;
      _screenshotWatchdog?.cancel();
      _wheelResetTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_accelSub == null) _startListening();
      _startScreenshotWatchdog();
    }
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      return FixedExtentScrollController(initialItem: widget.controller.getInitialValue(index));
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent e) {
      double rawMag = e.x.abs() + e.y.abs() + e.z.abs();
      widget.controller.registerShake(rawMag, e.x, e.y, e.z);
    });
  }

  void _analyzeScrollPattern(int index) {
    final now = DateTime.now();
    double speed = 0.0;
    if (_lastScrollTime != null) {
      speed = 1000.0 / now.difference(_lastScrollTime!).inMilliseconds.toDouble();
    }
    _lastScrollTime = now;
    
    _touchData.add({'timestamp': now, 'speed': speed, 'pressure': 0.5, 'wheelIndex': index});
    if (_touchData.length > 20) _touchData.removeAt(0);
    
    if (_touchData.length >= 5) {
      _patternScore = MLPatternAnalyzer.analyzePattern(_touchData);
      setState(() {});
    }
  }

  // 🔥 LOGIC TOUCH BARU: Panggil ini bila jari sentuh skrin
  void _setActiveWheel(int index) {
    _wheelResetTimer?.cancel();
    setState(() {
      _activeWheelIndex = index;
    });
  }

  // 🔥 LOGIC TOUCH BARU: Panggil ini bila jari lepas
  void _resetActiveWheel() {
    _wheelResetTimer?.cancel();
    _wheelResetTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _activeWheelIndex = null;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel();
    _screenshotWatchdog?.cancel();
    _wheelResetTimer?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _triggerHaptic({bool heavy = false}) {
    if (heavy) HapticFeedback.heavyImpact();
    else HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return _buildStateUI(widget.controller.state);
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor = _colNeon;
    String statusText = "SYSTEM IDLE";
    IconData statusIcon = Icons.lock_outline;
    bool isInputDisabled = false;

    if (state == SecurityState.LOCKED) {
       bool hasMotion = widget.controller.motionConfidence > 0.05;
       bool hasTouch = widget.controller.touchConfidence > 0.3;
       
       if (widget.controller.motionConfidence > 0.8) { 
         statusText = "MOTION DETECTED";
         statusIcon = Icons.graphic_eq;
       } else if (hasMotion && hasTouch) {
         statusText = "SENSORS ACTIVE";
         statusIcon = Icons.sensors;
       } else if (hasTouch) {
         statusText = "TOUCH INPUT";
         statusIcon = Icons.touch_app;
       } else if (hasMotion) {
         statusText = "SCANNING...";
         statusIcon = Icons.radar;
         activeColor = _colNeon.withOpacity(0.7);
       }
    } else if (state == SecurityState.VALIDATING) {
        activeColor = Colors.white;
        statusText = "VERIFYING...";
        statusIcon = Icons.cloud_sync;
        isInputDisabled = true;
    } else if (state == SecurityState.SOFT_LOCK) {
        activeColor = _colFail;
        statusText = "AUTH FAILED";
        statusIcon = Icons.warning_amber_rounded;
        isInputDisabled = true;
    } else if (state == SecurityState.HARD_LOCK) {
        activeColor = _colFail;
        statusText = "TERMINAL LOCKOUT";
        statusIcon = Icons.block;
        isInputDisabled = true;
    } else if (state == SecurityState.ROOT_WARNING) {
        return _buildSecurityWarningUI(); 
    } else { 
        activeColor = _colPass;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.lock_open;
        isInputDisabled = true;
    }

    return Stack(
      children: [
        // LAYER 1: Grid Background
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return CustomPaint(
                  painter: GridPainter(
                    color: activeColor.withOpacity(0.1),
                    scanValue: _scanController.value,
                  ),
                );
              },
            ),
          ),
        ),

        // LAYER 2: Main Interface
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _colDark.withOpacity(0.9), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: activeColor.withOpacity(0.6), 
              width: 1.5
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withOpacity(0.15), 
                blurRadius: 30, 
                spreadRadius: 2
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(statusIcon, color: activeColor, size: 18),
                            const SizedBox(width: 8),
                            Text("Z-KINETIC V2.0", style: TextStyle(color: activeColor.withOpacity(0.7), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Text(
                              statusText, 
                              style: TextStyle(
                                color: activeColor, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                                letterSpacing: 1.0,
                                shadows: [
                                  BoxShadow(
                                    color: activeColor.withOpacity(0.6 * _pulseController.value), 
                                    blurRadius: 15
                                  )
                                ]
                              )
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // SENSORS
                  Column(
                    children: [
                       _buildHoloSensorBox("MOTION", widget.controller.motionConfidence, Icons.sensors),
                       const SizedBox(height: 6),
                       _buildHoloSensorBox("TOUCH", widget.controller.touchConfidence, Icons.fingerprint),
                       const SizedBox(height: 6),
                       _buildHoloPatternBox("PATTERN", _patternScore),
                    ],
                  )
                ],
              ),
              
              if (widget.controller.threatMessage.isNotEmpty || _suspiciousRootBypass) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _colFail.withOpacity(0.1),
                    border: Border.all(color: _colFail.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: _colFail, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("INTEGRITY BREACH", style: TextStyle(color: _colFail, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 25),
              
              // 💿 WHEELS (HOLOGRAPHIC & REACTIVE)
              SizedBox(
                height: 130,
                child: IgnorePointer(
                  ignoring: isInputDisabled,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      5, 
                      (index) => _buildHolographicWheel(index, activeColor, isInputDisabled)
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 25),
              
              // BUTTON
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: isInputDisabled 
                    ? null 
                    : () {
                        _triggerHaptic(heavy: true); 
                        widget.controller.validateAttempt(hasPhysicalMovement: true);
                      },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isInputDisabled 
                          ? [Colors.grey[800]!, Colors.grey[900]!]
                          : [activeColor.withOpacity(0.8), activeColor.withOpacity(0.4)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      border: Border.all(
                        color: isInputDisabled ? Colors.grey : activeColor, 
                        width: 1
                      ),
                      boxShadow: isInputDisabled ? [] : [
                        BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 15)
                      ]
                    ),
                    child: Center(
                      child: Text(
                        state == SecurityState.HARD_LOCK ? "SYSTEM LOCKED" : "INITIALIZE", 
                        style: TextStyle(
                          color: isInputDisabled ? Colors.grey : Colors.black,
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 2.0,
                          fontSize: 14
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              if (state == SecurityState.LOCKED && widget.controller.motionConfidence == 0) ...[
                const SizedBox(height: 12),
                Text("[ WAITING FOR BIO-INPUT ]", style: TextStyle(color: activeColor.withOpacity(0.5), fontSize: 10, fontFamily: 'Courier')),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildHoloSensorBox(String label, double value, IconData icon) {
    bool isPass = value > 0.6;
    bool hasData = value > 0.05;
    Color statusColor = !hasData ? Colors.grey.withOpacity(0.3) : (isPass ? _colPass : _colFail);

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor.withOpacity(0.5)),
        color: statusColor.withOpacity(0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 8, color: statusColor, fontWeight: FontWeight.bold)),
          if (hasData)
             Icon(isPass ? Icons.check : Icons.close, size: 10, color: statusColor)
          else 
             Container(width: 4, height: 4, color: statusColor)
        ],
      ),
    );
  }

  Widget _buildHoloPatternBox(String label, double score) {
    bool isPass = score >= 0.5;
    bool hasData = score > 0;
    Color statusColor = !hasData ? Colors.grey.withOpacity(0.3) : (isPass ? _colPass : _colFail);

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor.withOpacity(0.5)),
        color: statusColor.withOpacity(0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 8, color: statusColor, fontWeight: FontWeight.bold)),
          if (hasData)
             Icon(isPass ? Icons.check : Icons.close, size: 10, color: statusColor)
          else 
             Container(width: 4, height: 4, color: statusColor)
        ],
      ),
    );
  }

  // 💿 INSTANT GLOW HOLOGRAM WHEEL
  Widget _buildHolographicWheel(int index, Color color, bool disabled) {
    final bool isActive = (_activeWheelIndex == index);
    final double opacity = disabled ? 0.3 : (isActive ? 1.0 : 0.25);
    
    // 🔥 PENTING: Bungkus dengan Listener untuk kesan sentuhan serta-merta
    return Listener(
      onPointerDown: (_) => _setActiveWheel(index), // Sentuh je terus menyala!
      onPointerUp: (_) => _resetActiveWheel(),      // Lepas baru padam
      child: Column(
        children: [
          AnimatedContainer(duration: const Duration(milliseconds: 100), height: 1, width: isActive ? 40 : 0, color: color),
          
          Expanded(
            child: SizedBox(
              width: 45,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: opacity,
                child: Stack(
                  children: [
                    // Setiap roda ada NotificationListener sendiri untuk tracking scroll
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification) {
                          widget.controller.registerTouch(); 
                          _analyzeScrollPattern(index);
                          _setActiveWheel(index); // Keep active while scrolling
                        }
                        return false;
                      },
                      child: ListWheelScrollView.useDelegate(
                        controller: _scrollControllers[index],
                        itemExtent: 45,
                        perspective: 0.005,
                        diameterRatio: 1.4,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (val) {
                          _triggerHaptic(); 
                          widget.controller.updateWheel(index, val % 10);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, i) {
                            final num = i % 10;
                            return Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 100),
                                style: TextStyle(
                                  color: isActive ? color : Colors.grey[800],
                                  fontSize: isActive ? 30 : 26,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                  shadows: isActive ? [
                                    BoxShadow(color: color.withOpacity(0.9), blurRadius: 20),
                                    BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 5)
                                  ] : [],
                                ),
                                child: Text('$num'),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    if (isActive)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: ScanLinePainter(color: color, progress: _scanController.value),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          AnimatedContainer(duration: const Duration(milliseconds: 100), height: 1, width: isActive ? 40 : 0, color: color),
        ],
      ),
    );
  }

  Widget _buildSecurityWarningUI() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: const Color(0xFF100000), border: Border.all(color: _colFail, width: 2)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: _colFail, size: 48),
          const SizedBox(height: 20),
          Text("SYSTEM COMPROMISED", style: TextStyle(color: _colFail, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          Text("Root access detected.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _colFail, foregroundColor: Colors.white),
              onPressed: () { _triggerHaptic(heavy: true); widget.controller.userAcceptsRisk(); },
              child: const Text("OVERRIDE"),
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  final double scanValue;
  GridPainter({required this.color, required this.scanValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    double step = 20.0;
    
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0), color.withOpacity(0.3), color.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, size.height * scanValue - 20, size.width, 40));
      
    canvas.drawRect(Rect.fromLTWH(0, size.height * scanValue - 20, size.width, 40), scanPaint);
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => oldDelegate.scanValue != scanValue;
}

class ScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;
  ScanLinePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0), color.withOpacity(0.5), color.withOpacity(0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, size.height * progress, size.width, 2));

    canvas.drawRect(Rect.fromLTWH(0, size.height * progress, size.width, 2), paint);
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) => oldDelegate.progress != progress;
}
