// lib/cryptex_lock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk getaran (Haptic)
import 'package:sensors_plus/sensors_plus.dart'; // Untuk sensor graviti

class CryptexLockScreen extends StatefulWidget {
  const CryptexLockScreen({super.key});

  @override
  State<CryptexLockScreen> createState() => _CryptexLockScreenState();
}

class _CryptexLockScreenState extends State<CryptexLockScreen> {
  // --- KONFIGURASI 5 RODA & PERANGKAP ---
  
  // Senarai Pilihan (Termasuk 'KOSONG' sebagai Perangkap)
  final List<String> _lockItems = ['API', 'AIR', 'KILAT', 'TANAH', 'KOSONG', 'BAYANG'];
  
  // INDEX untuk item 'KOSONG' (Index ke-4 dlm senarai di atas)
  final int _emptyItemIndex = 4; 

  // Kunci Rahsia (5 Digit)
  // Contoh: Roda 3 (Index 2) WAJIB 'KOSONG'. Roda lain JANGAN pilih 'KOSONG'.
  // Susunan: [API, AIR, KOSONG, TANAH, KILAT]
  final List<int> _correctPattern = [0, 1, 4, 3, 2]; 
  
  // Variabel Pilihan Semasa (5 Roda)
  List<int> _currentSelections = [0, 0, 0, 0, 0];
  
  // Status Perangkap
  bool _isTrapTriggered = false;

  // --- LOGIK ANTI-BOT ---
  double _minTimeRequired = 1.5; // Masa minimum manusia
  double _gravityThreshold = 0.5; // Kekuatan goncangan minimum
  DateTime? _startTime;
  String _statusMessage = 'Susun 5 Elemen. Elak Zon KOSONG!';
  bool _isShaken = false; // Adakah telefon digerakkan?

  @override
  void initState() {
    super.initState();
    _startListeningToSensors();
  }

