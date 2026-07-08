import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlertsScreen extends StatefulWidget {
  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _supabase = Supabase.instance.client;

  Color _getAlertColor(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return Colors.orange;
      case 'medic':
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
        return Icons.local_fire_department;
      case 'medic':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 Traffic & Safety Alerts'),
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
          final incidents = snapshot.data!;

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