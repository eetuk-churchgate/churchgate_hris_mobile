import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBdWLl_iN0WE4fjjikuLgcO3WWTVAY4qkc',
        appId: '1:864827271573:android:0ac3e2864d8d27ad902e9c',
        messagingSenderId: '864827271573',
        projectId: 'churchgate-hris',
      ),
    );
    await NotificationService.initialize();
  } catch (e) {
    // Firebase not available - continue without push notifications
  }

  await Supabase.initialize(
    url: 'https://pobfydvkjzhkmhuqwmtf.supabase.co',
    anonKey: 'sb_publishable_iDYmuO5jfqmzydDPgNhL3w_b21rWMhm',
  );

  runApp(const ChurchgateHRIS());
}

class ChurchgateHRIS extends StatelessWidget {
  const ChurchgateHRIS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Churchgate HRIS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFCC0000),
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCC0000),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}