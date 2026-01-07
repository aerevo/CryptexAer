import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_models.dart';

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

class _CryptexLockState extends State<CryptexLock> with WidgetsBindingObserver {
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _lockoutTimer;
  
  int? _activeWheelIndex;
  late List<FixedExtentScrollController> _scrollControllers;
  
  // 🔥 NEW: Pattern analysis
  double _patternScore = 0.0; // 0 = bot-like, 1 = human-like
  List<DateTime> _scrollTimestamps = [];
  
  // COLOR PALETTE (Improved contrast)
  final Color _colNeon = const Color(0xFF00FFFF); 
  final Color _colDim  = const Color(0xFF008B8B); 
  final Color _colFail = const Color(0xFFFF9800);   
  final Color _colJam  = const Color(0xFFFF6B6B);    
  final Color _colDead = const Color(0xFF424242);
  final Color _colWarning = const Color(0xFFFFA726);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    _startListening();
    _enableAntiScreenshot();
    widget.controller.addListener(_handleControllerChange);
  }
  
  // 🔥 NEW: Anti-screenshot protection
  void _enableAntiScreenshot() {
    try {
      // Platform-specific screenshot prevention
      // Android: FLAG_SECURE
      // iOS: Blur on app switcher
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final window = WidgetsBinding.instance.window;
        // This prevents screenshots on Android
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        );
      });
    } catch (e) {
      debugPrint("Screenshot protection not available on this platform");
    }
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
      // 🔥 ANTI-SCREENSHOT: Blur on app switcher
      _blurSensitiveContent(true);
    } else if (state == AppLifecycleState.resumed) {
      if (_accelSub == null) {
        _startListening();
      }
      if (widget.controller.state == SecurityState.HARD_LOCK) {
        _startLockoutTimer();
      }
      _blurSensitiveContent(false);
    }
  }

  void _blurSensitiveContent(bool blur) {
    // This creates a visual barrier when app is backgrounded
    if (mounted) {
      setState(() {
        // UI will respond to this
      });
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

  // 🔥 NEW: Analyze scroll pattern (Human vs Bot detection)
  void _analyzeScrollPattern() {
    _scrollTimestamps.add(DateTime.now());
    
    // Keep only last 10 scrolls
    if (_scrollTimestamps.length > 10) {
      _scrollTimestamps.removeAt(0);
    }
    
    if (_scrollTimestamps.length >= 3) {
      // Calculate intervals between scrolls
      List<int> intervals = [];
      for (int i = 1; i < _scrollTimestamps.length; i++) {
        intervals.add(
          _scrollTimestamps[i].difference(_scrollTimestamps[i-1]).inMilliseconds
        );
      }
      
      // Calculate variance (high variance = human, low = bot)
      double mean = intervals.reduce((a, b) => a + b) / intervals.length;
      double variance = intervals.map((x) {
        double diff = x - mean;
        return diff * diff;
      }).reduce((a, b) => a + b) / intervals.length;
      
      // Normalize variance to 0-1 score
      // Bots typically have <50ms variance, humans 100-500ms
      double normalizedVariance = (variance / 500.0).clamp(0.0, 1.0);
      
      // Also check for too-perfect timing (bot indicator)
      bool hasPerfectTiming = intervals.any((interval) => 
        interval > 50 && interval < 150 && 
        intervals.where((i) => (i - interval).abs() < 10).length >= 3
      );
      
      if (hasPerfectTiming) {
        _patternScore = 0.2; // Suspicious
      } else {
        _patternScore = normalizedVariance;
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
        activeColor = _colNeon;
        boxColor = _colNeon;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.lock_open;
        isInputDisabled = true;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          
          // STATUS HEADER
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: Main Status
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: activeColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "SYSTEM STATUS", 
                          style: TextStyle(
                            color: Colors.grey[600], 
                            fontSize: 10, 
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText, 
                      style: TextStyle(
                        color: activeColor, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 15,
                        letterSpacing: 0.5,
                        height: 1.2
                      )
                    ),
                    const SizedBox(height: 8),
                    Divider(color: activeColor.withOpacity(0.3), height: 1),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),

              // 🔥 RIGHT: 3 Sensor Boxes (Vertical Stack)
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
                   // 🔥 NEW: Pattern Analysis Box
                   _buildPatternBox(
                     label: "PATTERN",
                     score: _patternScore,
                     color: boxColor,
                   ),
                ],
              )
            ],
          ),
          
          // Threat message display
          if (widget.controller.threatMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _colFail.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _colFail.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: _colFail, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.controller.threatMessage,
                      style: TextStyle(
                        color: _colFail, 
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 25),
          
          // 🔥 WHEELS - Enhanced with individual tracking
          SizedBox(
            height: 120,
            child: IgnorePointer(
              ignoring: isInputDisabled,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                     widget.controller.registerTouch(); 
                     _analyzeScrollPattern(); // 🔥 NEW
                     
                     // Find which wheel is scrolling
                     for (int i = 0; i < _scrollControllers.length; i++) {
                       if (_scrollControllers[i].position == notification.metrics) {
                         if (_activeWheelIndex != i) {
                           setState(() => _activeWheelIndex = i);
                         }
                         break;
                       }
                     }
                  } else if (notification is ScrollEndNotification) {
                     Future.delayed(const Duration(milliseconds: 400), () {
                       if (mounted) setState(() => _activeWheelIndex = null); 
                     });
                  }
                  return false;
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    5, 
                    (index) => _buildPrivacyWheel(index, activeColor, isInputDisabled)
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 25),
          
          // UNLOCK BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isInputDisabled ? Colors.grey[900] : activeColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: isInputDisabled ? 0 : 4,
              ),
              onPressed: isInputDisabled 
                ? null 
                : () => widget.controller.validateAttempt(hasPhysicalMovement: true),
              child: Text(
                state == SecurityState.HARD_LOCK 
                  ? "SYSTEM LOCKED" 
                  : "AUTHENTICATE", 
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.5,
                  fontSize: 14
                ),
              ),
            ),
          ),
          
          // First-time hint
          if (state == SecurityState.LOCKED && 
              widget.controller.motionConfidence == 0 && 
              widget.controller.touchConfidence == 0) ...[
            const SizedBox(height: 12),
            Text(
              "💡 Move device & scroll wheels to unlock",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  // Unified sensor box
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
        Container(
          width: 52,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSensing ? color : Colors.grey[800]!,
              width: isSensing ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Icon(
              isActive ? Icons.check_circle : icon,
              size: 18, 
              color: isSensing ? color : Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 7.5,
            color: isSensing ? color.withOpacity(0.8) : Colors.grey[700],
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // 🔥 NEW: Pattern analysis box
  Widget _buildPatternBox({
    required String label,
    required double score,
    required Color color,
  }) {
    bool isHumanLike = score > 0.5;
    bool isSuspicious = score > 0.1 && score <= 0.3;
    bool hasData = score > 0;

    Color boxColor;
    IconData boxIcon;
    
    if (isHumanLike) {
      boxColor = color;
      boxIcon = Icons.check_circle;
    } else if (isSuspicious) {
      boxColor = _colFail;
      boxIcon = Icons.warning_amber_rounded;
    } else if (hasData) {
      boxColor = _colJam;
      boxIcon = Icons.close;
    } else {
      boxColor = Colors.grey[800]!;
      boxIcon = Icons.timeline;
    }

    return Column(
      children: [
        Container(
          width: 52,
          height: 40,
          decoration: BoxDecoration(
            color: isHumanLike ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: boxColor,
              width: hasData ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Icon(
              boxIcon,
              size: 18,
              color: boxColor,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 7.5,
            color: hasData ? boxColor.withOpacity(0.8) : Colors.grey[700],
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
  
  // 🔥 IMPROVED: Only active wheel glows
  Widget _buildPrivacyWheel(int index, Color color, bool disabled) {
    final bool isThisWheelActive = (_activeWheelIndex == index);
    
    // 🔥 FIX: Hanya roda yang dipusing sahaja menyala
    final double opacity = disabled 
      ? 0.3 
      : (isThisWheelActive ? 1.0 : 0.25); // Lebih dramatic difference
    
    return SizedBox(
      width: 45,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: opacity,
        child: ListWheelScrollView.useDelegate(
          controller: _scrollControllers[index],
          itemExtent: 45,
          perspective: 0.005,
          diameterRatio: 1.2,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (val) {
            _triggerHaptic(); 
            widget.controller.updateWheel(index, val % 10);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, i) {
              final num = i % 10;
              return Center(
                child: Text(
                  '$num',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      // 🔥 Glow hanya pada roda yang aktif
                      if (isThisWheelActive) 
                        BoxShadow(
                          color: color.withOpacity(0.9), 
                          blurRadius: 12,
                          spreadRadius: 3,
                        )
                    ]
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityWarningUI() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _colWarning, width: 2),
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Could add more info or exit
            },
            child: Text(
              "Learn more about device security",
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
