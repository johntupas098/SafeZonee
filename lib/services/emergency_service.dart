import '../models/emergency_responder.dart';

class EmergencyService {
  static Future<List<EmergencyResponder>> getNearbyResponders(
      double latitude,
      double longitude
      ) async {
    await Future.delayed(Duration(seconds: 1));

    return [
      EmergencyResponder(
        id: '1',
        name: 'Metro Police Station #5',
        type: 'Police',
        latitude: latitude + 0.005,
        longitude: longitude + 0.005,
        distance: 1.2,
        contactNumber: '+63-912-345-6789',
        address: '123 EDSA, Quezon City',
      ),
      EmergencyResponder(
        id: '2',
        name: 'Fire Station Central',
        type: 'Fire',
        latitude: latitude - 0.003,
        longitude: longitude + 0.008,
        distance: 2.1,
        contactNumber: '+63-917-123-4567',
        address: '456 Commonwealth Ave',
      ),
      EmergencyResponder(
        id: '3',
        name: 'East Medical Center',
        type: 'Medical',
        latitude: latitude + 0.007,
        longitude: longitude - 0.002,
        distance: 0.8,
        contactNumber: '+63-998-789-0123',
        address: '789 Timog Ave, Diliman',
      ),
    ];
  }

  static Future<bool> sendDistressSignal({
    required double latitude,
    required double longitude,
    required String message,
    required String userId,
  }) async {
    await Future.delayed(Duration(seconds: 2));
    return true;
  }
}