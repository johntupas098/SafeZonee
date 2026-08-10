import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/home_screen.dart';
import 'screens/incident_screen.dart';
import 'screens/alerts_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zjedyulcrxcttbukbynh.supabase.co',
    anonKey: 'sb_publishable_O4_Gy_uk6L50ARMA8QnP1g_QEAS2lJJ',
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await androidImplementation?.requestNotificationsPermission();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    Supabase.instance.client
        .channel('public:incidents')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'incidents',
      callback: (payload) {
        final record = payload.newRecord;

        final String? deviceId = record['device_id'];
        final String? phoneNumber = record['phone_number'];

        final bool hasDeviceId = deviceId != null && deviceId.trim().isNotEmpty;
        final bool hasPhoneNumber = phoneNumber != null && phoneNumber.trim().isNotEmpty;

        if (hasDeviceId && hasPhoneNumber) {
          return;
        }

        final category = record['category'] ?? 'Safety Hazard';
        final description =
            record['description'] ?? 'New incident reported.';

        _showGlobalNotification(
          id: DateTime.now().millisecond,
          title: 'New $category Alert!',
          body: description,
        );
      },
    )
        .subscribe();
  }

  Future<void> _showGlobalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'safety_alerts_channel',
      'Safety Alerts',
      channelDescription: 'Real-time safety hazard alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeZone',
      theme: ThemeData(primarySwatch: Colors.red),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/report': (context) => IncidentScreen(),
        '/alerts': (context) => AlertsScreen(),
      },
    );
  }
}