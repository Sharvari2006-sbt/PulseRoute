import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'dart:ui'; // Required for ImageFilter (Glassmorphism)
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'admin_panel.dart';
import 'mission_history.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
 
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse Route Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      // --- NEW ROUTING LOGIC ---
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/admin') {
          return MaterialPageRoute(builder: (context) => const AdminPanel());
        }
        // Default route is the Driver Dashboard
        return MaterialPageRoute(builder: (context) => const MissionDashboard());
      },
      // -------------------------
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
  Timer? _locationTimer;
  Timer? _simulationTimer;
  LatLng driverPosition = const LatLng(12.9069, 77.4855); 
  Set<Polyline> _polylines = {};
  final bool _isMissionAccepted = false; 
  
  // FIX: Mission ID Locking to prevent State-Jumps 
  String? _activeMissionId; 

  // Route simulation
  List<LatLng> _routePoints = [];  // Full route from Directions API
  int _currentRouteIndex = 0;
  static const int _simulationDurationSeconds = 10;

  static const String _key = dotenv.env['MAPS_API_KEY'] ?? "";
  final PolylinePoints _polylinePoints = PolylinePoints();  // No apiKey in constructor
  Future<void> _drawRouteToMission({required LatLng start, required LatLng destination}) async {
  setState(() {
    _polylines.add(
      Polyline(
        polylineId: PolylineId("route_${DateTime.now().millisecondsSinceEpoch}"),
        // CHANGE THIS: Use the [start, destination] list directly
        points: [start, destination], 
        color: Colors.blueAccent,
        width: 10,
        zIndex: 100,
      ),
    );
  });
}

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStart();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }

  Future<void> getDirections(LatLng destination) async {
  try {
    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(driverPosition.latitude, driverPosition.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      ),
      googleApiKey: _key,  // API key goes here as separate param
    );

    if (result.points.isNotEmpty && mounted) {
      // Store route points for simulation
      _routePoints = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
      _currentRouteIndex = 0;
      
      setState(() {
        _polylines = {
          Polyline(
            polylineId: PolylineId("api_${DateTime.now().millisecondsSinceEpoch}"),
            // CHANGE THIS: Use the mapped points from the result
            points: _routePoints,
            color: Colors.blueAccent,
            width: 10,
            zIndex: 100,
          ),
        };
      });
      
      debugPrint('Route received with ${_routePoints.length} points');
      debugPrint('Starting simulation for $_simulationDurationSeconds seconds');
      
      // Start driver simulation along the route
      _startRouteSimulation();
    }
  } catch (e) {
    debugPrint("Routing error: $e");
  }
}

/// Simulates driver moving along the actual road route
void _startRouteSimulation() {
  if (_routePoints.isEmpty) return;
  
  // Calculate interval: total points / (duration * 10 updates per second)
  final int totalUpdates = _simulationDurationSeconds * 10; // 10 updates per second
  final int pointsPerUpdate = (_routePoints.length / totalUpdates).ceil().clamp(1, _routePoints.length);
  
  int step = 0;
  final int maxSteps = _simulationDurationSeconds * 10;
  
  _simulationTimer?.cancel();
  _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
    if (step >= maxSteps || _currentRouteIndex >= _routePoints.length - 1) {
      timer.cancel();
      debugPrint('Simulation complete - driver arrived!');
      return;
    }
    
    // Move to next point(s) along route
    _currentRouteIndex = (_currentRouteIndex + pointsPerUpdate).clamp(0, _routePoints.length - 1);
    
    setState(() {
      driverPosition = _routePoints[_currentRouteIndex];
    });
    
    // Update driver position in Firestore
    FirebaseFirestore.instance.collection('drivers').doc('current_driver').set({
      'current_lat': driverPosition.latitude,
      'current_lng': driverPosition.longitude,
    }, SetOptions(merge: true));
    
    step++;
  });
}

  Future<void> _checkPermissionsAndStart() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      startLocationReporting();
    }
  }

  // Add this helper method to your _MissionDashboardState class
Widget _buildRealTimeTokenPanel() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('drivers')
        .doc('current_driver') // Ensure this matches the doc ID you use for the driver
        .snapshots(),
    builder: (context, snapshot) {
      // Default to 0 if data is loading or missing
      int tokens = 0;

      if (snapshot.hasData && snapshot.data!.exists) {
        final data = snapshot.data!.data() as Map<String, dynamic>;
        tokens = data['pulse_tokens'] ?? 0;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.offline_bolt, color: Colors.amberAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              "$tokens PULSE",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    },
  );
}
  void startLocationReporting() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await FirebaseFirestore.instance.collection('drivers').doc('current_driver').set({
          'current_lat': pos.latitude,
          'current_lng': pos.longitude,
        }, SetOptions(merge: true));
        
        if (mounted) {
          setState(() {
            driverPosition = LatLng(pos.latitude, pos.longitude);
          });
        }
      } catch (e) { 
        debugPrint("Location update error: $e"); 
      }
    });
  }

 // 1. Ensure this variable is defined at the top of your State class
final Set<Marker> _markers = {
  const Marker(
    markerId: MarkerId('mission_site'),
    position: LatLng(12.923, 77.498), // Near RVCE
  ),
};

@override
Widget build(BuildContext context) {
  return Scaffold(
  body: Stack(
  children: [
    _buildMapLayer(),   // ✅ THIS is your real system
    Positioned(
          top: 50, // Pushes it down safely below the status bar
          right: 20,
          child: _buildRealTimeTokenPanel(),
        ),
    Positioned(
      bottom: 30, // Bottom side
  left: 30,
  child: FloatingActionButton(
    backgroundColor: Colors.blueGrey,
    onPressed: () => Navigator.push(
  context, 
  MaterialPageRoute(builder: (context) => const MissionCasesPage())
),
    child: const Icon(Icons.visibility), // The "Vision" logo/icon
  ),
    ),
  ],
),
  );
}
 
