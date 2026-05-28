class EmergencyResponder {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double distance;
  final String contactNumber;
  final String address;

  EmergencyResponder({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.contactNumber,
    required this.address,
  });

  factory EmergencyResponder.fromJson(Map<String, dynamic> json) {
    return EmergencyResponder(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unknown Responder',
      type: json['type'] ?? 'Medical',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      contactNumber: json['contactNumber'] ?? '+1-555-0000',
      address: json['address'] ?? 'Nearby location',
    );
  }
}