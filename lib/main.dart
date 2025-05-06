import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:html' as html; // For loading the Google Maps script dynamically
import './admin/admin_dashboard.dart';
import 'users/login_screen.dart';
import 'users/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl;
  String supabaseKey;

  if (kIsWeb) {
    // Load from dart-define (set during build/run)
    supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
    supabaseKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    // Load Google Maps JavaScript API key from dart-define and inject the script
    const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    _loadGoogleMapsScript(googleMapsApiKey);
  } else {
    // Load from .env (excluded from Git)
    await dotenv.load(fileName: ".env");
    supabaseUrl = dotenv.env['SUPABASE_URL']!;
    supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  runApp(MyApp());
}

void _loadGoogleMapsScript(String apiKey) {
  final script =
      html.ScriptElement()
        ..type = 'text/javascript'
        ..async = true
        ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey';
  html.document.head!.append(script);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return MaterialApp(
        title: 'Digital Billboard',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: LoginScreen(),
      );
    }

    final role = session.user?.appMetadata['role']; // <-- FIX HERE

    Widget home;
    if (role == 'admin') {
      home = AdminDashboardScreen();
    } else {
      home = HomeScreen();
    }

    return MaterialApp(
      title: 'Digital Billboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: home,
    );
  }
}
