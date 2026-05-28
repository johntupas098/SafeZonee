import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_responder.dart';

class RespondersScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const RespondersScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  _RespondersScreenState createState() => _RespondersScreenState();
}

class _RespondersScreenState extends State<RespondersScreen> {
  List<EmergencyResponder> responders = [];
  bool isLoading = true;
  GoogleMapController? mapController;
  LatLng? _currentLiveLocation;
  StreamSubscription<Position>? _positionStream;

  final List<Map<String, dynamic>> rawData = [
    {"name": "PS1 City Proper", "lat": 10.701501994092405, "lng": 122.56369039944839, "type": "police"},
    {"name": "PS2 La Paz", "lat": 10.70552222109631, "lng": 122.56549995693831, "type": "police"},
    {"name": "PS3 Jaro", "lat": 10.71560226623802, "lng": 122.56266469623272, "type": "police"},
    {"name": "Molo Police Station", "lat": 10.698346304433658, "lng": 122.55105476464729, "type": "police"},
    {"name": "PS5 Mandurriao", "lat": 10.71683400704982, "lng": 122.53648059623264, "type": "police"},
    {"name": "Arevalo Police Station", "lat": 10.68890021276814, "lng": 122.51886825833218, "type": "police"},
    {"name": "PS7 Lapuz", "lat": 10.693878433584727, "lng": 122.55874469935698, "type": "police"},
    {"name": "Sambag Police Assistant", "lat": 10.742333401995415, "lng": 122.5409438842518, "type": "police"},
    {"name": "Ungka Police Station", "lat": 10.747512542219782, "lng": 122.54008363707585, "type": "police"},
    {"name": "ICPO Police Station 9", "lat": 10.7272054892569, "lng": 122.56710895228002, "type": "police"},
    {"name": "ICPO Police Station 10", "lat": 10.70553584277189, "lng": 122.55517513417514, "type": "police"},
    {"name": "La Paz Fire Sub-Station", "lat": 10.712651852092284, "lng": 122.57295111469945, "type": "fire"},
    {"name": "Federation Iloilo Fire Station", "lat": 10.698697241164309, "lng": 122.57076622219913, "type": "fire"},
    {"name": "BFP Iloilo", "lat": 10.690705849929284, "lng": 122.58144791800282, "type": "fire"},
    {"name": "Bo. Obrero Fire Sub-Station", "lat": 10.702275407727985, "lng": 122.59067301967075, "type": "fire"},
    {"name": "Mandurriao Fire Sub-Station", "lat": 10.719211489646474, "lng": 122.53920666146492, "type": "fire"},
    {"name": "Arevalo Fire Sub-Station", "lat": 10.688797426748417, "lng": 122.51626529021178, "type": "fire"},
    {"name": "Sto. Niño Sur Fire Sub-Station", "lat": 10.68223713089546, "lng": 122.5099533777009, "type": "fire"},
    {"name": "BFP Jaro", "lat": 10.72744065268221, "lng": 122.56251218153137, "type": "fire"},
    {"name": "Ungka Fire Sub-Station", "lat": 10.74690941039231, "lng": 122.53931659330536, "type": "fire"},
    {"name": "Old Molo Fire Station", "lat": 10.697030999439814, "lng": 122.5488881609591, "type": "fire"},
    {"name": "San Isidro Fire Sub-Station", "lat": 10.736444550002995, "lng": 122.5458557423291, "type": "fire"},
    {"name": "Western Visayas Medical Center", "lat": 10.718885489071287, "lng": 122.54193891896666, "type": "medical"},
    {"name": "Iloilo Mission Hospital", "lat": 10.714817707214994, "lng": 122.56058274040979, "type": "medical"},
    {"name": "St. Paul's Hospital Iloilo", "lat": 10.702011896133618, "lng": 122.56694877109325, "type": "medical"},
    {"name": "Iloilo Doctors' Hospital", "lat": 10.696804152759018, "lng": 122.55440768089073, "type": "medical"},
    {"name": "The Medical City Iloilo", "lat": 10.699644543003238, "lng": 122.54277137544258, "type": "medical"},
    {"name": "WVSU Medical Center", "lat": 10.717168244196454, "lng": 122.56120580362972, "type": "medical"},
    {"name": "QualiMed Hospital Iloilo", "lat": 10.706542561402188, "lng": 122.54782241379408, "type": "medical"},
    {"name": "Medicus Medical Center", "lat": 10.702756754480117, "lng": 122.55224702393059, "type": "medical"},
    {"name": "AMOSUP Seamen's Hospital", "lat": 10.714828158629505, "lng": 122.53455543124073, "type": "medical"},
  ];

