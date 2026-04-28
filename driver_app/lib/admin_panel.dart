import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _itemController = TextEditingController(text: "Clean Water Kit");
  final _contextController = TextEditingController(text: "Simulated leak near RVCE");
  double _urgency = 5.0; // Urgency slider value
  LatLng? _selectedLocation;
  bool _isDeployed = false;
 // Get current project ID

  Future<void> _deployMission() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a location on the map!")));
      return;
    }
    
    // Check which Firebase project is being used
    try {
      final projectId = Firebase.app().options.projectId;
      debugPrint('Using Firebase project: $projectId');
    } catch (e) {
      debugPrint('Could not get project ID: $e');
    }
    
    // Writing to Firestore
    try {
    DocumentReference docRef =await FirebaseFirestore.instance.collection('active_missions').add({
      'item': _itemController.text,
      'context': _contextController.text,
      'lat': _selectedLocation!.latitude,
      'lng': _selectedLocation!.longitude,
      'status': 'pending',
      'urgency': _urgency.toInt(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    debugPrint("SUCCESS: Doc ID ${docRef.id}"); // Check this in console!
    setState(() => _isDeployed = true);
  } catch (e) {
    debugPrint("FIREBASE ERROR: $e"); // CHECK THIS IN VS CODE CONSOLE
  }
    setState(() => _isDeployed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mission Controller")),
      body: _isDeployed 
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const Text("Mission successfully deployed to Firestore!"),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => setState(() => _isDeployed = false), child: const Text("Deploy Another Mission"))
          ]))
        : Column(children: [
            Expanded(child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: LatLng(12.923, 77.498), zoom: 14),
              onTap: (loc) => setState(() => _selectedLocation = loc),
              markers: _selectedLocation != null ? {Marker(markerId: const MarkerId('dest'), position: _selectedLocation!)} : {},
            )),
            Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              TextField(controller: _itemController, decoration: const InputDecoration(labelText: "Item Name")),
              TextField(controller: _contextController, decoration: const InputDecoration(labelText: "Mission Context")),
              const SizedBox(height: 10),
              const Text("Urgency Level"),
              Slider(value: _urgency, min: 1, max: 10, divisions: 9, label: _urgency.round().toString(), onChanged: (v) => setState(() => _urgency = v)),
              ElevatedButton(onPressed: _deployMission, child: const Text("DEPLOY MISSION")),
            ])),
          ]),
    );
  }
}