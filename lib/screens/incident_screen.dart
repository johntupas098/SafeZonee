import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class IncidentScreen extends StatefulWidget {
  @override
  _IncidentScreenState createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Police';
  File? _imageFile;
  bool _isUploading = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  String? _currentIncidentId;

  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> categories = [
    {'name': 'Police', 'icon': Icons.local_police, 'color': Colors.blue},
    {'name': 'Fire', 'icon': Icons.local_fire_department, 'color': Colors.orange},
    {'name': 'Medical', 'icon': Icons.local_hospital, 'color': Colors.red},
  ];

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void _startLiveTracking(String incidentId) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      try {
        await supabase.from('incidents').update({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }).eq('id', incidentId);
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (selectedImage != null) {
        setState(() {
          _imageFile = File(selectedImage.path);
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _showSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _handleImageSelection(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _handleImageSelection(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitIncident() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the emergency')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      Position position = await _determinePosition();
      String? imageUrl;

      if (_imageFile != null) {
        final fileName = 'incident_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = 'ufeng1_0/$fileName';

        await supabase.storage.from('report-images').upload(
          path,
          _imageFile!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        imageUrl = supabase.storage.from('report-images').getPublicUrl(path);
      }

      final data = await supabase.from('incidents').insert({
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      _currentIncidentId = data['id'].toString();
      _startLiveTracking(_currentIncidentId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ SOS Sent. Tracking live location...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Emergency'),
        backgroundColor: Colors.red[900],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What is the emergency?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Emergency Category',
                prefixIcon: const Icon(Icons.warning_amber_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat['name'],
                  child: Row(
                    children: [
                      Icon(cat['icon'], color: cat['color']),
                      const SizedBox(width: 10),
                      Text(cat['name']),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Details & Specific Location',
                hintText: 'Describe the situation...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Evidence Photo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_imageFile != null)
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(_imageFile!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _showSelectionDialog,
              icon: Icon(_imageFile == null ? Icons.add_a_photo : Icons.refresh),
              label: Text(_imageFile == null ? 'Add Photo' : 'Change Photo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isUploading ? null : _submitIncident,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'SEND EMERGENCY REPORT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }
}