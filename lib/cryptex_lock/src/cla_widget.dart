import 'package:flutter/material.dart';

class CryptexLock extends StatelessWidget {
  final dynamic controller;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;
  final VoidCallback? onJammed;

  const CryptexLock({
    super.key,
    this.controller,
    this.onSuccess,
    this.onFail,
    this.onJammed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: double.infinity,
          // Decoration sikit utk nampak sempadan
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
            ),
          ),
          
          // 🔥 INI KONSEP OVERLAY (STACK) 🔥
          child: Stack(
            alignment: Alignment.center, // Pastikan semua benda duduk tengah
            children: [
              // ==============================
              // LAPISAN 1 (BAWAH): GAMBAR RODA
              // ==============================
              Image.asset(
                'assets/z_wheel.png',
                fit: BoxFit.fitWidth, // Ikut setting Captain yg dah lulus tadi
              ),

              // ==============================
              // LAPISAN 2 (ATAS): NOMBOR TEST
              // ==============================
              // Kita guna Positioned.fill supaya lapisan ni
              // ikut saiz sebiji macam gambar di belakang.
              Positioned.fill(
                child: Row(
                  // Bahagikan ruang kepada 5 bahagian sama rata
                  children: List.generate(5, (index) {
                    return Expanded(
                      child: Container(
                        // Hamba letak kotak merah nipis supaya Captain nampak kawasan dia
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
                        ),
                        child: Center(
                          child: Text(
                            "0", // Nombor Test
                            style: TextStyle(
                              fontSize: 40, // Besar sikit
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              // Letak shadow sikit supaya nampak timbul
                              shadows: [
                                Shadow(blurRadius: 2, color: Colors.black, offset: Offset(2, 2))
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
