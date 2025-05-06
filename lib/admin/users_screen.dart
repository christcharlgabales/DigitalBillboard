import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../users/login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> inactiveDrivers = [];

  @override
  void initState() {
    super.initState();
    fetchDrivers();
  }

  Future<void> fetchDrivers() async {
    final response = await supabase.from('users').select().eq('role', 'Driver');
    final active = response.where((u) => u['status'] == 'active').toList();
    final inactive = response.where((u) => u['status'] != 'active').toList();

    setState(() {
      drivers = List<Map<String, dynamic>>.from(active);
      inactiveDrivers = List<Map<String, dynamic>>.from(inactive);
    });
  }

  void _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  final TextEditingController _deactivateController = TextEditingController();

  Future<void> _deactivateDriver() async {
    final evNumber = _deactivateController.text.trim();
    if (evNumber.isEmpty) return;

    final updates = {'status': 'inactive'};

    await supabase.from('users').update(updates).eq('ev_number', evNumber);
    _deactivateController.clear();
    fetchDrivers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/logo.png'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'ALERT TO DIVERT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 30),
                _buildSidebarButton(Icons.dashboard, 'Dashboard'),
                _buildSidebarButton(Icons.people, 'Users', isActive: true),
                _buildSidebarButton(Icons.tv, 'Billboard'),
                _buildSidebarButton(Icons.list, 'Logs'),
                const Spacer(),
                const CircleAvatar(radius: 20, child: Icon(Icons.person)),
                const SizedBox(height: 6),
                const Text('Christ Charles Gabales'),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'EV Drivers',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Total: ${drivers.length + inactiveDrivers.length}'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Table
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('EV Number')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows:
                        drivers
                            .map(
                              (driver) => DataRow(
                                cells: [
                                  DataCell(Text(driver['name'] ?? '')),
                                  DataCell(Text(driver['role'] ?? '')),
                                  DataCell(Text(driver['ev_number'] ?? '')),
                                  DataCell(Text(driver['email'] ?? '')),
                                  DataCell(Text(driver['status'] ?? '')),
                                  DataCell(
                                    TextButton(
                                      onPressed: () {
                                        // Add log navigation later
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Logs coming soon'),
                                          ),
                                        );
                                      },
                                      child: const Text('View Logs'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                  ),

                  const SizedBox(height: 30),

                  // Deactivation and Inactive Drivers Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Deactivate EV Driver Panel
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Deactivate EV Driver',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _deactivateController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter EV Number',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _deactivateDriver,
                                icon: const Icon(Icons.power_settings_new),
                                label: const Text('Deactivate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Inactive EV Driver Panel
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Inactive EV Driver',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (var driver in inactiveDrivers)
                                ListTile(
                                  title: Text(
                                    driver['ev_number'] ?? 'Unknown EV',
                                  ),
                                  subtitle: Text(
                                    'Last Use: February 2025',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
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

  Widget _buildSidebarButton(
    IconData icon,
    String label, {
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.redAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.white : Colors.black54),
        title: Text(
          label,
          style: TextStyle(color: isActive ? Colors.white : Colors.black87),
        ),
        onTap: () {
          // Implement navigation or selection logic
        },
      ),
    );
  }
}
