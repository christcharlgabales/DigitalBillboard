import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_locations_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _sendLocation(BuildContext context) async {
    try {
      // Show a loading indicator
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Getting your location...')));

      // Request and check location permissions
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied ||
          hasPermission == LocationPermission.deniedForever) {
        final permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required')),
          );
          return;
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get the current user
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to send location'),
          ),
        );
        return;
      }

      // Print debug information for Supabase client
      print('SUPABASE URL: ${Supabase.instance.client.supabaseUrl}');
      print(
        'AUTHENTICATED: ${Supabase.instance.client.auth.currentSession != null}',
      );

      // Print debug information for insert
      print('USER ID: ${user.id}');
      print('LATITUDE: ${position.latitude}');
      print('LONGITUDE: ${position.longitude}');
      print('TIMESTAMP: ${DateTime.now().toIso8601String()}');

      // Try a direct query first to check permissions
      try {
        final checkQuery = await Supabase.instance.client
            .from('locations')
            .select('count')
            .limit(1);

        print('CHECK QUERY RESPONSE: $checkQuery');
      } catch (checkError) {
        print('CHECK QUERY ERROR: $checkError');
      }

      // Insert location data with explicit error handling
      try {
        final insertData = {
          'user_id': user.id,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        };

        print('ATTEMPTING TO INSERT: $insertData');

        // Using the specific insert syntax recommended in latest Supabase docs
        final response = await Supabase.instance.client
            .from('locations')
            .insert(insertData);

        print('INSERT RESPONSE: $response');

        // Add a small delay to ensure database consistency
        await Future.delayed(const Duration(milliseconds: 500));

        // Query to verify data was saved
        final testQuery = await Supabase.instance.client
            .from('locations')
            .select()
            .eq('user_id', user.id);

        print('QUERY RESPONSE LENGTH: ${testQuery.length}');
        print('QUERY RESPONSE DATA: $testQuery');

        if (testQuery.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location sent but not found in database. Please check Supabase RLS policies.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location sent successfully!')),
          );

          // Navigate to view locations screen to see the saved location
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ViewLocationsScreen(),
            ),
          );
        }
      } catch (dbError) {
        print('DATABASE ERROR: $dbError');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Database error: $dbError')));
      }
    } catch (e) {
      print('GENERAL ERROR: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending location: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail =
        Supabase.instance.client.auth.currentUser?.email ?? 'No email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              color: Colors.redAccent.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20.0,
                  horizontal: 30.0,
                ),
                child: Column(
                  children: [
                    Text(
                      'Welcome!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'You are logged in as:',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    SizedBox(height: 10),
                    Text(
                      userEmail,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: const Color.fromARGB(255, 22, 20, 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            Text(
              'What would you like to do?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOptionButton(
                  context,
                  'View Alerts',
                  Icons.notification_important,
                ),
                SizedBox(width: 20),
                _buildOptionButton(context, 'View Route', Icons.directions_car),
              ],
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => _sendLocation(context),
              icon: Icon(Icons.location_on),
              label: Text('Send My Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(BuildContext context, String title, IconData icon) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ViewLocationsScreen()),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.white),
          SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}
