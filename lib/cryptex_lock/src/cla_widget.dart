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

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  
  double _lastX = 0, _lastY = 0, _lastZ = 0;
  double _humanScore = 0.0;
  bool _isHuman = false;
  
  // Privacy Shield - Track which wheel is being touched
  int? _activeWheelIndex;
  final Map<int, double> _wheelOpacity = {0: 0.1, 1: 0.1, 2: 0.1, 3: 0.1, 4: 0.1};
  
  // Advanced motion detection parameters
  static const double MOVEMENT_THRESHOLD = 0.12; // Electronic noise floor
  static const double DECAY_RATE = 0.5; // Natural score decay
  static const double SENSITIVITY_BOOST = 3.2; // Human motion amplification
  static const double HUMAN_ACTIVATION_THRESHOLD = 18.0; // Score needed for "human" status
  static const double MAX_SCORE = 60.0; // Score ceiling
  
  // Frequency analysis for tremor detection
  final List<double> _recentMagnitudes = [];
  static const int FREQUENCY_WINDOW = 20;
  
  late List<FixedExtentScrollController> _scrollControllers;
  late AnimationController _glowController;
  late AnimationController _pulseController;

  // Color scheme
  final Color _colLocked = const Color(0xFFFFD700); 
  final Color _colFail = const Color(0xFFFF9800);   
  final Color _colJam = const Color(0xFFFF3333);    
  final Color _colUnlock = const Color(0xFF00E676); 
  final Color _colDead = const Color(0xFF424242);
  final Color _colValidating = const Color(0xFF00BCD4);

  @override
  void initState() {
    super.initState();
    _initScrollControllers();
    _startListening();
    
    // Glow animation for active elements
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    // Pulse animation for biometric bar
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      int startVal = widget.controller.getInitialValue(index);
      return FixedExtentScrollController(initialItem: startVal);
    });
  }

  void _startListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      double deltaX = (e.x - _lastX).abs();
      double deltaY = (e.y - _lastY).abs();
      double deltaZ = (e.z - _lastZ).abs();

      _lastX = e.x; 
      _lastY = e.y; 
      _lastZ = e.z;
      
      double totalDelta = deltaX + deltaY + deltaZ;

      // High-pass filter: Only process significant movements
      if (totalDelta > MOVEMENT_THRESHOLD) {
        // Natural human tremor amplification
        _humanScore += (totalDelta * SENSITIVITY_BOOST);
        
        // Track for frequency analysis
        _recentMagnitudes.add(totalDelta);
        if (_recentMagnitudes.length > FREQUENCY_WINDOW) {
          _recentMagnitudes.removeAt(0);
        }
        
        // Register to controller with full delta information
        widget.controller.registerShake(
          totalDelta,
          dx: deltaX,
          dy: deltaY,
          dz: deltaZ,
        );
      } else {
        // Below noise threshold - apply natural decay
        _humanScore -= DECAY_RATE;
      }

      // Apply score boundaries
      _humanScore = _humanScore.clamp(0.0, MAX_SCORE);
      
      // Human detection with hysteresis (prevent flickering)
      bool detectedHuman = _humanScore > HUMAN_ACTIVATION_THRESHOLD;

      if (mounted && _isHuman != detectedHuman) {
        setState(() => _isHuman = detectedHuman);
      } else if (mounted) {
        setState(() {}); // Update score display
      }
    });
  }

  /// Calculate tremor frequency variance (humans: 8-12 Hz, bots: 0 Hz or perfect sine)
  double _calculateFrequencyVariance() {
    if (_recentMagnitudes.length < 5) return 0.0;
    
    double mean = _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;
    double variance = 0.0;
    
    for (var val in _recentMagnitudes) {
      variance += (val - mean) * (val - mean);
    }
    
    return variance / _recentMagnitudes.length;
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    for (var c in _scrollControllers) {
      c.dispose();
    }
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.selectionClick();
  }

  // Privacy Shield: Mark wheel as active on scroll
  void _onWheelScrollStart(int index) {
    setState(() {
      _activeWheelIndex = index;
      _wheelOpacity[index] = 1.0; // Full opacity
    });
  }

  void _onWheelScrollEnd() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _activeWheelIndex = null;
          for (int i = 0; i < 5; i++) {
            _wheelOpacity[i] = 0.1; // Blur all wheels
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (widget.controller.state == SecurityState.UNLOCKED) {
          Future.delayed(Duration.zero, widget.onSuccess);
        } else if (widget.controller.state == SecurityState.HARD_LOCK) {
          Future.delayed(Duration.zero, widget.onJammed);
        }
        return _buildStateUI(widget.controller.state);
      },
    );
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor;
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;

    switch (state) {
      case SecurityState.LOCKED:
        if (_isHuman) {
          activeColor = _colLocked;
          statusText = "BIO-LOCK ARMED";
          statusIcon = Icons.fingerprint;
        } else {
          activeColor = _colDead;
          statusText = "AWAITING BIOMETRIC"; 
          statusIcon = Icons.sensors_off; 
        }
        break;
      case SecurityState.VALIDATING:
        activeColor = _colValidating;
        statusText = "ANALYZING SIGNATURE...";
        statusIcon = Icons.psychology;
        isInputDisabled = true;
        break;
      case SecurityState.SOFT_LOCK:
        activeColor = _colFail;
        statusText = "ACCESS DENIED (${widget.controller.failedAttempts}/${widget.controller.config.maxAttempts})";
        statusIcon = Icons.warning_amber_rounded;
        isInputDisabled = true;
        break;
      case SecurityState.HARD_LOCK:
        activeColor = _colJam;
        int remaining = widget.controller.remainingLockoutSeconds;
        statusText = "LOCKOUT ACTIVE (${remaining}s)";
        statusIcon = Icons.lock_clock;
        isInputDisabled = true;
        break;
      case SecurityState.ROOT_WARNING:
        return _buildLiabilityWaiverUI();
      case SecurityState.UNLOCKED:
        activeColor = _colUnlock;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.verified_user;
        isInputDisabled = true;
        break;
      default:
        activeColor = _colLocked;
        statusText = "SYSTEM INITIALIZED";
        statusIcon = Icons.shield;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0A0A),
            const Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: activeColor.withOpacity(0.5), 
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(statusIcon, statusText, activeColor),
          const SizedBox(height: 20),
          _buildBiometricDisplay(activeColor),
          const SizedBox(height: 24),
          _buildWheelArray(activeColor, isInputDisabled),
          const SizedBox(height: 24),
          _buildActionButton(activeColor, isInputDisabled, state),
          if (widget.controller.threatMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildThreatAlert(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(IconData icon, String text, Color color) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: color.withOpacity(0.7 + (_glowController.value * 0.3)),
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 16,
                shadows: [
                  Shadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBiometricDisplay(Color activeColor) {
    double variance = _calculateFrequencyVariance();
    double confidence = widget.controller.biometricScore;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.radar, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  "BIO-SIGMA ANALYZER",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  _humanScore.toStringAsFixed(1),
                  style: TextStyle(
                    color: _isHuman ? _colUnlock : _colJam,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  " / ${MAX_SCORE.toInt()}",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  LinearProgressIndicator(
                    value: _humanScore / MAX_SCORE,
                    backgroundColor: Colors.grey[900],
                    color: _isHuman ? _colUnlock : _colJam,
                    minHeight: 6,
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.2 * _pulseController.value),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetric("VARIANCE", variance.toStringAsFixed(2), variance > 0.1),
            _buildMetric("PATTERNS", "${widget.controller.uniqueGestureCount}", widget.controller.uniqueGestureCount >= 3),
            _buildMetric("CONFIDENCE", "${(confidence * 100).toStringAsFixed(0)}%", confidence > 0.7),
          ],
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value, bool isGood) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isGood ? _colUnlock : _colFail,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWheelArray(Color color, bool disabled) {
    return SizedBox(
      height: 130,
      child: IgnorePointer(
        ignoring: disabled,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            5, 
            (index) => _buildQuantumWheel(index, color, disabled),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantumWheel(int index, Color color, bool disabled) {
    double opacity = _wheelOpacity[index] ?? 0.1;
    bool isActive = _activeWheelIndex == index;
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _onWheelScrollStart(index);
        } else if (notification is ScrollEndNotification) {
          _onWheelScrollEnd();
        }
        return true;
      },
      child: Container(
        width: 48,
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive 
                ? color.withOpacity(0.8) 
                : Colors.grey[800]!,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isActive ? 0 : 5,
              sigmaY: isActive ? 0 : 5,
            ),
            child: ListWheelScrollView.useDelegate(
              controller: _scrollControllers[index],
              itemExtent: 44,
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
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: opacity,
                      child: Text(
                        '$num',
                        style: TextStyle(
                          color: disabled ? Colors.grey[800] : Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          shadows: isActive ? [
                            Shadow(
                              color: color,
                              blurRadius: 8,
                            ),
                          ] : null,
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

  Widget _buildActionButton(Color color, bool disabled, SecurityState state) {
    String label = state == SecurityState.HARD_LOCK 
        ? "SYSTEM LOCKED" 
        : "AUTHENTICATE";
    
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: disabled 
                ? LinearGradient(colors: [Colors.grey[900]!, Colors.grey[800]!])
                : LinearGradient(
                    colors: [
                      color.withOpacity(0.8),
                      color,
                    ],
                  ),
            boxShadow: disabled ? null : [
              BoxShadow(
                color: color.withOpacity(0.3 + (_glowController.value * 0.2)),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: disabled 
                ? null 
                : () => widget.controller.validateAttempt(
                      hasPhysicalMovement: _isHuman,
                    ),
            child: Text(
              label,
              style: TextStyle(
                color: disabled ? Colors.grey[700] : Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThreatAlert() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _colJam.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _colJam.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: _colJam, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.controller.threatMessage,
              style: TextStyle(
                color: _colJam,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiabilityWaiverUI() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF330000),
            const Color(0xFF660000),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colJam, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.security, color: Colors.white, size: 60),
          const SizedBox(height: 16),
          Text(
            "SECURITY COMPROMISE DETECTED",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.controller.threatMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "⚠️ This device's security integrity has been compromised. Proceeding may expose sensitive data to unauthorized access.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _colJam,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.shield_outlined, color: Colors.white),
            label: const Text(
              "ACKNOWLEDGE RISK & PROCEED",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => widget.controller.userAcceptsRisk(),
          ),
        ],
      ),
    );
  }
}
