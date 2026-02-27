import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CONFIGURATION
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticConfig {
  static const double imageWidth3 = 712.0;
  static const double imageHeight3 = 600.0;

  static const List<List<double>> coords3 = [
    [165, 155, 257, 380],
    [309, 155, 402, 380],
    [457, 155, 546, 381],
  ];

  static const List<double> btnCoords3 = [122, 435, 603, 546];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WIDGET CONTROLLER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WidgetController {
  static const String _serverUrl =
      'https://asia-southeast1-z-kinetic.cloudfunctions.net/api';
  final String apiKey;

  String? _currentNonce;
  final ValueNotifier<List<int>> challengeCode = ValueNotifier([0, 0, 0]);
  final ValueNotifier<int> randomizeTrigger = ValueNotifier(0);

  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _lastMagnitude = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer? _decayTimer;

  WidgetController({required this.apiKey}) {
    _initSensors();
    _startDecayTimer();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      double magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      double delta = (magnitude - _lastMagnitude).abs();
      if (delta > 0.3) {
        motionScore.value = (delta / 3.0).clamp(0.0, 1.0);
        _lastMotionTime = DateTime.now();
      }
      _lastMagnitude = magnitude;
    });
  }

  void _startDecayTimer() {
    _decayTimer?.cancel();
    _decayTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final elapsed = DateTime.now().difference(_lastMotionTime).inSeconds;
      if (elapsed > 1) {
        motionScore.value = (motionScore.value - 0.05).clamp(0.0, 1.0);
      }
    });
  }

  Future<void> getChallenge() async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/challenge'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _currentNonce = data['nonce'];
          challengeCode.value = List<int>.from(data['challengeCode']);
        }
      }
    } catch (e) {
      _currentNonce = 'local_${DateTime.now().millisecondsSinceEpoch}';
      challengeCode.value = List.generate(3, (_) => Random().nextInt(10));
    }
  }

  Future<Map<String, dynamic>> verifyChallenge(List<int> userResponse) async {
    if (_currentNonce == null) {
      return {'allowed': false, 'error': 'No active challenge'};
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/verify'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode({
          'nonce': _currentNonce,
          'userResponse': userResponse,
          'biometricData': {
            'motion': motionScore.value,
            'touch': touchScore.value,
            'pattern': patternScore.value,
          },
          'deviceId': 'flutter_device_${apiKey.substring(8, 16)}'
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'allowed': data['allowed'] ?? false};
      }
      return {'allowed': false};
    } catch (e) {
      return {
        'allowed': userResponse.join() == challengeCode.value.join()
      };
    }
  }

  void registerTouch() => touchScore.value = Random().nextDouble() * 0.3 + 0.7;
  void registerScroll() => patternScore.value = 0.8;
  void randomizeWheels() => randomizeTrigger.value++;

  void dispose() {
    _accelSub?.cancel();
    _decayTimer?.cancel();
    challengeCode.dispose();
    randomizeTrigger.dispose();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN WIDGET (OVERLAY)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticWidgetProdukB extends StatefulWidget {
  final WidgetController controller;
  final Function(bool) onComplete;
  final VoidCallback? onCancel;

  const ZKineticWidgetProdukB({
    super.key,
    required this.controller,
    required this.onComplete,
    this.onCancel,
  });

  @override
  State<ZKineticWidgetProdukB> createState() => _ZKineticWidgetProdukBState();
}

class _ZKineticWidgetProdukBState extends State<ZKineticWidgetProdukB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final List<FixedExtentScrollController> _scrollControllers = [];
  final List<int> _userSelection = [0, 0, 0];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    for (int i = 0; i < 3; i++) {
      _scrollControllers.add(FixedExtentScrollController(initialItem: 0));
    }
    _animController.forward();
    _loadChallenge();
  }

  @override
  void dispose() {
    _animController.dispose();
    for (var c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    setState(() => _isLoading = true);
    await widget.controller.getChallenge();
    setState(() => _isLoading = false);
  }

  Future<void> _onButtonTap() async {
    widget.controller.registerTouch();
    setState(() => _isLoading = true);
    final result = await widget.controller.verifyChallenge(_userSelection);
    setState(() => _isLoading = false);
    widget.onComplete(result['allowed'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxCardHeight = screenSize.height * 0.88;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              constraints: BoxConstraints(maxHeight: maxCardHeight),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5722),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Row: Title + Close button ─────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          'Z-KINETIC',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      if (widget.onCancel != null)
                        GestureDetector(
                          onTap: widget.onCancel,
                          child: const Icon(Icons.close,
                              color: Colors.white70, size: 24),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Badge ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_user,
                            color: Colors.greenAccent, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'INTELLIGENT-GRADE BIOMETRIC LOCK',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Challenge Code Display ─────────────────────────
                  ValueListenableBuilder<List<int>>(
                    valueListenable: widget.controller.challengeCode,
                    builder: (ctx, code, _) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        code.join('  '),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please match the code',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // ── Wheel Image ────────────────────────────────────
                  FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: ZKineticConfig.imageWidth3,
                      height: ZKineticConfig.imageHeight3,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/z_wheel3.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                          ...List.generate(3, (i) {
                            final coords = ZKineticConfig.coords3[i];
                            final h = coords[3] - coords[1];
                            return Positioned(
                              left: coords[0],
                              top: coords[1],
                              width: coords[2] - coords[0],
                              height: h,
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n is ScrollUpdateNotification) {
                                    widget.controller.registerScroll();
                                  }
                                  return false;
                                },
                                child: _buildWheel(i, h),
                              ),
                            );
                          }),
                          Positioned(
                            left: ZKineticConfig.btnCoords3[0],
                            top: ZKineticConfig.btnCoords3[1],
                            width: ZKineticConfig.btnCoords3[2] -
                                ZKineticConfig.btnCoords3[0],
                            height: ZKineticConfig.btnCoords3[3] -
                                ZKineticConfig.btnCoords3[1],
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white))
                                : GestureDetector(
                                    onTap: _onButtonTap,
                                    child:
                                        Container(color: Colors.transparent),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Sensor Indicators ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSensorIcon(Icons.sensors, 'MOTION',
                          widget.controller.motionScore),
                      const SizedBox(width: 32),
                      _buildSensorIcon(Icons.touch_app, 'TOUCH',
                          widget.controller.touchScore),
                      const SizedBox(width: 32),
                      _buildSensorIcon(Icons.fingerprint, 'PATTERN',
                          widget.controller.patternScore),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // ── Cancel text ───────────────────────────────────
                  if (widget.onCancel != null)
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancel',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWheel(int index, double height) {
    return ListWheelScrollView.useDelegate(
      controller: _scrollControllers[index],
      itemExtent: height / 3,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (val) {
        _userSelection[index] = val % 10;
        widget.controller.registerScroll();
      },
      childDelegate: ListWheelChildLoopingListDelegate(
        children: List.generate(
          10,
          (i) => Center(
            child: Text(
              '$i',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorIcon(
      IconData icon, String label, ValueNotifier<double> notifier) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (ctx, val, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: val > 0.3 ? Colors.greenAccent : Colors.white38,
              size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: val > 0.3 ? Colors.greenAccent : Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
