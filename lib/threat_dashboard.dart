import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math'; // Untuk nombor rawak

class ThreatDashboard extends StatelessWidget {
  const ThreatDashboard({super.key});

  // 💥 FUNGSI: Acah-acah Serang (Simulasi)
  void _simulateAttack() {
    final random = Random();
    final List<String> threats = [
      'Root Access Detected',
      'Brute Force Attack', 
      'Malware Signature',
      'Suspicious IP Location',
      'SQL Injection Attempt'
    ];

    // Hantar data palsu ke Cloud Firestore
    FirebaseFirestore.instance.collection('global_threat_intel').add({
      'device_id': 'SIMULATION-${1000 + random.nextInt(9000)}', // ID Palsu: SIMULATION-1234
      'threat_type': threats[random.nextInt(threats.length)], // Pilih jenis ancaman rawak
      'severity': 'HIGH',
      'timestamp': FieldValue.serverTimestamp(), // Masa sekarang
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Background gelap ala hacker
      appBar: AppBar(
        title: const Text("RADAR ANCAMAN LIVE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.redAccent.withOpacity(0.3), height: 1),
        ),
      ),
      
      // 📡 PAPARAN DATA LIVE
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('global_threat_intel')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 80, color: Colors.green.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  const Text("TIADA ANCAMAN DIKESAN", style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 10),
                  const Text("Tekan butang 🐞 untuk test serangan", style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(10),
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              
              bool isHighRisk = data['severity'] == 'HIGH';

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: isHighRisk ? Colors.red.withOpacity(0.5) : Colors.orange.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded, 
                    color: isHighRisk ? Colors.red : Colors.orange,
                    size: 30,
                  ),
                  title: Text(
                    data['threat_type'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "ID: ${data['device_id']}",
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                  trailing: Text(
                    isHighRisk ? 'CRITICAL' : 'WARNING',
                    style: TextStyle(
                      color: isHighRisk ? Colors.redAccent : Colors.orangeAccent, 
                      fontWeight: FontWeight.bold,
                      fontSize: 10
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),

      // 🐞 BUTANG MERAH (SIMULASI SERANGAN)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _simulateAttack,
        backgroundColor: Colors.red[900],
        icon: const Icon(Icons.bug_report, color: Colors.white),
        label: const Text("HANTAR SERANGAN PALSU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
