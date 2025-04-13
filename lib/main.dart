import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv to load .env file
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl;
  String supabaseKey;

  if (kIsWeb) {
    // Load directly for web (hardcoded or use web-safe alternatives)
    supabaseUrl = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://jlipihosbermbnaolpme.supabase.co',
    );
    supabaseKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsaXBpaG9zYmVybWJuYW9scG1lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDI2MDgsImV4cCI6MjA1OTYxODYwOH0.Did1Nan5xTBXDPD06WZdaY_5uhY8qktoSUWFu4B3uGQ',
    );
  } else {
    // Load environment variables from .env file
    await dotenv.load(fileName: ".env");
    supabaseUrl = dotenv.env['SUPABASE_URL']!;
    supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;
  }

  // Initialize Supabase
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
