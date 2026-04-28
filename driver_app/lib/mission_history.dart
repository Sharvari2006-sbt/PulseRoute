import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MissionCasesPage extends StatelessWidget {
  const MissionCasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Mission Cases")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('active_missions').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No missions found in database."));
          }

          // Robust Filtering: Check for 'pending' regardless of trailing spaces
          final pendingDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? '').toString().trim().toLowerCase();
            return status == 'pending';
          }).toList();

          // Sorting: Highest urgency on top
          pendingDocs.sort((a, b) {
            final aUrgency = (a.data() as Map<String, dynamic>)['urgency'] ?? 0;
            final bUrgency = (b.data() as Map<String, dynamic>)['urgency'] ?? 0;
            return bUrgency.compareTo(aUrgency);
          });

          if (pendingDocs.isEmpty) {
            return const Center(child: Text("No pending missions detected."));
          }

          return ListView.builder(
            itemCount: pendingDocs.length,
            itemBuilder: (context, index) {
              final data = pendingDocs[index].data() as Map<String, dynamic>;
              final urgency = data['urgency'] ?? 0;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white10,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: urgency > 7 ? Colors.redAccent : Colors.blueAccent,
                    child: Text("$urgency", style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(data['item'] ?? 'New Mission'),
                  subtitle: Text(data['context'] ?? 'No context provided'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              );
            },
          );
        },
      ),
    );
  }
}