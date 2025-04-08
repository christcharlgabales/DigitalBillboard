import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart'; // Make sure this file exists
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String locationText = "Press the button to get location";

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _fetchLocation() async {
    try {
      final locationService = LocationService();
      Position position = await locationService.getCurrentLocation();

      setState(() {
        locationText =
            "Latitude: ${position.latitude}, Longitude: ${position.longitude}";
      });
    } catch (e) {
      setState(() {
        locationText = "Error: ${e.toString()}";
      });
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Welcome Card
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
                      const Text(
                        'Welcome!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You are logged in as:',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(255, 22, 20, 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildOptionButton(
                    'View Alerts',
                    Icons.notification_important,
                  ),
                  const SizedBox(width: 20),
                  _buildOptionButton('View Route', Icons.directions_car),
                ],
              ),
              const SizedBox(height: 30),
              // Location display
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                color: Colors.redAccent.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        locationText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _fetchLocation,
                        icon: const Icon(Icons.location_on),
                        label: const Text('Get Current Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14.0,
                            horizontal: 20.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable option button
  Widget _buildOptionButton(String title, IconData icon) {
    return ElevatedButton(
      onPressed: () {
        // Placeholder for navigation logic
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
