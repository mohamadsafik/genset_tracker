import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:genset_tracker/providers/monitoring_provider.dart'
    show MonitoringProvider;
import 'package:genset_tracker/providers/user_provider.dart';
import 'package:genset_tracker/services/monitoring_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'core/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseConfig.platformOptions);
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
