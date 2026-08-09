import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peerdart/peerdart.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final supabase = Supabase.instance.client;

  LatLng _currentLocation = const LatLng(10.7202, 122.5621);
  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _responderSubscription;
  StreamSubscription? _activeAlertSubscription; // Listens for admin status updates

  Map<MarkerId, Marker> _liveResponders = {};

  late Peer _peer;
  MediaStream? _localStream;
  MediaConnection? _activeCall;
  bool _isCalling = false;
  bool _isSpeakerOn = false;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String? _myPeerId;
  String? _currentAlertId;
  String? _deviceId;

  final List<Map<String, dynamic>> staticResponders = [
    {"name": "PS1 City Proper", "lat": 10.701501994092405, "lng": 122.56369039944839, "type": "police", "phone": "0998-598-6242"},
    {"name": "PS2 La Paz", "lat": 10.70552222109631, "lng": 122.56549995693831, "type": "police", "phone": "0998-598-6244"},
    {"name": "PS3 Jaro", "lat": 10.71560226623802, "lng": 122.56266469623272, "type": "police", "phone": "0998-598-6246"},
    {"name": "Molo Police Station", "lat": 10.698346304433658, "lng": 122.55105476464729, "type": "police", "phone": "0998-598-6248"},
    {"name": "PS5 Mandurriao", "lat": 10.71683400704982, "lng": 122.53648059623264, "type": "police", "phone": "0998-598-6250"},
    {"name": "Arevalo Police Station", "lat": 10.68890021276814, "lng": 122.51886825833218, "type": "police", "phone": "0998-598-6252"},
    {"name": "PS7 Lapuz", "lat": 10.693878433584727, "lng": 122.55874469935698, "type": "police", "phone": "0947-996-6568"},
    {"name": "Sambag Police Assistant", "lat": 10.742333401995415, "lng": 122.5409438842518, "type": "police", "phone": "0908-689-6098"},
    {"name": "Ungka Police Station", "lat": 10.747512542219782, "lng": 122.54008363707585, "type": "police", "phone": "0908-689-6098"},
    {"name": "ICPO Police Station 9", "lat": 10.7272054892569, "lng": 122.56710895228002, "type": "police", "phone": "0908-322-8457"},
    {"name": "ICPO Police Station 10", "lat": 10.70553584277189, "lng": 122.55517513417514, "type": "police", "phone": "0908-308-0940"},
    {"name": "La Paz Fire Sub-Station", "lat": 10.712651852092284, "lng": 122.57295111469945, "type": "fire", "phone": "(033) 320 6963"},
    {"name": "Federation Iloilo Fire Station", "lat": 10.698697241164309, "lng": 122.57076622219913, "type": "fire", "phone": "(033) 337 9760"},
    {"name": "BFP Iloilo", "lat": 10.690705849929284, "lng": 122.58144791800282, "type": "fire", "phone": "500-5026"},
    {"name": "Bo. Obrero Fire Sub-Station", "lat": 10.702275407727985, "lng": 122.59067301967075, "type": "fire", "phone": "(033) 335 1965"},
    {"name": "Mandurriao Fire Sub-Station", "lat": 10.719211489646474, "lng": 122.53920666146492, "type": "fire", "phone": "(033) 321 0779"},
    {"name": "Arevalo Fire Sub-Station", "lat": 10.688797426748417, "lng": 122.51626529021178, "type": "fire", "phone": "(033) 321 1096"},
    {"name": "Sto. Niño Sur Fire Sub-Station", "lat": 10.68223713089546, "lng": 122.5099533777009, "type": "fire", "phone": "(033) 314 7631"},
    {"name": "BFP Jaro", "lat": 10.72744065268221, "lng": 122.56251218153137, "type": "fire", "phone": "(033) 500 0217"},
    {"name": "Ungka Fire Sub-Station", "lat": 10.74690941039231, "lng": 122.53931659330536, "type": "fire", "phone": "(033) 323 5139"},
    {"name": "Old Molo Fire Station", "lat": 10.697030999439814, "lng": 122.5488881609591, "type": "fire", "phone": "(033) 336 0639"},
    {"name": "San Isidro Fire Sub-Station", "lat": 10.736444550002995, "lng": 122.5458557423291, "type": "fire", "phone": "(033) 330 1507"},
    {"name": "Western Visayas Medical Center", "lat": 10.718885489071287, "lng": 122.54193891896666, "type": "medical", "phone": "0919-066-1554"},
    {"name": "Iloilo Mission Hospital", "lat": 10.714817707214994, "lng": 122.56058274040979, "type": "medical", "phone": "0919-066-1554"},
    {"name": "St. Paul's Hospital Iloilo", "lat": 10.702011896133618, "lng": 122.56694877109325, "type": "medical", "phone": "0919-066-1554"},
    {"name": "Iloilo Doctors' Hospital", "lat": 10.696804152759018, "lng": 122.55440768089073, "type": "medical", "phone": "0919-066-1554"},
    {"name": "The Medical City Iloilo", "lat": 10.699644543003238, "lng": 122.54277137544258, "type": "medical", "phone": "0919-066-1554"},
    {"name": "WVSU Medical Center", "lat": 10.717168244196454, "lng": 122.56120580362972, "type": "medical", "phone": "0919-066-1554"},
    {"name": "QualiMed Hospital Iloilo", "lat": 10.706542561402188, "lng": 122.54782241379408, "type": "medical", "phone": "0919-066-1554"},
    {"name": "Medicus Medical Center", "lat": 10.702756754480117, "lng": 122.55224702393059, "type": "medical", "phone": "0919-066-1554"},
    {"name": "AMOSUP Seamen's Hospital", "lat": 10.714828158629505, "lng": 122.53455543124073, "type": "medical", "phone": "0919-066-1554"},
  ];

  @override
  void initState() {
    super.initState();
    _initDeviceId();
    _getCurrentInitialLocation();
    _startLiveTracking();
    _subscribeToResponders();
    _initPeer();
  }

  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('device_unique_id');
    if (storedId == null || storedId.isEmpty) {
      storedId = const Uuid().v4();
      await prefs.setString('device_unique_id', storedId);
    }
    setState(() {
      _deviceId = storedId;
    });
  }

  Future<void> _initPeer() async {
    await _remoteRenderer.initialize();
    _peer = Peer();

    _peer.on('open').listen((id) {
      if (mounted) {
        setState(() => _myPeerId = id);
      }
      debugPrint("My Peer ID is: $_myPeerId");
    });

    _peer.on('error').listen((error) => debugPrint("Peer error: $error"));

    _peer.on<MediaConnection>('call').listen((call) async {
      _activeCall = call;

      _localStream ??= await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      call.answer(_localStream!);

      if (mounted) {
        setState(() => _isCalling = true);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call Connected to Dispatch'), backgroundColor: Colors.green),
        );
      }

      call.on<MediaStream>('stream').listen((remoteStream) {
        _remoteRenderer.srcObject = remoteStream;
      });

      call.on('close').listen((_) => _hangUp(isRemote: true)); // If connection closes remotely
    });
  }

  Future<void> _toggleSpeaker() async {
    final session = await AudioSession.instance;
    setState(() => _isSpeakerOn = !_isSpeakerOn);

    if (_isSpeakerOn) {
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
      ));
      Helper.setSpeakerphoneOn(true);
    } else {
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
      ));
      Helper.setSpeakerphoneOn(false);
    }
  }

  Future<void> _getCurrentInitialLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() => _currentLocation = LatLng(position.latitude, position.longitude));
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation));
    }
  }

  void _startLiveTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      if (mounted) {
        setState(() => _currentLocation = LatLng(position.latitude, position.longitude));
      }
    });
  }

  void _subscribeToResponders() {
    _responderSubscription = supabase
        .from('responders')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
      if (!mounted) return;
      setState(() {
        for (var responder in data) {
          final markerId = MarkerId("live_${responder['id']}");
          _liveResponders[markerId] = Marker(
            markerId: markerId,
            position: LatLng(
              (responder['latitude'] as num).toDouble(),
              (responder['longitude'] as num).toDouble(),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: responder['name'] ?? 'Live Responder'),
          );
        }
      });
    });
  }

  BitmapDescriptor _getMarkerHue(String type) {
    if (type == 'police') return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    if (type == 'fire') return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  Widget _getResponderIconUI(String type) {
    if (type == 'police') {
      return const Icon(Icons.emergency, color: Colors.blue, size: 20);
    } else if (type == 'fire') {
      return const Icon(Icons.sports_motorsports, color: Colors.orange, size: 20);
    } else {
      return const Icon(Icons.local_hospital, color: Colors.red, size: 20);
    }
  }

  void _goToResponder(double lat, double lng) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 16),
      ),
    );
  }

  Future<void> _triggerSOS() async {
    if (_isCalling) {
      _hangUp(); // User manually triggered hangup
      return;
    }

    if (_myPeerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecting to server, please wait...'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;

      if (mounted) {
        setState(() => _isCalling = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcasting SOS to all dispatchers...'), backgroundColor: Colors.blue),
        );
      }

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      final response = await supabase.from('emergency_alerts').insert({
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
        'status': 'pending',
        'caller_peer_id': _myPeerId,
        'device_id': _deviceId,
      }).select().single();

      _currentAlertId = response['id'].toString();

      // REALTIME LISTENER: Listen for status updates from Admin side
      await _activeAlertSubscription?.cancel();
      _activeAlertSubscription = supabase
          .from('emergency_alerts')
          .stream(primaryKey: ['id'])
          .eq('id', int.parse(_currentAlertId!))
          .listen((List<Map<String, dynamic>> data) {
        if (data.isNotEmpty) {
          final alertStatus = data.first['status'];
          // If admin cancels, resolves, or ends call, hang up user side
          if (alertStatus == 'cancelled' || alertStatus == 'resolved' || alertStatus == 'ended') {
            _hangUp(isRemote: true); // Tell the app the admin caused this
          }
        }
      });

    } catch (e) {
      debugPrint('Call processing error: $e');
      _hangUp();
    }
  }

  void _hangUp({bool isRemote = false}) async {
    // Unsubscribe real-time alert stream
    await _activeAlertSubscription?.cancel();
    _activeAlertSubscription = null;

    if (_currentAlertId != null) {
      final alertIdToCancel = _currentAlertId;
      _currentAlertId = null; // Clear ID to prevent redundant trigger loops

      // ONLY update the database if the user pressed the button.
      // If the admin hung up, the database is already updated!
      if (!isRemote) {
        try {
          await supabase
              .from('emergency_alerts')
              .update({'status': 'cancelled'})
              .eq('id', alertIdToCancel!);
        } catch (e) {
          debugPrint("Error updating alert status: $e");
        }
      }
    }

    _activeCall?.close();
    _activeCall = null;
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    _remoteRenderer.srcObject = null;

    if (mounted) {
      setState(() {
        _isCalling = false;
        _isSpeakerOn = false;
      });
    }
  }

  @override
  void dispose() {
    _activeAlertSubscription?.cancel();
    _positionStream?.cancel();
    _responderSubscription?.cancel();
    _mapController?.dispose();
    _hangUp();
    _peer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentLocation, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(top: 100, bottom: 140),
            onMapCreated: (controller) => _mapController = controller,
            markers: {
              ...staticResponders.map((data) => Marker(
                markerId: MarkerId(data['name']),
                position: LatLng(data['lat'], data['lng']),
                icon: _getMarkerHue(data['type']),
                infoWindow: InfoWindow(
                  title: data['name'],
                  snippet: "📞 ${data['phone']} (${data['type'].toUpperCase()})",
                ),
              )),
              ..._liveResponders.values,
            },
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: const Text(
                    "SafeZone Live Map",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      hint: const Text("Navigate to Responder"),
                      isExpanded: true,
                      items: staticResponders.map((responder) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: responder,
                          child: Row(
                            children: [
                              _getResponderIconUI(responder['type']),
                              const SizedBox(width: 10),
                              Text(responder['name']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _goToResponder(val['lat'], val['lng']);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 15,
            bottom: 110,
            child: Column(
              children: [
                if (_isCalling) ...[
                  FloatingActionButton(
                    heroTag: "speakerToggle",
                    mini: true,
                    backgroundColor: _isSpeakerOn ? Colors.red[900] : Colors.white,
                    child: Icon(
                      _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      color: _isSpeakerOn ? Colors.white : Colors.red[900],
                    ),
                    onPressed: _toggleSpeaker,
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.add, color: Colors.red[900]),
                  onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.remove, color: Colors.red[900]),
                  onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "center",
                  mini: true,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.my_location, color: Colors.red[900]),
                  onPressed: () async {
                    Position position = await Geolocator.getCurrentPosition();
                    LatLng freshLocation = LatLng(position.latitude, position.longitude);
                    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(freshLocation, 15));
                    setState(() => _currentLocation = freshLocation);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 12.0,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(icon: const Icon(Icons.assignment_outlined), onPressed: () => Navigator.pushNamed(context, '/report')),
              const SizedBox(width: 50),
              IconButton(icon: const Icon(Icons.notifications_active_outlined), onPressed: () => Navigator.pushNamed(context, '/alerts')),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 75,
        height: 75,
        child: FloatingActionButton(
          backgroundColor: _isCalling ? Colors.orange : Colors.red[900],
          onPressed: _triggerSOS,
          shape: const CircleBorder(),
          elevation: 10,
          child: _isCalling
              ? const Icon(Icons.call_end, color: Colors.white, size: 32)
              : const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_in_talk, color: Colors.white, size: 26),
              Text("SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}