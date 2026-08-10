import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlertsScreen extends StatefulWidget {
  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _supabase = Supabase.instance.client;
  late FlutterLocalNotificationsPlugin _localNotificationsPlugin;

  final Set<String> _processedIncidentIds = {};
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  void _initNotifications() async {
    _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'safety_alerts_channel',
      'Safety Alerts',
      channelDescription: 'Real-time safety hazard alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  Color _getAlertColor(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return Colors.orange;
      case 'medical':
        return Colors.red;
      case 'police':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getLocalIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return Icons.fire_truck;
      case 'medical':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police_outlined;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 Safety Alerts', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[900],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('incidents')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading alerts: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final incidents = snapshot.data!
              .where((incident) => (incident['status'] as String? ?? '').toLowerCase() != 'cancelled')
              .toList();

          if (_isInitialLoad) {
            for (var inc in incidents) {
              if (inc['id'] != null) {
                _processedIncidentIds.add(inc['id'].toString());
              }
            }
            _isInitialLoad = false;
          } else {
            for (var inc in incidents) {
              final id = inc['id']?.toString() ?? '';
              if (id.isNotEmpty && !_processedIncidentIds.contains(id)) {
                _processedIncidentIds.add(id);
                final category = inc['category'] as String? ?? 'Safety Hazard';
                final description = inc['description'] as String? ?? 'New incident reported.';

                _showLocalNotification("New $category Alert!", description);
              }
            }
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[800]!, Colors.red[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ongoing Hazards', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${incidents.length} active incidents', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              Expanded(
                child: incidents.isEmpty
                    ? const Center(child: Text("All clear! No current hazards."))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: incidents.length,
                  itemBuilder: (context, index) {
                    final incident = incidents[index];

                    final category = incident['category'] as String? ?? 'General';
                    final description = incident['description'] as String? ?? 'No description provided.';
                    final status = incident['status'] as String? ?? 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_getAlertColor(category).withOpacity(0.15), Colors.white],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getAlertColor(category),
                              child: Icon(_getLocalIcon(category), color: Colors.white),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    category,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: status.toLowerCase() == 'pending' ? Colors.amber[800] : Colors.green[700],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[800]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}