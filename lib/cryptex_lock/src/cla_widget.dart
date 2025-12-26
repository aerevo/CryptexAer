void _startListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      // Kira magnitud 3D
      final double magnitude = (e.x.abs() + e.y.abs() + e.z.abs()) / 3.0;
      
      // HANTAR DATA KE CONTROLLER UNTUK ANALISIS STATISTIK
      widget.controller.recordShakeSample(magnitude);
      
      if (mounted) {
        setState(() {
          _shakeSum += magnitude;
          _shakeCount++;
        });
      }
    });
  }

  void _attemptUnlock() {
    // ... (kod awal sama) ...

    // GANTI VALIDASI LAMA DENGAN ANALISIS BARU
    // Panggil validateHumanBehavior() bukannya validateShake()
    if (!widget.controller.validateSolveTime(elapsed) ||
        !widget.controller.validateHumanBehavior()) {
      
      // Gagal profil manusia -> JAM!
      widget.controller.jam();
      HapticFeedback.heavyImpact();
      widget.onJammed();
      return;
    }

    // ... (kod seterusnya sama) ...
