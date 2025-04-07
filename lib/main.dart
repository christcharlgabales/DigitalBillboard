import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:
        'https://jlipihosbermbnaolpme.supabase.co', // <-- Replace with your URL
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsaXBpaG9zYmVybWJuYW9scG1lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDI2MDgsImV4cCI6MjA1OTYxODYwOH0.Did1Nan5xTBXDPD06WZdaY_5uhY8qktoSUWFu4B3uGQ', // <-- Replace with your anon/public key
  );

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
