import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../users/login_screen.dart';
import '../admin/users_screen.dart';
import '../admin/billboards_screen.dart';
import '../admin/logs_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late GoogleMapController mapController;
  Set<Marker> _markers = {};

  String userName = "Admin";
  int totalBillboards = 0;
  int activeUsers = 0;
  int alertsToday = 0;
  bool _isLoading = true;

  // Current active screen index
  int _currentScreenIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAuth();
    _loadAdminData();

    // Subscribe to new alerts (e.g., a billboard was activated)
    Supabase.instance.client
        .channel('public:alerts')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(event: 'INSERT', schema: 'public', table: 'alerts'),
          (payload, [ref]) {
            print('New alert inserted: ${payload['new']}');
            _loadAdminData(); // Reload dashboard stats and markers
          },
        )
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(event: 'DELETE', schema: 'public', table: 'alerts'),
          (payload, [ref]) {
            print('Alert deleted: ${payload['old']}');
            _loadAdminData(); // Reload again on removal
          },
        )
        .subscribe();

    // (Optional) Listen for billboard activation changes (status toggled)
    Supabase.instance.client.channel('public:billboards').on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: 'UPDATE', schema: 'public', table: 'billboards'),
      (payload, [ref]) {
        print('Billboard updated: ${payload['new']}');
        _loadAdminData(); // Update active billboard count and marker icon
      },
    ).subscribe();
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

      userName = user.email?.split('@').first ?? 'Admin';

      // Fetch active billboards and markers
      final billboardResponse = await Supabase.instance.client
          .from('billboards')
          .select('*');

      // Make sure we properly handle the response as a List
      if (billboardResponse is List) {
        final billboards = billboardResponse;

        print('Fetched ${billboards.length} billboards from database');

        // Count active billboards
        totalBillboards = billboards.where((b) => b['active'] == true).length;

        // Clear existing markers and create new ones
        _markers.clear();

        for (var billboard in billboards) {
          if (billboard['latitude'] != null && billboard['longitude'] != null) {
            try {
              final double lat = double.parse(billboard['latitude'].toString());
              final double lng = double.parse(
                billboard['longitude'].toString(),
              );

              final marker = Marker(
                markerId: MarkerId(billboard['id'].toString()),
                position: LatLng(lat, lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  billboard['active'] == true
                      ? BitmapDescriptor.hueGreen
                      : BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(
                  title: billboard['name'] ?? 'Billboard ${billboard['id']}',
                  snippet: billboard['active'] == true ? 'Active' : 'Inactive',
                ),
              );

              _markers.add(marker);
              print('Added marker at: $lat, $lng');
            } catch (e) {
              print(
                'Error creating marker for billboard ${billboard['id']}: $e',
              );
            }
          } else {
            print('Invalid coordinates for billboard ${billboard['id']}');
          }
        }
      } else {
        print('Invalid response format from billboards table');
      }

      // Active users in last 7 days
      try {
        final userResponse = await Supabase.instance.client
            .from('profiles')
            .select('*', const FetchOptions(count: CountOption.exact))
            .gt(
              'last_sign_in',
              DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
            );
        activeUsers = userResponse.count ?? 0;
      } catch (e) {
        print('Error fetching profiles: $e');
        activeUsers = 0; // Default if table doesn't exist
      }

      // Alerts triggered today
      try {
        final alertResponse = await Supabase.instance.client
            .from('emergency_alerts')
            .select('*', const FetchOptions(count: CountOption.exact))
            .gte('created_at', DateTime.now().toIso8601String().split('T')[0]);
        alertsToday = alertResponse.count ?? 0;
      } catch (e) {
        print('Error fetching emergency_alerts: $e');
        alertsToday = 0; // Default if table doesn't exist
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading admin data: $e');
      setState(() => _isLoading = false);
      _showMessage('Error loading data: ${e.toString().substring(0, 100)}');
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
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF8B3E3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _switchScreen(int index) {
    setState(() {
      _currentScreenIndex = index;
    });
  }

  // Dashboard content
  Widget _buildDashboardContent() {
    final String formattedDate = DateFormat(
      'EEEE, MMMM d y',
    ).format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Welcome back $userName!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Debug info
          Text(
            'Total markers: ${_markers.length}',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 10),

          // Google Map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                onMapCreated: (controller) {
                  mapController = controller;
                },
                initialCameraPosition: const CameraPosition(
                  target: LatLng(8.9526, 125.5298), // Butuan City, Philippines
                  zoom: 14,
                ),
                markers: _markers,
                myLocationEnabled: false,
                zoomControlsEnabled: true,
                mapToolbarEnabled: true,
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
    );
  }

  // Function to get the correct content based on index
  Widget _getContentForIndex() {
    switch (_currentScreenIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const UsersScreen(); // Using our newly created UsersScreen
      case 2:
        return const BillboardsScreen();
      case 3:
        return const LogsScreen();
      default:
        return _buildDashboardContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B3E3E)),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar - This stays constant
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
                      backgroundImage: AssetImage('icon.jpg'),
                      radius: 30,
                      backgroundColor: Colors.white,
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
                    buildNavItem(
                      Icons.dashboard,
                      "Dashboard",
                      _currentScreenIndex == 0,
                      () {
                        _switchScreen(0);
                      },
                    ),
                    buildNavItem(
                      Icons.group,
                      "Users",
                      _currentScreenIndex == 1,
                      () {
                        _switchScreen(1);
                      },
                    ),
                    buildNavItem(
                      Icons.location_on,
                      "Billboard",
                      _currentScreenIndex == 2,
                      () {
                        _switchScreen(2);
                      },
                    ),
                    buildNavItem(
                      Icons.receipt_long,
                      "Logs",
                      _currentScreenIndex == 3,
                      () {
                        _switchScreen(3);
                      },
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Divider(color: Colors.white54),
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: const Text(
                        "Admin",
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 18,
                        ),
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

          // Main Content - This changes based on navigation
          Expanded(child: _getContentForIndex()),
        ],
      ),
    );
  }

  Widget buildNavItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: active ? Colors.white.withOpacity(0.2) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: onTap,
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

// Note: We've removed the placeholder UsersContent class as it's been replaced
// with the actual implementation in users_screen.dart

// Placeholder widgets for content sections that don't have implementations yet

@override
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(20.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billboard Management',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20),
        Expanded(
          child: Center(
            child: Text('Billboard management content will go here'),
          ),
        ),
      ],
    ),
  );
}

class LogsContent extends StatelessWidget {
  const LogsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Logs',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Expanded(
            child: Center(child: Text('System logs content will go here')),
          ),
        ],
      ),
    );
  }
}
