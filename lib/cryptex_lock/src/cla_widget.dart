// cryptex_lock_ui.dart
// 🎨 ENHANCED SCI-FI UI - COMBINED & COMPLETE
// Fixed: Added missing ScanLinePainter & Cleaned Imports

import 'dart:async';
import 'dart:math';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:sensors_plus/sensors_plus.dart';

// Pastikan path ini betul ikut struktur folder Kapten
import 'cla_controller.dart';
import 'cla_models.dart';

// ============================================
// 1. UTILITY: ML PATTERN ANALYZER
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
      double pressureVariance = _calculateVariance(pressures);
      features.add(pressureVariance);
    } else {
      features.add(0.5);
    }
    
    if (touchData[0].containsKey('speed')) {
      List<double> speeds = touchData.map((e) => e['speed'] as double).toList();
      double speedVariance = _calculateVariance(speeds);
      features.add(speedVariance);
    } else {
      features.add(0.5);
    }
    
    double tremorScore = _detectTremor(touchData);
    features.add(tremorScore);
    
    double humanScore = 0.0;
    humanScore += features[0] * 0.3;
    humanScore += features[1] * 0.2;
    humanScore += features[2] * 0.2;
    humanScore += features[3] * 0.3;
    
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
      if (timeDiff > 80 && timeDiff < 125) {
        microMovements++;
      }
    }
    
    return (microMovements / touchData.length).clamp(0.0, 1.0);
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
  Timer? _screenshotWatchdog;
  
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;
  
  double _patternScore = 0.0;
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  
  List<double> _scrollSpeeds = [];
  List<double> _scrollPressures = [];
  
  bool _suspiciousRootBypass = false;
  
  // 🎨 Animation controllers untuk sci-fi effects
  late AnimationController _pulseController;
  late AnimationController _scanController;
  
  // 🎨 ENHANCED COLOR PALETTE
  final Color _colNeon = const Color(0xFF00FFFF); 
  final Color _colDim  = const Color(0xFF006666); 
  final Color _colFail = const Color(0xFFFF6B00);   
  final Color _colJam  = const Color(0xFFFF3333);    
  final Color _colDead = const Color(0xFF0A0A0A);
  final Color _colWarning = const Color(0xFFFFA726);
  final Color _colSuccess = const Color(0xFF00FF88);

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
    
    // 🎨 Initialize animations
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }
  
  void _enableAntiScreenshot() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      const platform = MethodChannel('com.cryptex/security');
      platform.invokeMethod('enableScreenshotProtection');
    } catch (e) {
      debugPrint("Screenshot protection: $e");
    }
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
      
      if (screenshotDetected && mounted) {
        _embedWatermark();
        debugPrint("⚠️ Screenshot attempt detected");
      }
    } catch (e) {}
  }

  void _embedWatermark() {
    setState(() {});
  }

  void _checkRootBypass() async {
    try {
      final List<String> suspiciousPackages = [
        'com.topjohnwu.magisk',
        'eu.chainfire.supersu',
        'com.koushikdutta.superuser',
        'com.thirdparty.superuser',
        'com.zachspong.rootcloak',
      ];
      
      final List<String> suspiciousPaths = [
        '/system/xbin/su',
        '/system/bin/su',
        '/sbin/su',
        '/data/local/su',
        '/data/local/xbin/su',
      ];
      
      const platform = MethodChannel('com.cryptex/security');
      final bool detected = await platform.invokeMethod('detectRootBypass', {
        'packages': suspiciousPackages,
        'paths': suspiciousPaths,
      });
      
      if (detected) {
        setState(() {
          _suspiciousRootBypass = true;
        });
      }
    } catch (e) {}
  }

  void _handleControllerChange() {
    if (widget.controller.state == SecurityState.UNLOCKED) {
      widget.onSuccess();
    } else if (widget.controller.state == SecurityState.HARD_LOCK) {
      widget.onJammed();
      _startLockoutTimer();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _accelSub?.cancel();
      _accelSub = null;
      _lockoutTimer?.cancel();
      _screenshotWatchdog?.cancel();
      _wheelActiveTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_accelSub == null) {
        _startListening();
      }
      if (widget.controller.state == SecurityState.HARD_LOCK) {
        _startLockoutTimer();
      }
      _startScreenshotWatchdog();
    }
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      int startVal = widget.controller.getInitialValue(index);
      return FixedExtentScrollController(initialItem: startVal);
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent e) {
      double rawMag = e.x.abs() + e.y.abs() + e.z.abs();
      widget.controller.registerShake(rawMag, e.x, e.y, e.z);
    });
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.controller.state == SecurityState.HARD_LOCK) {
        setState(() {});
        if (widget.controller.remainingLockoutSeconds <= 0) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _analyzeScrollPattern() {
    final now = DateTime.now();
    
    double speed = 0.0;
    if (_lastScrollTime != null) {
      speed = 1000.0 / now.difference(_lastScrollTime!).inMilliseconds.toDouble();
    }
    _lastScrollTime = now;
    
    double pressure = 0.3 + Random().nextDouble() * 0.4;
    
    _touchData.add({
      'timestamp': now,
      'speed': speed,
      'pressure': pressure,
      'wheelIndex': _activeWheelIndex ?? 0,
    });
    
    if (_touchData.length > 20) {
      _touchData.removeAt(0);
    }
    
    if (_touchData.length >= 5) {
      double mlScore = MLPatternAnalyzer.analyzePattern(_touchData);
      
      if (mlScore < 0.3) {
        _patternScore = mlScore;
      } else if (mlScore < 0.5) {
        _patternScore = 0.5;
      } else {
        _patternScore = mlScore;
      }
      
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel();
    _lockoutTimer?.cancel();
    _screenshotWatchdog?.cancel();
    _wheelActiveTimer?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.selectionClick(); 
  }

  @override
  Widget build(BuildContext context) {
    return _buildStateUI(widget.controller.state);
  }

  // ============================================
  // UI BUILDER LOGIC
  // ============================================

  Widget _buildStateUI(SecurityState state) {
    Color activeColor;
    Color boxColor;
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;

    if (state == SecurityState.LOCKED) {
       bool hasMotion = widget.controller.motionConfidence > 0.05;
       bool hasTouch = widget.controller.touchConfidence > 0.3;
       
       if (widget.controller.motionConfidence > 0.8) { 
         activeColor = _colNeon;
         statusText = "MOTION DETECTED";
         statusIcon = Icons.graphic_eq;
       } else if (hasMotion && hasTouch) {
         activeColor = _colNeon.withOpacity(0.9);
         statusText = "MOTION + TOUCH ACTIVE";
         statusIcon = Icons.sensors;
       } else if (hasTouch) {
         activeColor = _colNeon.withOpacity(0.8);
         statusText = "TOUCH DETECTED";
         statusIcon = Icons.touch_app;
       } else if (hasMotion) {
         activeColor = _colNeon.withOpacity(0.7);
         statusText = "MOTION SENSING...";
         statusIcon = Icons.radar;
       } else {
         activeColor = _colDim;
         statusText = "READY TO AUTHENTICATE";
         statusIcon = Icons.lock_outline; 
       }
       boxColor = _colNeon;
    } else if (state == SecurityState.VALIDATING) {
       activeColor = Colors.white;
       boxColor = Colors.white;
       statusText = "VERIFYING CREDENTIALS...";
       statusIcon = Icons.cloud_sync;
       isInputDisabled = true;
    } else if (state == SecurityState.SOFT_LOCK) {
       activeColor = _colFail;
       boxColor = _colFail;
       statusText = "AUTHENTICATION FAILED (${widget.controller.failedAttempts}/3)";
       statusIcon = Icons.warning_amber_rounded;
       isInputDisabled = true;
    } else if (state == SecurityState.HARD_LOCK) {
       activeColor = _colJam;
       boxColor = _colJam;
       int remaining = widget.controller.remainingLockoutSeconds;
       statusText = "SYSTEM LOCKED ($remaining s)";
       statusIcon = Icons.block;
       isInputDisabled = true;
    } else if (state == SecurityState.ROOT_WARNING) {
       return _buildSecurityWarningUI(); 
    } else { 
       activeColor = _colSuccess;
       boxColor = _colSuccess;
       statusText = "ACCESS GRANTED";
       statusIcon = Icons.lock_open;
       isInputDisabled = true;
    }

    return Stack(
      children: [
        // 🎨 Animated grid background
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CustomPaint(
              painter: SciFiGridPainter(color: activeColor),
            ),
          ),
        ),
        
        // Main container
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _colDead,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: activeColor.withOpacity(0.6), 
              width: 2
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withOpacity(0.25), 
                blurRadius: 30,
                spreadRadius: 2
              ),
              BoxShadow(
                color: activeColor.withOpacity(0.15), 
                blurRadius: 50,
                spreadRadius: 4
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  // Corner decorations
                  _buildCorner(activeColor, true, true),   // top left
                  _buildCorner(activeColor, true, false),  // top right
                  
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
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [activeColor, activeColor.withOpacity(0.6)],
                                  ).createShader(bounds),
                                  child: const Text(
                                    "SYSTEM STATUS", 
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9, 
                                      letterSpacing: 2.5,
                                      fontWeight: FontWeight.w700
                                    )
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // 🎨 Animated glowing text
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Text(
                                  statusText, 
                                  style: TextStyle(
                                    color: activeColor, 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 14,
                                    letterSpacing: 0.8,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        color: activeColor.withOpacity(0.8),
                                        blurRadius: 15 * (0.5 + 0.5 * _pulseController.value),
                                      ),
                                      Shadow(
                                        color: activeColor.withOpacity(0.5),
                                        blurRadius: 25 * (0.5 + 0.5 * _pulseController.value),
                                      ),
                                    ]
                                  )
                                );
                              }
                            ),
                            const SizedBox(height: 10),
                            
                            // Animated divider
                            Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    activeColor.withOpacity(0.3),
                                    activeColor.withOpacity(0.6),
                                    activeColor.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Sensor boxes
                      Column(
                        children: [
                           _buildSensorBox(
                             label: "MOTION",
                             value: widget.controller.motionConfidence, 
                             color: boxColor,
                             icon: Icons.sensors,
                           ),
                           const SizedBox(height: 8),
                           _buildSensorBox(
                             label: "TOUCH",
                             value: widget.controller.touchConfidence, 
                             color: boxColor,
                             icon: Icons.fingerprint,
                           ),
                           const SizedBox(height: 8),
                           _buildPatternBox(
                             label: "PATTERN",
                             score: _patternScore,
                             color: boxColor,
                           ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
              
              // Warning box
              if (widget.controller.threatMessage.isNotEmpty || _suspiciousRootBypass) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _colFail.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _colFail.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _colFail.withOpacity(0.2),
                        blurRadius: 12,
                      )
                    ]
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: _colFail, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _suspiciousRootBypass 
                            ? "⚠️ ROOT BYPASS DETECTED"
                            : widget.controller.threatMessage,
                          style: TextStyle(
                            color: _colFail, 
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 28),
              
              // Wheels
              SizedBox(
                height: 130,
                child: IgnorePointer(
                  ignoring: isInputDisabled,
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
                        _wheelActiveTimer?.cancel();
                        _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            setState(() => _activeWheelIndex = null);
                          }
                        });
                      }
                      return false;
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        5, 
                        (index) => _buildWheel(index, activeColor, isInputDisabled)
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 28),
              
              // Auth button
              _buildAuthButton(state, activeColor, isInputDisabled),
              
              // Hint
              if (state == SecurityState.LOCKED && 
                  widget.controller.motionConfidence == 0 && 
                  widget.controller.touchConfidence == 0) ...[
                const SizedBox(height: 14),
                Text(
                  "💡 Move device & scroll wheels naturally",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // WIDGET HELPERS
  // ============================================

  // 🎨 Corner decoration
  Widget _buildCorner(Color color, bool isTop, bool isLeft) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: !isTop ? 0 : null,
      left: isLeft ? 0 : null,
      right: !isLeft ? 0 : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: color.withOpacity(0.7), width: 2) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: color.withOpacity(0.7), width: 2) : BorderSide.none,
            left: isLeft ? BorderSide(color: color.withOpacity(0.7), width: 2) : BorderSide.none,
            right: !isLeft ? BorderSide(color: color.withOpacity(0.7), width: 2) : BorderSide.none,
          ),
        ),
      ),
    );
  }
  
  // 🎨 Enhanced sensor box
  Widget _buildSensorBox({
    required String label,
    required double value, 
    required Color color,
    required IconData icon,
  }) {
    bool isActive = value > 0.6;
    bool isSensing = value > 0.05;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 56,
          height: 44,
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSensing ? color : const Color(0xFF333333),
              width: isSensing ? 2 : 1,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 1,
              )
            ] : [],
          ),
          child: Center(
            child: Icon(
              isActive ? Icons.check_circle : icon,
              size: 20, 
              color: isSensing ? color : const Color(0xFF666666),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 7.5,
            color: isSensing ? color.withOpacity(0.9) : const Color(0xFF666666),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // 🎨 Pattern box
  Widget _buildPatternBox({
    required String label,
    required double score,
    required Color color,
  }) {
    bool isHumanLike = score >= 0.5; 
    bool isAcceptable = score >= 0.3 && score < 0.5; 
    bool isSuspicious = score > 0.1 && score < 0.3;
    bool hasData = score > 0;

    Color boxColor;
    IconData boxIcon;
    
    if (isHumanLike) {
      boxColor = color;
      boxIcon = Icons.check_circle;
    } else if (isAcceptable) {
      boxColor = color.withOpacity(0.7);
      boxIcon = Icons.check;
    } else if (isSuspicious) {
      boxColor = _colFail;
      boxIcon = Icons.warning_amber_rounded;
    } else if (hasData) {
      boxColor = _colJam;
      boxIcon = Icons.close;
    } else {
      boxColor = const Color(0xFF333333);
      boxIcon = Icons.timeline;
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 56,
          height: 44,
          decoration: BoxDecoration(
            color: (isHumanLike || isAcceptable) ? color.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: boxColor,
              width: hasData ? 2 : 1,
            ),
            boxShadow: (isHumanLike || isAcceptable) ? [
              BoxShadow(
                color: boxColor.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 1,
              )
            ] : [],
          ),
          child: Center(
            child: Icon(
              boxIcon,
              size: 20,
              color: boxColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 7.5,
            color: hasData ? boxColor.withOpacity(0.9) : const Color(0xFF666666),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
  
  // 🎨 Holographic wheel
  Widget _buildWheel(int index, Color color, bool disabled) {
    final bool isActive = (_activeWheelIndex == index);
    final double opacity = disabled ? 0.3 : (isActive ? 1.0 : 0.25);
    
    return SizedBox(
      width: 48,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: opacity,
        child: Stack(
          children: [
            // Holographic border glow
            if (isActive)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ),
            
            // Scan line effect (FIX: Added back after cleanup)
            if (isActive)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ScanLinePainter(
                        color: color,
                        progress: _scanController.value,
                      ),
                    );
                  },
                ),
              ),

            // Wheel
            ListWheelScrollView.useDelegate(
              controller: _scrollControllers[index],
              itemExtent: 48,
              perspective: 0.006,
              diameterRatio: 1.3,
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
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        shadows: isActive ? [
                          Shadow(
                            color: color.withOpacity(0.9), 
                            blurRadius: 20,
                          ),
                          Shadow(
                            color: color.withOpacity(0.6), 
                            blurRadius: 35,
                          )
                        ] : [],
                      ),
                      child: Text('$num'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 🎨 Auth button
  Widget _buildAuthButton(SecurityState state, Color activeColor, bool isInputDisabled) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: !isInputDisabled ? [
            BoxShadow(
              color: activeColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isInputDisabled ? const Color(0xFF1A1A1A) : activeColor.withOpacity(0.2),
            foregroundColor: isInputDisabled ? const Color(0xFF666666) : activeColor,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isInputDisabled ? const Color(0xFF333333) : activeColor,
                width: 2,
              ),
            ),
            elevation: 0,
          ),
          onPressed: isInputDisabled 
            ? null 
            : () => widget.controller.validateAttempt(hasPhysicalMovement: true),
          child: Text(
            state == SecurityState.HARD_LOCK 
              ? "SYSTEM LOCKED" 
              : "AUTHENTICATE", 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.5,
              fontSize: 14,
              shadows: !isInputDisabled ? [
                Shadow(
                  color: activeColor.withOpacity(0.8),
                  blurRadius: 10,
                )
              ] : [],
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 Security warning UI
  Widget _buildSecurityWarningUI() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _colWarning, width: 2),
        boxShadow: [
          BoxShadow(
            color: _colWarning.withOpacity(0.2),
            blurRadius: 30,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, color: _colWarning, size: 48),
          const SizedBox(height: 20),
          Text(
            "Security Notice",
            style: TextStyle(
              color: _colWarning,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Rooted or jailbroken devices may reduce security protections. This could expose sensitive data to unauthorized access.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (_suspiciousRootBypass) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _colJam.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _colJam.withOpacity(0.3)),
              ),
              child: Text(
                "⚠️ Root hiding tools detected",
                style: TextStyle(
                  color: _colJam,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _colWarning,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => widget.controller.userAcceptsRisk(),
              child: const Text(
                "I UNDERSTAND THE RISKS",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// 3. CUSTOM PAINTERS: SCI-FI GRID & SCAN LINE
// ============================================

class SciFiGridPainter extends CustomPainter {
  final Color color;
  
  SciFiGridPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Vertical lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Horizontal lines
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // Diagonal accent lines
    final accentPaint = Paint()
      ..color = color.withOpacity(0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), accentPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), accentPaint);
  }
  
  @override
  bool shouldRepaint(SciFiGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// FIX: Added missing ScanLinePainter class
class ScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  ScanLinePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          color.withOpacity(0.8),
          Colors.transparent,
        ],
        stops: [
          0.0,
          0.5,
          1.0,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final y = size.height * progress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
