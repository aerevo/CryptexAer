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
  
  // Privacy Shield
  int? _activeWheelIndex;
  Timer? _fadeTimer;
  
  late List<FixedExtentScrollController> _scrollControllers;
  
  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  
  // 🔧 ULTRA NEON CYAN COLOR SCHEME
  final Color _colLocked = const Color(0xFF00FFFF);
  final Color _colFail = const Color(0xFFFF6B6B);
  final Color _colJam = const Color(0xFFFF1744);
  final Color _colUnlock = const Color(0xFF00FF88);
  final Color _colDead = const Color(0xFF4A5568);
  final Color _colValidating = const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    _initAnimations();
    _startListening();
    
    widget.controller.addListener(_handleControllerChange);
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
    
    SecurityState newState = widget.controller.state;
    
    if (newState == SecurityState.UNLOCKED) {
      _triggerSuccessTik();
      widget.onSuccess();
    } else if (newState == SecurityState.HARD_LOCK) {
      _triggerCriticalTik();
      widget.onJammed();
    } else if (newState == SecurityState.SOFT_LOCK) {
      _triggerErrorTik();
      _triggerShakeAnimation();
      widget.onFail();
    }
    
    setState(() {});
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
      if (_accelSub == null) {
        _startListening();
      }
    }
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      // Pastikan method getInitialValue wujud dalam controller
      int startVal = 0;
      try {
         startVal = widget.controller.getInitialValue(index);
      } catch (e) {
         startVal = 0; // Fallback jika method tiada
      }
      return FixedExtentScrollController(initialItem: startVal);
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    // 🔧 FIX: Proper parameter order & Type safety
    _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent e) {
      double rawMag = e.x.abs() + e.y.abs() + e.z.abs();
      
      // ✅ CORRECT: Pass all 4 parameters to ensure Controller receives data
      widget.controller.registerShake(rawMag, e.x, e.y, e.z);
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

  // Quick "tik" haptic feedback
  void _triggerLightTik() {
    HapticFeedback.selectionClick();
  }
  
  void _triggerMediumTik() {
    HapticFeedback.lightImpact();
  }
  
  Future<void> _triggerSuccessTik() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.lightImpact();
  }
  
  Future<void> _triggerErrorTik() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    HapticFeedback.lightImpact();
  }
  
  Future<void> _triggerCriticalTik() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    HapticFeedback.heavyImpact();
  }

  void _activatePrivacyShield() {
    setState(() => _activeWheelIndex = 1);
    
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
          statusText = "BIOMETRIC ACTIVE";
          statusIcon = Icons.fingerprint;
          showPulse = true;
        } else {
          activeColor = _colDead;
          statusText = "STANDBY";
          statusIcon = Icons.sensors_off; 
        }
        break;
        
      case SecurityState.VALIDATING:
        activeColor = _colValidating;
        statusText = "ANALYZING...";
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
        statusText = "SYSTEM LOCKED • ${widget.controller.remainingLockoutSeconds}s";
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
            color: activeColor.withOpacity(0.4),
            blurRadius: 50,
            spreadRadius: 5,
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
                  "BIOMETRIC SIGNATURE",
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
                        return LinearGradient(
                          colors: [activeColor, activeColor],
                        ).createShader(bounds);
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
              label: "ENTROPY",
              value: "${(widget.controller.motionEntropy * 100).toInt()}",
              isGood: widget.controller.motionEntropy > 0.5,
              color: activeColor,
            ),
            Container(width: 1, height: 30, color: Colors.grey[800]),
            _buildModernMetric(
              icon: Icons.verified_user,
              label: "SCORE",
              value: "${(confidence * 100).toInt()}",
              isGood: confidence > 0.5,
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
      child: IgnorePointer(
        ignoring: disabled,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification || 
                notification is ScrollUpdateNotification) {
              _activatePrivacyShield();
              widget.controller.registerTouchInteraction();
            }
            return false;
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) => 
              _buildModernWheel(index, color, disabled)
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernWheel(int index, Color color, bool disabled) {
    final double opacity = (_activeWheelIndex != null) ? 1.0 : 0.15;
    final bool isActive = _activeWheelIndex != null;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isActive
              ? [color.withOpacity(0.2), color.withOpacity(0.05)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
        ),
        border: Border.all(
          color: isActive ? color.withOpacity(0.5) : Colors.grey[800]!,
          width: isActive ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
            ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 30, spreadRadius: 5)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: disabled ? 0.4 : 1.0,
          child: ListWheelScrollView.useDelegate(
            controller: _scrollControllers[index],
            itemExtent: 46,
            diameterRatio: 1.3,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (val) {
              _triggerLightTik();
              widget.controller.updateWheel(index, val % 10);
              _activatePrivacyShield();
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, i) {
                final num = i % 10;
                return Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: opacity,
                    child: Text(
                      '$num',
                      style: TextStyle(
                        color: disabled ? Colors.grey[700] : (isActive ? color : Colors.white70),
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        shadows: isActive
                            ? [
                                Shadow(color: color.withOpacity(1.0), blurRadius: 20),
                                Shadow(color: color.withOpacity(0.5), blurRadius: 40),
                              ]
                            : null,
                      ),
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

  Widget _buildModernButton(Color color, bool disabled, SecurityState state) {
    String label = state == SecurityState.HARD_LOCK 
        ? "SYSTEM LOCKED" 
        : state == SecurityState.VALIDATING
            ? "PROCESSING..."
            : "AUTHENTICATE";
    
    IconData icon = state == SecurityState.HARD_LOCK
        ? Icons.lock
        : state == SecurityState.VALIDATING
            ? Icons.hourglass_empty
            : Icons.fingerprint;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: disabled
            ? null
            : LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: disabled ? const Color(0xFF1E293B) : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: disabled ? Colors.grey[800]! : color.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: disabled
            ? null
            : [BoxShadow(color: color.withOpacity(0.5), blurRadius: 25, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  _triggerMediumTik();
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _colFail.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning, color: _colFail, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.controller.threatMessage,
              style: TextStyle(
                color: _colFail,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityWarningUI() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF450A0A), const Color(0xFF7F1D1D)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _colJam, width: 2),
        boxShadow: [BoxShadow(color: _colJam.withOpacity(0.3), blurRadius: 30, spreadRadius: 2)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            "SECURITY BREACH",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.controller.threatMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white60, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Device security compromised. Sensitive data may be exposed.",
                    style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _colJam,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 8,
              ),
              onPressed: () {
                _triggerCriticalTik();
                widget.controller.userAcceptsRisk();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "ACKNOWLEDGE RISK",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
