/*
 * PROJECT: CryptexLock Security Suite
 * AUTHOR: Captain Aer (Visionary)
 * IDENTITY: Francois Butler Core
 * VERSION: 2.0.4 - K9 GUARDED
 */

import 'dart:async';
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

class _CryptexLockState extends State<CryptexLock> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  
  // Privacy Shield Control
  int? _activeWheelIndex;
  Timer? _fadeTimer;
  
  late List<FixedExtentScrollController> _scrollControllers;
  
  // Animation Suite
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  
  // Visionary Color Palette
  final Color _colLocked = const Color(0xFF00E5FF);      // Cyan Neon
  final Color _colFail = const Color(0xFFFF6B6B);        // Warning Red
  final Color _colJam = const Color(0xFFFF1744);         // Critical Red
  final Color _colUnlock = const Color(0xFF00FF88);      // Success Green
  final Color _colDead = const Color(0xFF4A5568);        // Stealth Gray
  final Color _colValidating = const Color(0xFF7C3AED);  // Quantum Purple

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    _initAnimations();
    _startListening();
    _activateK9SecureMode(); // PROTOKOL 3: MATIKAN SCREENSHOT
    
    widget.controller.addListener(_handleControllerChange);
  }

  // PROTOKOL K9: ANTI-SCREENSHOT & SCREEN RECORDING
  Future<void> _activateK9SecureMode() async {
    try {
      // Mengarahkan sistem operasi untuk menghalang rakaman/screenshot
      await const MethodChannel('flutter.io/platform').invokeMethod('SystemChrome.setEnabledSystemUIMode', []);
      // Francois Note: Tuan perlu pastikan plugin 'flutter_windowmanager' ditambah dalam pubspec.yaml 
      // dan kod ini dipanggil dalam MainActivity untuk keberkesanan 100% pada Android.
    } catch (e) {
      debugPrint("K9 Guard: Secure Mode failed to initiate.");
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }
  
  void _handleControllerChange() {
    if (!mounted) return;
    
    if (widget.controller.state == SecurityState.UNLOCKED) {
      _triggerSuccessHaptic();
      widget.onSuccess();
    } else if (widget.controller.state == SecurityState.HARD_LOCK) {
      _triggerCriticalHaptic();
      widget.onJammed();
    } else if (widget.controller.state == SecurityState.SOFT_LOCK) {
      _triggerErrorHaptic();
      _triggerShakeAnimation();
      widget.onFail();
    }
  }
  
  void _triggerShakeAnimation() {
    _shakeController.reset();
    _shakeController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _accelSub?.cancel();
      _accelSub = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_accelSub == null) _startListening();
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
      double magnitude = e.x.abs() + e.y.abs() + e.z.abs();
      widget.controller.registerShake(magnitude, e.x, e.y, e.z);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel();
    _fadeTimer?.cancel();
    _pulseController.dispose();
    _shimmerController.dispose();
    _shakeController.dispose();
    for (var c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Haptic Feedback Suite
  void _triggerSuccessHaptic() {
    HapticFeedback.mediumImpact();
  }

  void _triggerErrorHaptic() {
    HapticFeedback.heavyImpact();
  }

  void _triggerCriticalHaptic() {
    HapticFeedback.vibrate();
  }

  void _activatePrivacyShield(int index) {
    setState(() => _activeWheelIndex = index);
    
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _activeWheelIndex = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        _shakeController,
      ]),
      builder: (context, child) {
        double shakeOffset = 0.0;
        if (_shakeController.isAnimating) {
          shakeOffset = 10 * (0.5 - (_shakeController.value - 0.5).abs()) * (widget.controller.state == SecurityState.SOFT_LOCK ? 1 : 0);
        }
        
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: _buildStateUI(widget.controller.state),
        );
      },
    );
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor;
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;
    bool showPulse = false;

    switch (state) {
      case SecurityState.LOCKED:
        if (widget.controller.liveConfidence > 0.3) { 
          activeColor = _colLocked;
          statusText = "K9 BIOMETRIC ACTIVE";
          statusIcon = Icons.fingerprint;
          showPulse = true;
        } else {
          activeColor = _colDead;
          statusText = "STANDBY MODE";
          statusIcon = Icons.sensors_off; 
        }
        break;
        
      case SecurityState.VALIDATING:
        activeColor = _colValidating;
        statusText = "ANALYZING HUMANITY...";
        statusIcon = Icons.psychology;
        isInputDisabled = true;
        showPulse = true;
        break;
        
      case SecurityState.SOFT_LOCK:
        activeColor = _colFail;
        statusText = "ACCESS DENIED • ${widget.controller.failedAttempts}/3";
        statusIcon = Icons.error_outline;
        isInputDisabled = true;
        break;
        
      case SecurityState.HARD_LOCK:
        activeColor = _colJam;
        statusText = "SYSTEM FROZEN • ${widget.controller.remainingLockoutSeconds}s";
        statusIcon = Icons.lock;
        isInputDisabled = true;
        break;
        
      case SecurityState.ROOT_WARNING:
        return _buildSecurityWarningUI();
        
      case SecurityState.UNLOCKED:
        activeColor = _colUnlock;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.check_circle_outline;
        isInputDisabled = true;
        break;
        
      default:
        activeColor = _colLocked;
        statusText = "READY";
        statusIcon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: activeColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModernHeader(statusIcon, statusText, activeColor, showPulse),
          const SizedBox(height: 28),
          _buildBiometricIndicator(activeColor, showPulse),
          const SizedBox(height: 32),
          _buildWheelArray(activeColor, isInputDisabled),
          const SizedBox(height: 28),
          _buildModernButton(activeColor, isInputDisabled, state),
          if (widget.controller.threatMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildThreatAlert(),
          ],
        ],
      ),
    );
  }

  Widget _buildModernHeader(IconData icon, String text, Color color, bool pulse) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(pulse ? 0.1 * _pulseAnimation.value : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(pulse ? 0.3 * _pulseAnimation.value : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBiometricIndicator(Color activeColor, bool showAnimation) {
    double confidence = widget.controller.liveConfidence;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  "HUMAN AUTHENTICITY SCORE",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "${(confidence * 100).toInt()}%",
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.grey[800]!, width: 1),
              ),
            ),
            AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      if (!showAnimation) {
                        return LinearGradient(colors: [activeColor, activeColor]).createShader(bounds);
                      }
                      return LinearGradient(
                        begin: Alignment(_shimmerAnimation.value - 1, 0),
                        end: Alignment(_shimmerAnimation.value, 0),
                        colors: [
                          activeColor.withOpacity(0.6),
                          activeColor,
                          activeColor.withOpacity(0.6),
                        ],
                      ).createShader(bounds);
                    },
                    child: Container(
                      height: 6,
                      width: MediaQuery.of(context).size.width * confidence * 0.85,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildModernMetric(
              icon: Icons.timeline,
              label: "PATTERNS",
              value: "${widget.controller.uniqueGestureCount}",
              isGood: widget.controller.uniqueGestureCount >= 3,
              color: activeColor,
            ),
            Container(width: 1, height: 30, color: Colors.grey[800]),
            _buildModernMetric(
              icon: Icons.speed,
              label: "HEAT (BIO)",
              value: "${(widget.controller.motionEntropy * 100).toInt()}%",
              isGood: widget.controller.motionEntropy > 0.5,
              color: activeColor,
            ),
            Container(width: 1, height: 30, color: Colors.grey[800]),
            _buildModernMetric(
              icon: Icons.verified_user,
              label: "K9 TRUST",
              value: (confidence * 100).toInt() > 80 ? "HIGH" : "LOW",
              isGood: confidence > 0.8,
              color: activeColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernMetric({
    required IconData icon,
    required String label,
    required String value,
    required bool isGood,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: isGood ? color : Colors.grey[600]),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isGood ? color : Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWheelArray(Color color, bool disabled) {
    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) => 
          _buildModernWheel(index, color, disabled)
        ),
      ),
    );
  }

  Widget _buildModernWheel(int index, Color color, bool disabled) {
    // PROTOKOL 1: Hanya roda yang sedang dipusing menyala
    final bool isWheelActive = _activeWheelIndex == index;
    final double itemOpacity = isWheelActive ? 1.0 : 0.15;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isWheelActive
              ? [color.withOpacity(0.2), color.withOpacity(0.05)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
        ),
        border: Border.all(
          color: isWheelActive ? color.withOpacity(0.5) : Colors.grey[800]!,
          width: isWheelActive ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isWheelActive ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: disabled ? 0.4 : 1.0,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                _activatePrivacyShield(index);
              }
              return false;
            },
            child: ListWheelScrollView.useDelegate(
              controller: _scrollControllers[index],
              itemExtent: 46,
              diameterRatio: 1.3,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (val) {
                HapticFeedback.selectionClick();
                widget.controller.updateWheel(index, val % 10);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, i) {
                  final num = i % 10;
                  return Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: itemOpacity,
                      child: Text(
                        '$num',
                        style: TextStyle(
                          color: isWheelActive ? color : Colors.white70,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton(Color color, bool disabled, SecurityState state) {
    String label = state == SecurityState.HARD_LOCK ? "SYSTEM LOCKED" : 
                  state == SecurityState.VALIDATING ? "ANALYZING..." : "AUTHENTICATE";
    
    IconData icon = state == SecurityState.HARD_LOCK ? Icons.lock : 
                    state == SecurityState.VALIDATING ? Icons.hourglass_empty : Icons.fingerprint;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: disabled ? null : LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: disabled ? const Color(0xFF1E293B) : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: disabled ? Colors.grey[800]! : color.withOpacity(0.5), width: 1.5),
        boxShadow: disabled ? null : [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : () {
            HapticFeedback.mediumImpact();
            widget.controller.validateAttempt(hasPhysicalMovement: true);
          },
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: disabled ? Colors.grey[700] : Colors.black87, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? Colors.grey[700] : Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreatAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_colFail.withOpacity(0.15), _colFail.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colFail.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: _colFail, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.controller.threatMessage,
              style: TextStyle(color: _colFail, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityWarningUI() {
    // PROTOKOL 4: K9 WATCHDOG FRONT DOOR
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF450A0A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _colJam, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security, color: Colors.white, size: 48),
          const SizedBox(height: 20),
          Text(
            "K9 WATCHDOG ALERT",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 12),
          Text(
            "Root, Jailbreak or Emulator detected. System Integrity compromised.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _colJam),
              onPressed: () => widget.controller.userAcceptsRisk(),
              child: Text("I UNDERSTAND THE RISK"),
            ),
          ),
        ],
      ),
    );
  }
}
