import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../users/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late GoogleMapController mapController;

  final List<Marker> _markers = [
    Marker(
      markerId: MarkerId('1'),
      position: LatLng(8.9526, 125.5298),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ),
    Marker(
      markerId: MarkerId('2'),
      position: LatLng(8.9550, 125.5300),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ),
    Marker(
      markerId: MarkerId('3'),
      position: LatLng(8.9570, 125.5320),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ),
  ];

  String userName = "Admin";
  int totalBillboards = 7;
  int activeUsers = 11;
  int alertsToday = 3;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAuth();
    _loadAdminData();
  }

  Future<void> _checkAdminAuth() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _navigateToLogin();
        return;
      }

      final role = user.appMetadata['role'];
      if (role != 'admin') {
        _showMessage('Unauthorized access. Please login as admin.');
        _navigateToLogin();
      }
    } catch (e) {
      print('Authentication error: $e');
      _showMessage('Authentication error');
      _navigateToLogin();
    }
  }

  Future<void> _loadAdminData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Use email prefix as fallback name
      userName = user.email?.split('@').first ?? 'Admin';

      // Get statistics
      final billboardResponse = await Supabase.instance.client
          .from('billboards')
          .select('*', const FetchOptions(count: CountOption.exact))
          .eq('active', true);

      final billboardCount = billboardResponse.count ?? 0;

      final userResponse = await Supabase.instance.client
          .from('profiles')
          .select('*', const FetchOptions(count: CountOption.exact))
          .gt(
            'last_sign_in',
            DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
          );

      final userCount = userResponse.count ?? 0;

      final alertResponse = await Supabase.instance.client
          .from('emergency_alerts')
          .select('*', const FetchOptions(count: CountOption.exact))
          .gte('created_at', DateTime.now().toIso8601String().split('T')[0]);

      final todayAlerts = alertResponse.count ?? 0;

      setState(() {
        totalBillboards = billboardCount;
        activeUsers = userCount;
        alertsToday = todayAlerts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading admin data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    _navigateToLogin();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF8B3E3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'EEEE, MMMM d y',
    ).format(DateTime.now());

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: const Color(0xFF8B3E3E)),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: const Color(0xFF8B3E3E),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 40),
                    const CircleAvatar(
                      backgroundImage: AssetImage(
                        'icon.jpg',
                      ), // Replace with your app logo
                      radius: 30,
                      backgroundColor:
                          Colors.white, // Fallback if image isn't loaded
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ALERT TO DIVERT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),
                    buildNavItem(Icons.dashboard, "Dashboard", true),
                    buildNavItem(Icons.group, "Users", false),
                    buildNavItem(Icons.location_on, "Billboard", false),
                    buildNavItem(Icons.receipt_long, "Logs", false),
                  ],
                ),
                Column(
                  children: [
                    const Divider(color: Colors.white54),
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        userName,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      subtitle: const Text(
                        "Admin",
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.logout, color: Colors.white, size: 18),
                        onPressed: _signOut,
                        tooltip: "Logout",
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20.0,
                horizontal: 30.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Welcome Back $userName!',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Google Map
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        onMapCreated: (controller) {
                          mapController = controller;
                        },
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(8.9526, 125.5298),
                          zoom: 14,
                        ),
                        markers: Set<Marker>.of(_markers),
                        myLocationEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Statistics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      buildStatCard(
                        Icons.location_city,
                        "Total Active Billboards",
                        totalBillboards,
                        Colors.brown,
                      ),
                      buildStatCard(
                        Icons.people,
                        "Active Users",
                        activeUsers,
                        Colors.black87,
                      ),
                      buildStatCard(
                        Icons.warning_amber,
                        "Alerts Triggered Today",
                        alertsToday,
                        Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNavItem(IconData icon, String label, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: active ? Colors.white.withOpacity(0.2) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: () {
          // Handle navigation logic
        },
      ),
    );
  }

  Widget buildStatCard(IconData icon, String label, int value, Color bgColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