  void _startListeningToSensors() {
    // Memantau sensor graviti telefon
    accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (AccelerometerEvent event) {
        final double magnitude = event.x.abs() + event.y.abs() + event.z.abs();
        // Jika ada pergerakan, sahkan ini manusia
        if (magnitude > _gravityThreshold) {
          setState(() {
            _isShaken = true;
          });
        }
      },
    );
  }

  // --- LOGIK PERIUK API (TRAP LOGIC) ---
  void _onWheelChanged(int wheelIndex, int value) {
    if (_isTrapTriggered) return; // Kalau dah kena trap, jam terus.

    if (_startTime == null) {
      _startTime = DateTime.now(); // Mula kira masa bila sentuh roda pertama
    }

    // 1. SEMAKAN PERANGKAP SERTA-MERTA (REAL-TIME TRAP)
    // Jika pengguna pilih 'KOSONG' pada roda yang SALAH
    // (Iaitu roda yang sepatutnya BUKAN kosong)
    if (value == _emptyItemIndex && _correctPattern[wheelIndex] != _emptyItemIndex) {
      _triggerTrap();
      return;
    }

    setState(() {
      _currentSelections[wheelIndex] = value;
    });
    
    // Getaran ringan 'Klik' setiap kali pusing
    HapticFeedback.selectionClick();
  }

  void _triggerTrap() {
    setState(() {
      _isTrapTriggered = true;
      _statusMessage = 'AMARAN: PERANGKAP DISENTUH! (XXX TETT!)';
      // Kita biarkan roda tu tunjuk kosong supaya dia tahu dia salah
    });
    
    // Getaran Kuat & Panjang (Tanda Bahaya/Meletup)
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.heavyImpact());
  }

  void _resetLock() {
    setState(() {
      _isTrapTriggered = false;
      _statusMessage = 'Sila Cuba Lagi.';
      _startTime = null;
      _isShaken = false;
      _currentSelections = [0, 0, 0, 0, 0]; // Reset semua ke 0
    });
  }

  void _attemptUnlock() {
    // Kalau dah kena trap, tak boleh tekan unlock
    if (_isTrapTriggered) {
      setState(() => _statusMessage = 'SISTEM ROSAK. PERANGKAP AKTIF.');
      HapticFeedback.vibrate();
      return;
    }

    if (_startTime == null) return;
    final Duration duration = DateTime.now().difference(_startTime!);
    final double timeTaken = duration.inMilliseconds / 1000;
    _startTime = null;

    // 1. Semak Anti-Bot (Masa)
    if (timeTaken < _minTimeRequired) {
      setState(() => _statusMessage = 'DITOLAK: Terlalu Pantas (${timeTaken}s). Bot Dikesan.');
      return;
    }

    // 2. Semak Anti-Bot (Goncangan)
    if (!_isShaken) {
      setState(() => _statusMessage = 'DITOLAK: Tiada Goncangan Biometrik Dikesan.');
      return;
    }

    // 3. Semak Corak 5 Roda
    bool isCorrect = true;
    for (int i = 0; i < 5; i++) {
      if (_currentSelections[i] != _correctPattern[i]) {
        isCorrect = false;
        break;
      }
    }

    if (isCorrect) {
      setState(() => _statusMessage = 'AKSES DIBENARKAN. IDENTITI DISAHKAN.');
      HapticFeedback.mediumImpact();
    } else {
      setState(() => _statusMessage = 'Kombinasi Salah.');
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Jika kena trap, background jadi Merah Gelap
    return Scaffold(
      backgroundColor: _isTrapTriggered ? const Color(0xFF450000) : Colors.black, 
      appBar: AppBar(
        title: const Text('Cryptex Aer V2.0', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 20),
          child: Column(
            children: <Widget>[
              // Kotak Mesej Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isTrapTriggered ? Colors.red : (_statusMessage.contains('DIBENARKAN') ? Colors.green : Colors.blueAccent.withOpacity(0.3))
                  )
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isTrapTriggered ? Colors.redAccent : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier', // Font gaya hacker
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- 5 RODA UTAMA ---
              Container(
                height: 200, 
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF111111),
                  boxShadow: [
                     BoxShadow(
                       color: _isTrapTriggered ? Colors.red.withOpacity(0.2) : Colors.black, 
                       blurRadius: 15
                     )
                  ]
                ),
                // Row untuk susun 5 roda melintang
                child: Row(
                  children: List.generate(5, (index) {
                    return Expanded(child: _buildCryptexWheel(index));
                  }),
                ),
              ),
              
              const SizedBox(height: 30),

              // Butang Tindakan
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isTrapTriggered
                  ? ElevatedButton.icon( // Butang Reset bila kena trap
                      onPressed: _resetLock,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('RESET SISTEM', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
                    )
                  : ElevatedButton( // Butang Biasa
                      onPressed: _attemptUnlock,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      child: const Text('BUKA KUNCI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
              ),

              const SizedBox(height: 30),
              
              // --- BOT SIMULATOR (SLIDER) ---
              const Divider(color: Colors.white12),
              const Text('BOT SPEED SIMULATOR', style: TextStyle(color: Colors.orange, fontSize: 10, letterSpacing: 2)),
              Slider(
                min: 0.5, max: 3.0, divisions: 5,
                value: _minTimeRequired,
                onChanged: (val) => setState(() => _minTimeRequired = val),
                activeColor: Colors.redAccent,
                inactiveColor: Colors.white10,
              ),
              Text(
                'Min Masa Manusia: ${_minTimeRequired}s\n(Bot perlukan <0.1s)', 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const SizedBox(height: 10),
              Text(
                'Status Sensor Goncangan: ${_isShaken ? "[OK] MANUSIA" : "[X] STATIK (BOT)"}',
                style: TextStyle(color: _isShaken ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCryptexWheel(int index) {
    // Kunci roda kalau dah kena trap
    return AbsorbPointer(
      absorbing: _isTrapTriggered, 
      child: ListWheelScrollView.useDelegate(
        itemExtent: 45, // Jarak antara item
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (value) => _onWheelChanged(index, value),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            final itemText = _lockItems[i % _lockItems.length];
            // Highlight Merah jika item adalah KOSONG (Perangkap Visual)
            final isZero = itemText == 'KOSONG';
            
            return Center(
              child: Text(
                itemText,
                style: TextStyle(
                  // 'KOSONG' warna kelabu gelap, lain warna putih
                  color: isZero ? Colors.white24 : Colors.white,
                  fontSize: 12, // Saiz font
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
          childCount: _lockItems.length,
        ),
      ),
    );
  }
}