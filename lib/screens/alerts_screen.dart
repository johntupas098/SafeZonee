import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, String>> localAlerts = [
    {
      'title': '🚧 EDSA TRAFFIC JAM',
      'type': 'Traffic',
      'time': '2 min ago',
      'severity': 'High',
      'color': 'red',
    },
    {
      'title': '💡 STREET LIGHT OUT - Timog Ave',
      'type': 'Street Light',
      'time': '8 min ago',
      'severity': 'Medium',
      'color': 'orange',
    },
    {
      'title': '🗑️ GARBAGE OVERFLOW - Barangay Hall',
      'type': 'Garbage',
      'time': '12 min ago',
      'severity': 'Medium',
      'color': 'orange',
    },
    {
      'title': '🚰 WATER LEAK - Commonwealth',
      'type': 'Water Leak',
      'time': '20 min ago',
      'severity': 'High',
      'color': 'red',
    },
    {
      'title': '🕳️ POTHOLE REPORTED - Quezon Ave',
      'type': 'Pothole',
      'time': '35 min ago',
      'severity': 'Low',
      'color': 'amber',
    },
  ];

  Color _getAlertColor(String? severity) {
    switch (severity) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 LOCAL Hazard Alerts'),
        backgroundColor: Colors.amber,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber[400]!, Colors.amber[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 36),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Real-time Local Alerts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${localAlerts.length} LOCAL issues',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: localAlerts.length,
                itemBuilder: (context, index) {
                  final alert = localAlerts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getAlertColor(alert['severity']).withOpacity(0.2),
                            _getAlertColor(alert['severity']),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        leading: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(
                            _getLocalIcon(alert['type']!),
                            color: _getAlertColor(alert['severity']),
                            size: 28,
                          ),
                        ),
                        title: Text(
                          alert['title']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '${alert['type']} • ${alert['time']} • ${alert['severity']}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Reported: ${alert['title']}'),
                              backgroundColor: _getAlertColor(
                                alert['severity'],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLocalIcon(String type) {
    switch (type.toLowerCase()) {
      case 'traffic':
        return Icons.traffic;
      case 'street light':
        return Icons.lightbulb;
      case 'garbage':
        return Icons.delete;
      case 'water leak':
        return Icons.water_drop;
      case 'pothole':
        return Icons.remove_road;
      default:
        return Icons.warning;
    }
  }
}
