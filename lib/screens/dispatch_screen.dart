import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import '../services/emergency_service.dart';

class DispatchScreen extends StatefulWidget {
  final Position position;
  const DispatchScreen({Key? key, required this.position}) : super(key: key);

  @override
  _DispatchScreenState createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final _messageController = TextEditingController();
  bool isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendDistressSignal() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please describe your emergency')),
      );
      return;
    }

    setState(() => isSending = true);

    final success = await EmergencyService.sendDistressSignal(
      latitude: widget.position.latitude,
      longitude: widget.position.longitude,
      message: _messageController.text.trim(),
      userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
    );

    setState(() => isSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '✅ SOS SENT to DASMO! Help is coming!'
            : '❌ Failed to send SOS - Try again'
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );

    if (success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        title: const Text('🚨 Emergency SOS'),
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.red[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos, size: 80, color: Colors.red),
            ),
            const SizedBox(height: 24),

            const Text(
              'Send LIVE Distress Signal',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your LIVE GPS: ${widget.position.latitude.toStringAsFixed(4)}, ${widget.position.longitude.toStringAsFixed(4)}',
              style: TextStyle(fontSize: 16, color: Colors.green[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _messageController,
              maxLines: 5,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Describe your emergency *REQUIRED*',
                hintText: 'Medical emergency, Fire, Accident, Robbery, etc...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                prefixIcon: const Icon(Icons.description, color: Colors.red),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                onPressed: isSending ? null : _sendDistressSignal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: isSending
                    ? const SpinKitFadingCircle(color: Colors.white, size: 30)
                    : const Text(
                  '🚨 SEND SOS TO DASMO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}