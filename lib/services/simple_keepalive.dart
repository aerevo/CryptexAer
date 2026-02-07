import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;

class SimpleKeepAlive {
  Timer? _keepAliveTimer;
  int? _mySlot;
  
  // ⚠️ PENTING: Tukar URL ni bila dah deploy ke Render nanti
  // Buat masa ni biarkan begini atau letak URL dummy
  final String _serverUrl = 'https://z-kinetic.onrender.com';
  
  // Initialize keep-alive system
  void initialize() {
    // 1. Tentukan slot (0-9) secara rawak
    // Ini memastikan setiap user ping pada minit berbeza
    _mySlot = Random().nextInt(10);
    
    print('📡 Keep-alive System: START');
    print('🎰 My Slot: $_mySlot (Akan ping server bila minit berakhir dengan $_mySlot)');
    
    // 2. Mula checking setiap 1 minit
    // Timer check setiap minit, tapi HANYA ping kalau kena dengan slot
    _keepAliveTimer = Timer.periodic(
      const Duration(minutes: 1), 
      (timer) => _checkAndPing(),
    );
  }
  
  // Check masa & Slot
  Future<void> _checkAndPing() async {
    final now = DateTime.now();
    final minute = now.minute;
    
    // Logik Slot:
    // Contoh: Kalau slot Captain = 3.
    // Dia akan ping pada minit: 03, 13, 23, 33, 43, 53.
    // (Setiap 10 minit)
    
    if (minute % 10 == _mySlot) {
      print('🔔 Ding Dong! Minit $minute - Giliran Slot $_mySlot untuk Ping!');
      await _pingServer();
    }
  }
  
  // Tembak Server
  Future<void> _pingServer() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/health'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ Server Render: HIDUP (Response 200 OK)');
      }
    } catch (e) {
      // Error biasa kalau server tengah tidur atau tiada internet
      // Kita senyapkan supaya tak ganggu log console
    }
  }
  
  // Matikan sistem (jimat bateri bila app tutup)
  void dispose() {
    _keepAliveTimer?.cancel();
    print('🛑 Keep-alive System: STOP');
  }
}
