import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ThreatDashboard extends StatelessWidget {
  const ThreatDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Z-Kinetic Threat Radar"),
        backgroundColor: Colors.black87,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 📡 Arahan: Ambil data dari folder 'global_threat_intel' di Cloud
        stream: FirebaseFirestore.instance
            .collection('global_threat_intel')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Tiada ancaman dikesan buat masa ini."));
          }

          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              
              // Pilih warna ikut tahap bahaya
              Color severityColor = data['severity'] == 'HIGH' ? Colors.red : Colors.orange;

              return ListTile(
                leading: Icon(Icons.security_update_warning, color: severityColor),
                title: Text(
                  data['threat_type'] ?? 'Unknown Threat',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Device ID: ${data['device_id']}"),
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    data['severity'] ?? 'LOW',
                    style: TextStyle(color: severityColor, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