  @override
  void initState() {
    super.initState();
    _currentLiveLocation = LatLng(widget.latitude, widget.longitude);
    _loadNearbyResponders();
    _startLiveTracking();
  }

  void _startLiveTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      if (mounted) {
        setState(() => _currentLiveLocation = LatLng(position.latitude, position.longitude));
        mapController?.animateCamera(CameraUpdate.newLatLng(_currentLiveLocation!));
      }
    });
  }

  Future<void> _loadNearbyResponders() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    final userLat = _currentLiveLocation?.latitude ?? widget.latitude;
    final userLng = _currentLiveLocation?.longitude ?? widget.longitude;

    final List<EmergencyResponder> mappedResponders = rawData.map((data) {
      double distanceInMeters = Geolocator.distanceBetween(
          userLat, userLng, data['lat'], data['lng']
      );

      return EmergencyResponder(
        id: data['name'],
        name: data['name'],
        latitude: data['lat'],
        longitude: data['lng'],
        type: data['type'],
        distance: distanceInMeters / 1000,
        contactNumber: "911",
        address: "Iloilo City",
      );
    }).toList();

    mappedResponders.sort((a, b) => a.distance.compareTo(b.distance));

    if (mounted) {
      setState(() {
        responders = mappedResponders;
        isLoading = false;
      });
    }
  }

  BitmapDescriptor _getMarkerIcon(String type) {
    if (type == 'police') return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    if (type == 'fire') return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  Color _getColor(String type) {
    if (type == 'police') return Colors.blue;
    if (type == 'fire') return Colors.orange;
    return Colors.red;
  }

  IconData _getIcon(String type) {
    if (type == 'police') return Icons.local_police;
    if (type == 'fire') return Icons.local_fire_department;
    return Icons.local_hospital;
  }

  @override
  Widget build(BuildContext context) {
    final LatLng displayPos = _currentLiveLocation ?? LatLng(widget.latitude, widget.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text('Iloilo Responders (${responders.length})'),
        backgroundColor: Colors.red[900],
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadNearbyResponders)],
      ),
      body: isLoading
          ? const Center(child: SpinKitDoubleBounce(color: Colors.red, size: 60))
          : Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            child: GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: CameraPosition(target: displayPos, zoom: 14),
              myLocationEnabled: true,
              markers: {
                Marker(
                  markerId: const MarkerId('you'),
                  position: displayPos,
                  infoWindow: const InfoWindow(title: 'YOUR LOCATION'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
                ...responders.map((r) => Marker(
                  markerId: MarkerId(r.id),
                  position: LatLng(r.latitude, r.longitude),
                  infoWindow: InfoWindow(title: r.name, snippet: '${r.distance.toStringAsFixed(1)}km'),
                  icon: _getMarkerIcon(r.type),
                )),
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: responders.length,
              itemBuilder: (context, index) {
                final r = responders[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: _getColor(r.type), child: Icon(_getIcon(r.type), color: Colors.white)),
                    title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${r.distance.toStringAsFixed(1)} km away • ${r.type.toUpperCase()}'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    mapController?.dispose();
    super.dispose();
  }
}