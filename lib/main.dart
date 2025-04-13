import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl;
  String supabaseKey;

  if (kIsWeb) {
    // Load from dart-define (set during build/run)
    supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
    supabaseKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  } else {
    // Load from .env (excluded from Git)
    await dotenv.load(fileName: ".env");
    supabaseUrl = dotenv.env['SUPABASE_URL']!;
    supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Billboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          Supabase.instance.client.auth.currentSession == null
              ? LoginScreen()
              : HomeScreen(),
    );
  }
}
