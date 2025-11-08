import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:genset_tracker/providers/monitoring_provider.dart'
    show MonitoringProvider;
import 'package:genset_tracker/providers/user_provider.dart';
import 'package:genset_tracker/services/monitoring_service.dart';
import 'package:genset_tracker/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'core/config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 Pesan diterima di background: ${message.notification?.title}');
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseConfig.platformOptions);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await Firebase.initializeApp(options: DefaultFirebaseConfig.platformOptions);

  FirebaseMessaging messaging = FirebaseMessaging.instance;

// Minta izin
  NotificationSettings _ = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
// Dapatkan token FCM
  String? token = await messaging.getToken();
  print('🔥 Token FCM: $token');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📩 Foreground message: ${message.notification?.title}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🚀 Diklik dari notifikasi: ${message.notification?.title}');
  });

  RemoteMessage? initialMessage =
  await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('🧊 Pesan dari terminated: ${initialMessage.notification?.title}');
  }

  await messaging.subscribeToTopic("all_users");
  // Inisialisasi local notification
  await NotificationService.init();

  // Tunggu selesai inisialisasi lokal
  await initializeDateFormatting('id');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(
          create: (_) => MonitoringProvider(service: MonitoringService()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Firebase Realtime Boilerplate',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const RootScreen(),
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);


    return auth.user != null ? const HomeScreen() : const LoginScreen();
  }
}
