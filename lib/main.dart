import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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