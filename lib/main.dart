import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv to load .env file
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load();

  // Fetch Supabase URL and API key from .env
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;

  // Initialize Supabase with values from .env
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
