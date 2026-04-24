import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mission Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark, // High contrast dark theme
        ),
        useMaterial3: true,
      ),
      home: const MissionDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MissionDashboard extends StatefulWidget {
  const MissionDashboard({super.key});

  @override
  State<MissionDashboard> createState() => _MissionDashboardState();
}

class _MissionDashboardState extends State<MissionDashboard> {
  // Coordinates for Kengeri, Bengaluru
  static const LatLng _kengeriLocation = LatLng(12.9069, 77.4855);
  static const LatLng _mockDriverLocation = LatLng(12.9120, 77.4800); // Mock Driver Location
  
  late GoogleMapController mapController;
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 2,
      ),
      body: Firebase.apps.isEmpty 
        ? const Center(
            child: Text(
              'Waiting for Perception...', 
              style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)
            )
          )
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('active_missions')
            .where('status', whereIn: ['pending', 'in_transit'])
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          
          bool hasPending = false;
          bool hasInTransit = false;
          QueryDocumentSnapshot? activeDoc;
          
          if (docs.isNotEmpty) {
            activeDoc = docs.first;
            if (activeDoc['status'] == 'pending') hasPending = true;
            if (activeDoc['status'] == 'in_transit') hasInTransit = true;
          }

          final Set<Polyline> dynamicPolylines = {};
          
          if (hasInTransit && activeDoc != null) {
            final mData = activeDoc.data() as Map<String, dynamic>;
            final double mLat = (mData['lat'] ?? _kengeriLocation.latitude).toDouble();
            final double mLng = (mData['lng'] ?? _kengeriLocation.longitude).toDouble();
            final detourLoc = LatLng(mLat, mLng);

            // Original route: Blue (A to B)
            dynamicPolylines.add(
              Polyline(
                polylineId: const PolylineId('original_route'),
                color: Colors.blue,
                width: 4,
                points: [_mockDriverLocation, _kengeriLocation],
              ),
            );

            // Detour route: Green (A to C to B)
            dynamicPolylines.add(
              Polyline(
                polylineId: const PolylineId('detour_route'),
                color: Colors.greenAccent[400] ?? Colors.green,
                width: 6,
                points: [_mockDriverLocation, detourLoc, _kengeriLocation],
              ),
            );
          }

          return Stack(
            children: [
              // 1. Placeholder for Map (Bypasses billing check)
              Container(
                color: Colors.black87,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 80, color: Colors.white24),
                      SizedBox(height: 16),
                      Text("Simulation Mode: Map Overlay Hidden", 
                           style: TextStyle(color: Colors.white24)),
                    ],
                  ),
                ),
              ),

              /* 
              // ORIGINAL GOOGLE MAP WIDGET
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: const CameraPosition(
                  target: _kengeriLocation,
                  zoom: 15.5,
                  tilt: 45.0, // 45-degree tilt for 3D buildings
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                buildingsEnabled: true, // Enable 3D city buildings
                polylines: dynamicPolylines,
              ),
              */
              
              // 2. Pending Mission Panel (This will now work!)
              if (hasPending && activeDoc != null)
                _buildPendingPanel(activeDoc, context),

              // 3. Resource Delivered Button
              if (hasInTransit && activeDoc != null)
                Positioned(
                  bottom: 40,
                  left: 24,
                  right: 24,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Mark as completed
                      await activeDoc!.reference.update({'status': 'completed'});
                      // Call Firebase function (simulated via Firestore transaction/update) to increment tokens
                      await FirebaseFirestore.instance.collection('drivers').doc('current_driver').set(
                        {'pulse_tokens': FieldValue.increment(50)}, 
                        SetOptions(merge: true)
                      );
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Resource Delivered! +50 Pulse Tokens!'),
                            backgroundColor: Colors.blueAccent,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'RESOURCE DELIVERED',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingPanel(QueryDocumentSnapshot missionDoc, BuildContext context) {
    final missionData = missionDoc.data() as Map<String, dynamic>;
    final String resourceType = missionData['item'] ?? 'Unknown Resource';
    final dynamic urgency = missionData['urgency'] ?? 0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, -5),
            )
          ]
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Incoming Mission',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent, width: 1.5),
                    ),
                    child: Text(
                      'URGENCY SCORE: $urgency',
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '📍 Location: Kengeri, Bengaluru\n📦 Type: $resourceType',
                style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              
              // High-Contrast 'Accept' Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    // Accept Mission Action
                    await missionDoc.reference.update({'status': 'in_transit'});
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mission Accepted! Routing...'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent[700], // Extremely high contrast green
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'ACCEPT MISSION',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
