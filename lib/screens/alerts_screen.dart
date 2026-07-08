import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlertsScreen extends StatefulWidget {
  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _supabase = Supabase.instance.client;

  Color _getAlertColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire': return Colors.red;
      case 'car collision': return Colors.orangeAccent;
      case 'road closed': return Colors.amber;
      default: return Colors.blueGrey;
    }
  }

  IconData _getLocalIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire': return Icons.local_fire_department;
      case 'car collision': return Icons.directions_car;
      case 'road closed': return Icons.construction;
      default: return Icons.warning;
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
            .from('alerts')
            .stream(primaryKey: ['id'])
            .eq('status', 'ongoing')
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
          final alerts = snapshot.data!;

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
                    Text('${alerts.length} active incidents', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              Expanded(
                child: alerts.isEmpty
                    ? const Center(child: Text("All clear! No current hazards."))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final type = alert['type'] as String? ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_getAlertColor(type).withOpacity(0.2), Colors.white],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAlertColor(type),
                            child: Icon(_getLocalIcon(type), color: Colors.white),
                          ),
                          title: Text(alert['title'] ?? 'Incident', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(type),
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