// Simple helper to render your 50 tokens
Widget _buildTokenPanel() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('drivers')
        .doc('current_driver')
        .snapshots(),
    builder: (context, snapshot) {
      int tokens = 0;

      if (snapshot.hasData && snapshot.data!.exists) {
        final data = snapshot.data!.data() as Map<String, dynamic>;
        tokens = data['pulse_tokens'] ?? 0;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          "PULSE TOKENS: $tokens",
          style: const TextStyle(color: Colors.white),
        ),
      );
    },
  );
}
 Widget _buildMapLayer() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('drivers').doc('current_driver').snapshots(),
    builder: (context, driverSnapshot) {
      if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
        final data = driverSnapshot.data!.data() as Map<String, dynamic>;
        driverPosition = LatLng(data['current_lat'] ?? 12.9069, data['current_lng'] ?? 77.4855);
      }

      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('active_missions')
            .where('status', whereIn: ['pending', 'in_transit']).snapshots(),
        builder: (context, missionSnapshot) {
          final docs = missionSnapshot.data?.docs ?? [];
          
          QueryDocumentSnapshot? activeDoc;
          if (_activeMissionId != null) {
            activeDoc = docs.cast<QueryDocumentSnapshot?>().firstWhere(
              (d) => d?.id == _activeMissionId, orElse: () => null);
          } else if (docs.isNotEmpty) {
            activeDoc = docs.first;
          }

          // CRITICAL: We use a unique string as the key to force the browser 
          // to destroy and recreate the map when the status changes.
          String mapKey = activeDoc != null 
              ? "${activeDoc.id}_${activeDoc['status']}_${_polylines.length}" 
              : "initial_map";

          return Stack(
            fit: StackFit.expand,
            children: [
              GoogleMap(
                key: ValueKey(mapKey), // THIS IS THE HARD RESET
                initialCameraPosition: CameraPosition(target: driverPosition, zoom: 14.0),
                myLocationEnabled: true,
                markers: {
                  Marker(
                    markerId: const MarkerId('driver'), 
                    position: driverPosition, 
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
                  ),
                  if (activeDoc != null)
                    Marker(
                      markerId: const MarkerId('mission'),
                      position: LatLng(activeDoc['lat'], activeDoc['lng']),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                },
                polylines: _polylines,
              ),

              if (activeDoc != null) ...[
                if (activeDoc['status'] == 'pending')
                  _buildPendingPanel(activeDoc),
                if (activeDoc['status'] == 'in_transit')
                  _buildInTransitPanel(activeDoc),
              ],
            ],
          );
        },
      );
    },
  );
}

  Widget _buildAntigravityProfile() {
    return Positioned(
      top: 50,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('drivers').doc('current_driver').snapshots(),
          builder: (context, snapshot) {
            final tokens = (snapshot.data?.data() as Map<String, dynamic>?)?['pulse_tokens'] ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("PULSE TOKENS", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
                Text("$tokens", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(
                    value: (tokens % 500) / 500.0, // Progress to next 500-token tier [cite: 31]
                    backgroundColor: Colors.white10,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInTransitPanel(QueryDocumentSnapshot activeDoc) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        child: SizedBox(
          height: 200,
          width: MediaQuery.of(context).size.width * 0.9,
          child: ElevatedButton(
            onPressed: () async {
              await activeDoc.reference.update({'status': 'completed'});
              await FirebaseFirestore.instance.collection('drivers').doc('current_driver').set(
                {'pulse_tokens': FieldValue.increment(50)}, 
                SetOptions(merge: true)
              );
              setState(() {
                _polylines = {};
                _activeMissionId = null; // Clear lock for next mission 
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text('RESOURCE DELIVERED', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPanel(QueryDocumentSnapshot missionDoc) {
    final data = missionDoc.data() as Map<String, dynamic>;
    final detourDistance = data['detour_distance'] ?? '2.4'; // Fallback if not yet set by CF
    
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        child: Container(
          height: 200,
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black87, // Solid color to prevent Web render clipping
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('MISSION BRIEFING', style: TextStyle(color: Colors.blueAccent, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                        Icon(Icons.radar, color: Colors.blueAccent.withOpacity(0.8), size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      '${data['item']}',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),

    const SizedBox(height: 4),

    const Text(
      "AI DETECTED: Water scarcity hotspot",
      style: TextStyle(color: Colors.blueAccent, fontSize: 12),
    ),
  ],
),
                    const SizedBox(height: 8),
                    
                    // Arbitrage Data Visualization (Impact Metrics)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('DETOUR', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              const SizedBox(height: 4),
                              Text('+$detourDistance km', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(width: 1, height: 30, color: Colors.white24),
                          const Column(
                            children: [
                              Text('REWARD', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              SizedBox(height: 4),
                              Text('50 TOKENS', style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
  "Impact: Helps ~100+ people in this area",
  style: TextStyle(color: Colors.greenAccent, fontSize: 12),
),
                    
                    ElevatedButton(
                      onPressed: () async {
  setState(() => _activeMissionId = missionDoc.id);

  await missionDoc.reference.update({'status': 'in_transit'});

  await _drawRouteToMission(
    start: driverPosition,
    destination: LatLng(missionDoc['lat'], missionDoc['lng']),
  );
},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent, 
                        // Change this line:
                        foregroundColor: (data['urgency'] ?? 0) > 8 ? Colors.redAccent : Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('ACCEPT MISSION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}