import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mission Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
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
  Timer? _locationTimer;
  LatLng driverPosition = const LatLng(12.9069, 77.4855);
  Set<Polyline> _polylines = {};
  final PolylinePoints _polylinePoints = PolylinePoints();
  // Note: API keys should ideally be in a secure environment file
  final String _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStart();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> getDirections(LatLng destination) async {
    // Prevent redundant calls
    if (_polylines.isNotEmpty) return;

    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      apiKey: _googleMapsApiKey,
      request: PolylineRequest(
        origin: PointLatLng(driverPosition.latitude, driverPosition.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        travelMode: TravelMode.driving,
      ),
    );
    if (result.points.isNotEmpty) {
      if (mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId("route"),
              points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
              color: Colors.blueAccent,
              width: 6,
            ),
          };
        });
      }
    }
  }

  Future<void> _checkPermissionsAndStart() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      startLocationReporting();
    }
  }

  void startLocationReporting() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await FirebaseFirestore.instance.collection('drivers').doc('current_driver').set({
          'current_lat': pos.latitude,
          'current_lng': pos.longitude,
        }, SetOptions(merge: true));
      } catch (e) { debugPrint("$e"); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
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
              QueryDocumentSnapshot? activeDoc = docs.isNotEmpty ? docs.first : null;
              
              if (activeDoc != null && activeDoc['status'] == 'in_transit') {
                getDirections(LatLng(activeDoc['lat'], activeDoc['lng']));
              }

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: driverPosition, zoom: 15.5),
                    myLocationEnabled: true,
                    markers: {
                      Marker(
                        markerId: const MarkerId('driver'), 
                        position: driverPosition, 
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
                      ),
                    },
                    polylines: _polylines,
                  ),
                  if (activeDoc != null) ...[
                    if (activeDoc['status'] == 'pending')
                      _buildPendingPanel(activeDoc, context),
                    if (activeDoc['status'] == 'in_transit')
                      Positioned(
                        bottom: 40,
                        left: 24,
                        right: 24,
                        child: ElevatedButton(
                          onPressed: () async {
                            await activeDoc.reference.update({'status': 'completed'});
                            await FirebaseFirestore.instance.collection('drivers').doc('current_driver').set(
                              {'pulse_tokens': FieldValue.increment(50)}, 
                              SetOptions(merge: true)
                            );
                            setState(() => _polylines = {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                          ),
                          child: const Text('RESOURCE DELIVERED'),
                        ),
                      ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingPanel(QueryDocumentSnapshot missionDoc, BuildContext context) {
    final data = missionDoc.data() as Map<String, dynamic>;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
            color: Colors.black87, 
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mission: ${data['item']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => missionDoc.reference.update({'status': 'in_transit'}),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('ACCEPT MISSION'),
            ),
          ],
        ),
      ),
    );
  }
}