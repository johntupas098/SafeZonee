import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:metered_realtime/metered_realtime.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final supabase = Supabase.instance.client;

  LatLng _currentLocation = const LatLng(10.7202, 122.5621);
  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _responderSubscription;

  final Map<MarkerId, Marker> _liveResponders = {};

  static const String _meteredApiKey =
      'pk_live_ffa91f88e27d9d705f400f3a9f29eeba2380691f';

  MeteredPeer? _meteredPeer;
  final List<StreamSubscription<dynamic>> _meteredSubscriptions = [];
  final List<StreamSubscription<dynamic>> _remotePeerSubscriptions = [];
  String? _meteredAlertId;
  bool _meteredJoinInProgress = false;
  Future<void>? _meteredCleanupFuture;
  bool _widgetDisposed = false;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isCalling = false;
  bool _isSpeakerOn = false;
  bool _isEndingCall = false;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String? _currentAlertId;
  StreamSubscription? _currentAlertStatusSubscription;
  Timer? _alertStatusPollTimer;
  bool _statusCheckInProgress = false;
  RealtimeChannel? _callEndedChannel;

  final List<Map<String, dynamic>> staticResponders = [
    ['PS1 City Proper', 10.701501994092405, 122.56369039944839, 'police', '0998-598-6242'],
    ['PS2 La Paz', 10.70552222109631, 122.56549995693831, 'police', '0998-598-6244'],
    ['PS3 Jaro', 10.71560226623802, 122.56266469623272, 'police', '0998-598-6246'],
    ['Molo Police Station', 10.698346304433658, 122.55105476464729, 'police', '0998-598-6248'],
    ['PS5 Mandurriao', 10.71683400704982, 122.53648059623264, 'police', '0998-598-6250'],
    ['Arevalo Police Station', 10.68890021276814, 122.51886825833218, 'police', '0998-598-6252'],
    ['PS7 Lapuz', 10.693878433584727, 122.55874469935698, 'police', '0947-996-6568'],
    ['Sambag Police Assistant', 10.742333401995415, 122.5409438842518, 'police', '0908-689-6098'],
    ['Ungka Police Station', 10.747512542219782, 122.54008363707585, 'police', '0908-322-8457'],
    ['ICPO Police Station 9', 10.7272054892569, 122.56710895228002, 'police', '0908-322-8457'],
    ['ICPO Police Station 10', 10.70553584277189, 122.55517513417514, 'police', '0908-308-0940'],
    ['La Paz Fire Sub-Station', 10.712651852092284, 122.57295111469945, 'fire', '(033) 320 6963'],
    ['Federation Iloilo Fire Station', 10.698697241164309, 122.57076622219913, 'fire', '(033) 337 9760'],
    ['BFP Iloilo', 10.690705849929284, 122.58144791800282, 'fire', '500-5026'],
    ['Bo. Obrero Fire Sub-Station', 10.702275407727985, 122.59067301967075, 'fire', '(033) 335 1965'],
    ['Mandurriao Fire Sub-Station', 10.719211489646474, 122.53920666146492, 'fire', '(033) 321 0779'],
    ['Arevalo Fire Sub-Station', 10.688797426748417, 122.51626529021178, 'fire', '(033) 321 1096'],
    ['Sto. Niño Sur Fire Sub-Station', 10.68223713089546, 122.5099533777009, 'fire', '(033) 314 7631'],
    ['BFP Jaro', 10.72744065268221, 122.56251218153137, 'fire', '(033) 500 0217'],
    ['Ungka Fire Sub-Station', 10.74690941039231, 122.53931659330536, 'fire', '0919-066-2333'],
    ['Old Molo Fire Station', 10.697030999439814, 122.5488881609591, 'fire', '(033) 336 0639'],
    ['San Isidro Fire Sub-Station', 10.736444550002995, 122.5458557423291, 'fire', '(033) 330 1507'],
    ['Western Visayas Medical Center', 10.718885489071287, 122.54193891896666, 'medical', '0919-066-1554'],
    ['Iloilo Mission Hospital', 10.714817707214994, 122.56058274040979, 'medical', '0919-066-1554'],
    ['St. Paul\'s Hospital Iloilo', 10.702011896133618, 122.56694877109325, 'medical', '0919-066-1554'],
    ['Iloilo Doctors\' Hospital', 10.696804152759018, 122.55440768089073, 'medical', '0919-066-1554'],
    ['The Medical City Iloilo', 10.699644543003238, 122.54277137544258, 'medical', '0919-066-1554'],
    ['WVSU Medical Center', 10.717168244196454, 122.56120580362972, 'medical', '0919-066-1554'],
    ['QualiMed Hospital Iloilo', 10.706542561402188, 122.54782241379408, 'medical', '0919-066-1554'],
    ['Medicus Medical Center', 10.702756754480117, 122.55224702393059, 'medical', '0919-066-1554'],
    ['AMOSUP Seamen\'s Hospital', 10.714828158629505, 122.53455543124073, 'medical', '0919-066-1554'],
  ].map((r) => <String, dynamic>{
    'name': r[0],
    'lat': r[1],
    'lng': r[2],
    'type': r[3],
    'phone': r[4],
  }).toList();

  @override
  void initState() {
    super.initState();
    _getCurrentInitialLocation();
    _startLiveTracking();
    _subscribeToResponders();
    unawaited(_remoteRenderer.initialize());
    unawaited(_cleanupStaleCalls()); // Fix: Cleans up ghost calls instead of resuming them
  }

  Future<String> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webBrowserInfo = await deviceInfo.webBrowserInfo;
        return webBrowserInfo.userAgent ?? 'web-device';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios-device';
      }
    } catch (e) {
      debugPrint('[Device Info Error] $e');
    }
    return 'unknown-device';
  }

  // FIX: This entirely replaces the old _recoverActiveAlert logic
  Future<void> _cleanupStaleCalls() async {
    try {
      final deviceId = await _getDeviceId();
      if (deviceId == 'unknown-device') return;

      // Close any calls tied to this device ID that are still hanging open in Supabase
      await supabase
          .from('emergency_alerts')
          .update({'status': 'ended'})
          .eq('device_id', deviceId)
          .neq('status', 'ended');

      debugPrint('[Caller Call] Cleaned up stale calls for device: $deviceId');
    } catch (error) {
      debugPrint('[Caller Call] Failed to clean up stale calls: $error');
    }
  }

  void _watchRemotePeer(RemotePeer remote) {
    if (_widgetDisposed || _isEndingCall) return;
    debugPrint('[Metered Caller] Remote peer joined: ${remote.id}');
    _remotePeerSubscriptions.add(
      remote.onStreamAdded.listen((event) {
        if (_widgetDisposed || _isEndingCall) return;
        final stream = event.stream;
        if (stream is FlutterWebrtcMediaStream) {
          _remoteStream = stream.native;
          _remoteRenderer.srcObject = stream.native;
          debugPrint('[Metered Caller] Receiving remote audio: ${remote.id}');
        }
      }),
    );
  }

  Future<void> _joinMeteredCall(
      String alertId, {
        bool throwOnFailure = false,
      }) async {
    final pendingCleanup = _meteredCleanupFuture;
    if (pendingCleanup != null) await pendingCleanup;
    if (_widgetDisposed ||
        _meteredAlertId == alertId ||
        _meteredJoinInProgress ||
        _isEndingCall) {
      return;
    }

    _meteredJoinInProgress = true;
    final roomId = 'safezone-call-$alertId';
    debugPrint('[Metered Caller] Accepted alert: $alertId');
    debugPrint('[Metered Caller] Room: $roomId');

    try {
      final stream = _localStream ??
          await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': false,
          });
      if (_widgetDisposed || _currentAlertId != alertId || _isEndingCall) {
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
        return;
      }

      final audioTracks = stream.getAudioTracks();
      debugPrint('[Metered Caller] Audio tracks: ${audioTracks.length}');
      if (audioTracks.isEmpty) {
        throw StateError('Microphone stream contains no audio track');
      }

      final peer = MeteredPeer(
        MeteredPeerOptions(
          apiKey: _meteredApiKey,
          logger: const ConsoleLogger(),
        ),
      );
      _meteredPeer = peer;
      _localStream = stream;

      _meteredSubscriptions
        ..add(peer.onPeerJoined.listen(_watchRemotePeer))
        ..add(peer.onPeerLeft.listen((remote) {
          debugPrint('[Metered Caller] Remote peer left: ${remote.id}');
          if (!_isEndingCall) {
            endCurrentCall(reason: 'admin-ended', notifyRemote: false);
          }
        }))
        ..add(peer.stateChanges.listen(
              (change) => debugPrint(
            '[Metered Caller] State: ${change.from} -> ${change.to}',
          ),
        ))
        ..add(peer.onError.listen(
              (error) => debugPrint('[Metered Caller] Error: $error'),
        ));

      await peer.addStream(
        wrapMediaStream(stream),
        metadata: {
          'role': 'voice',
          'label': 'caller microphone',
          'alertId': alertId,
        },
      );
      debugPrint('[Metered Caller] Publishing microphone audio');
      await peer.join(roomId);

      if (_widgetDisposed || _currentAlertId != alertId || _isEndingCall) {
        await peer.close('alert-ended-during-join');
        return;
      }

      _meteredAlertId = alertId;
      debugPrint('[Metered Caller] Audio published and room joined: $roomId');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call connected to dispatch'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[Metered Caller] Join failed: $error');
      debugPrint(stackTrace.toString());
      await _closeMeteredCall('join-failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to connect call: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (throwOnFailure) rethrow;
    } finally {
      _meteredJoinInProgress = false;
    }
  }

  Future<void> _subscribeToCurrentAlertStatus() async {
    final currentAlertId = _currentAlertId;
    if (currentAlertId == null || currentAlertId.isEmpty) {
      return;
    }

    await _currentAlertStatusSubscription?.cancel();
    _alertStatusPollTimer?.cancel();

    _callEndedChannel?.unsubscribe();
    final channel = supabase.channel('call-dispatch');
    _callEndedChannel = channel;
    channel.onBroadcast(
      event: 'call-ended',
      callback: (payload) async {
        final payloadCallId = payload['callId']?.toString();
        debugPrint('[Caller Call] Received call-ended broadcast for: $payloadCallId');
        if ((payloadCallId == currentAlertId || payloadCallId == null) && !_isEndingCall) {
          await endCurrentCall(reason: 'admin-ended', notifyRemote: false);
        }
      },
    ).subscribe();

    final dynamic queryId = int.tryParse(currentAlertId) ?? currentAlertId;

    _currentAlertStatusSubscription = supabase
        .from('emergency_alerts')
        .stream(primaryKey: ['id'])
        .eq('id', queryId)
        .listen((List<Map<String, dynamic>> rows) async {
      if (_currentAlertId == null) return;

      for (final row in rows) {
        await _handleAlertStatusRow(row, source: 'realtime');
      }
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('[Caller Call] Alert status subscription error: $error');
      debugPrint(stackTrace.toString());
    });

    await _checkCurrentAlertStatus(source: 'initial-read');
    _alertStatusPollTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => unawaited(_checkCurrentAlertStatus(source: 'poll')),
    );
  }

  Future<void> _handleAlertStatusRow(
      Map<String, dynamic> row, {
        required String source,
      }) async {
    final updatedId = row['id']?.toString();
    final status = row['status']?.toString();
    if (updatedId == null || status == null || updatedId != _currentAlertId) {
      return;
    }

    final normalizedStatus = status.toLowerCase();
    debugPrint(
      '[Caller Call] Alert $updatedId status: $normalizedStatus ($source)',
    );
    if (normalizedStatus == 'accepted') {
      await _joinMeteredCall(updatedId);
      return;
    }

    const terminalStatuses = {
      'ended',
      'cancelled',
      'failed',
      'completed',
      'closed',
      'resolved',
      'rejected',
      'done',
      'declined',
    };

    if (terminalStatuses.contains(normalizedStatus) && !_isEndingCall) {
      await endCurrentCall(reason: 'admin-ended', notifyRemote: false);
    }
  }

  Future<void> _checkCurrentAlertStatus({required String source}) async {
    final alertId = _currentAlertId;
    if (alertId == null || _statusCheckInProgress || _isEndingCall) return;
    _statusCheckInProgress = true;
    try {
      final dynamic queryId = int.tryParse(alertId) ?? alertId;
      final row = await supabase
          .from('emergency_alerts')
          .select('id,status')
          .eq('id', queryId)
          .maybeSingle();
      if (row != null) await _handleAlertStatusRow(row, source: source);
    } catch (error) {
      debugPrint('[Caller Call] Status $source failed: $error');
    } finally {
      _statusCheckInProgress = false;
    }
  }

  Future<void> _broadcastCallEnded({
    required String callId,
    required String reason,
  }) async {
    try {
      const channelName = 'call-dispatch';
      final channel = supabase.channel(channelName);
      _callEndedChannel = channel;
      channel.subscribe();
      await channel.sendBroadcastMessage(
        event: 'call-ended',
        payload: {
          'callId': callId,
          'from': 'flutter-metered-caller',
          'reason': reason,
        },
      );
      debugPrint('[Caller Call] Broadcasting call-ended');
    } catch (error, stackTrace) {
      debugPrint('[Caller Call] Broadcast error: $error');
      debugPrint(stackTrace.toString());
    }
  }

  Future<void> endCurrentCall({
    required String reason,
    bool notifyRemote = true,
  }) async {
    if (_isEndingCall) {
      debugPrint(
          '[Caller Call] Already ending call; ignoring reason: $reason');
      return;
    }

    _isEndingCall = true;
    final callId = _currentAlertId;
    debugPrint('[Caller Call] Ending call: $callId (Reason: $reason)');

    try {
      if (notifyRemote && callId != null && callId.isNotEmpty) {
        debugPrint('[Caller Call] Updating status to ended');
        final dynamic queryId = int.tryParse(callId) ?? callId;
        await supabase
            .from('emergency_alerts')
            .update({'status': 'ended'})
            .eq('id', queryId);

        await _broadcastCallEnded(
          callId: callId,
          reason: reason,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[Caller Call] End-call update/broadcast error: $error');
      debugPrint(stackTrace.toString());
    } finally {
      try {
        await _closeMeteredCall(reason);
      } catch (error) {
        debugPrint('[Caller Call] Metered cleanup error: $error');
      }

      _currentAlertStatusSubscription?.cancel();
      _currentAlertStatusSubscription = null;
      _alertStatusPollTimer?.cancel();
      _alertStatusPollTimer = null;
      _callEndedChannel?.unsubscribe();
      _callEndedChannel = null;

      _localStream = null;
      _remoteStream = null;
      _remoteRenderer.srcObject = null;

      if (mounted) {
        setState(() {
          _isCalling = false;
          _isSpeakerOn = false;
          _isEndingCall = false;
          _currentAlertId = null;
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reason == 'admin-ended'
                  ? 'Call ended by dispatch.'
                  : 'Call disconnected.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      debugPrint('[Caller Call] UI reset complete');
    }
  }

  Future<void> _closeMeteredCall(String reason) {
    final existingCleanup = _meteredCleanupFuture;
    if (existingCleanup != null) return existingCleanup;

    final cleanup = _performMeteredCleanup(reason);
    _meteredCleanupFuture = cleanup;
    return cleanup.whenComplete(() {
      if (identical(_meteredCleanupFuture, cleanup)) {
        _meteredCleanupFuture = null;
      }
    });
  }

  Future<void> _performMeteredCleanup(String reason) async {
    final peer = _meteredPeer;
    _meteredPeer = null;
    _meteredAlertId = null;
    final localStream = _localStream;
    final remoteStream = _remoteStream;
    _localStream = null;
    _remoteStream = null;
    if (!_widgetDisposed) _remoteRenderer.srcObject = null;

    final meteredSubscriptions = List<StreamSubscription<dynamic>>.of(
      _meteredSubscriptions,
    );
    final remoteSubscriptions = List<StreamSubscription<dynamic>>.of(
      _remotePeerSubscriptions,
    );
    _meteredSubscriptions.clear();
    _remotePeerSubscriptions.clear();

    for (final subscription in meteredSubscriptions) {
      await subscription.cancel();
    }
    for (final subscription in remoteSubscriptions) {
      await subscription.cancel();
    }

    try {
      await peer?.close(reason);
    } catch (error) {
      debugPrint('[Metered Caller] Close failed: $error');
    }

    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    for (final track in remoteStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await localStream?.dispose();
    await remoteStream?.dispose();
    debugPrint('[Metered Caller] Cleanup complete');
  }

  Future<void> _toggleSpeaker() async {
    final session = await AudioSession.instance;
    setState(() => _isSpeakerOn = !_isSpeakerOn);

    if (_isSpeakerOn) {
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
        AVAudioSessionCategoryOptions.defaultToSpeaker,
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
      setState(() =>
      _currentLocation = LatLng(position.latitude, position.longitude));
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation));
    }
  }

  void _startLiveTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      if (mounted) {
        setState(() =>
        _currentLocation = LatLng(position.latitude, position.longitude));
      }
    });
  }

  void _subscribeToResponders() {
    _responderSubscription = supabase
        .from('responders')
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
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
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: responder['name'] ?? 'Live Responder',
              snippet: responder['phone'] != null
                  ? 'Contact: ${responder['phone']}'
                  : null,
            ),
          );
        }
      });
    });
  }

  BitmapDescriptor _getMarkerHue(String type) {
    if (type == 'police') {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
    if (type == 'fire') {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  Widget _getResponderIconUI(String type) {
    if (type == 'police') {
      return const Icon(Icons.local_police_outlined, color: Colors.blue, size: 20);
    } else if (type == 'fire') {
      return const Icon(Icons.fire_truck, color: Colors.orange, size: 20);
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
      _hangUp();
      return;
    }

    try {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) return;
      }

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      debugPrint('[Metered Caller] Microphone ready');

      if (mounted) {
        setState(() => _isCalling = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Broadcasting SOS to all dispatchers...'),
              backgroundColor: Colors.blue),
        );
      }

      final deviceId = await _getDeviceId();

      final response = await supabase
          .from('emergency_alerts')
          .insert({
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
        'status': 'pending',
        'caller_peer_id': 'metered-caller',
        'device_id': deviceId,
      })
          .select()
          .single();

      _currentAlertId = response['id'].toString();
      debugPrint('[Caller Call] Active alert ID: $_currentAlertId');

      await _joinMeteredCall(_currentAlertId!, throwOnFailure: true);
      await _subscribeToCurrentAlertStatus();
    } catch (e, stackTrace) {
      debugPrint('[Caller Call] Call processing error: $e');
      debugPrint(stackTrace.toString());
      if (_currentAlertId != null) {
        await endCurrentCall(reason: 'call-setup-failed', notifyRemote: false);
      } else {
        await _closeMeteredCall('call-setup-failed');
        if (mounted) setState(() => _isCalling = false);
      }
    }
  }

  Future<void> _hangUp() async {
    await endCurrentCall(reason: 'local-end', notifyRemote: true);
  }

  @override
  void dispose() {
    _widgetDisposed = true;
    _positionStream?.cancel();
    _responderSubscription?.cancel();
    _currentAlertStatusSubscription?.cancel();
    _alertStatusPollTimer?.cancel();
    _callEndedChannel?.unsubscribe();
    _mapController?.dispose();
    _remoteRenderer.srcObject = null;
    unawaited(_closeMeteredCall('widget-disposed'));
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
            initialCameraPosition:
            CameraPosition(target: _currentLocation, zoom: 14),
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
                  snippet:
                  '${data['type'].toString().toUpperCase()} • ${data['phone']}',
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
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10)
                    ],
                  ),
                  child: const Text(
                    "SafeZone Live Map",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 5)
                    ],
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
                              Expanded(
                                child: Text(
                                  '${responder['name']} (${responder['phone']})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
                    backgroundColor:
                    _isSpeakerOn ? Colors.red[900] : Colors.white,
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
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.remove, color: Colors.red[900]),
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomOut()),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "center",
                  mini: true,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.my_location, color: Colors.red[900]),
                  onPressed: () async {
                    Position position = await Geolocator.getCurrentPosition();
                    LatLng freshLocation =
                    LatLng(position.latitude, position.longitude);
                    _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(freshLocation, 15));
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
              IconButton(
                  icon: const Icon(Icons.assignment_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/report')),
              const SizedBox(width: 50),
              IconButton(
                  icon: const Icon(Icons.notifications_active_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/alerts')),
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
              Text("SOS",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}