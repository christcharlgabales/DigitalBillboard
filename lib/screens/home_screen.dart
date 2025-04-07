import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    // After logout, navigate back to login screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
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
            // Driver Dashboard Options
            Text(
              'What would you like to do?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 20),
            // Options Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOptionButton('View Alerts', Icons.notification_important),
                SizedBox(width: 20),
                _buildOptionButton('View Route', Icons.directions_car),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to create option buttons
  Widget _buildOptionButton(String title, IconData icon) {
    return ElevatedButton(
      onPressed: () {
        // Implement navigation for each button's functionality
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            Colors.redAccent, // Use backgroundColor instead of primary
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
