import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _activeDrivers = [];
  List<Map<String, dynamic>> _inactiveDrivers = [];
  bool _isLoading = true;
  final TextEditingController _evNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _evNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      // Fetch active drivers (case-insensitive)
      final activeResponse = await Supabase.instance.client
          .from('users')
          .select()
          .ilike('status', 'active')
          .order('name');

      // Fetch inactive drivers (case-insensitive)
      final inactiveResponse = await Supabase.instance.client
          .from('users')
          .select()
          .ilike('status', 'inactive');

      setState(() {
        _activeDrivers = List<Map<String, dynamic>>.from(activeResponse);
        _inactiveDrivers = List<Map<String, dynamic>>.from(inactiveResponse);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading drivers: $e');
      setState(() => _isLoading = false);
      _showMessage('Error loading drivers');
    }
  }

  Future<void> _deactivateDriver() async {
    final evNumber = _evNumberController.text.trim().toUpperCase();
    if (evNumber.isEmpty) {
      _showMessage('Please enter an EV Number');
      return;
    }

    try {
      // Find active driver (case-insensitive)
      final driverResponse = await Supabase.instance.client
          .from('users')
          .select()
          .eq('ev_registration_no', evNumber)
          .ilike('status', 'active');

      if (driverResponse.isEmpty) {
        _showMessage('No active driver found with EV Number: $evNumber');
        return;
      }

      // Deactivate driver
      await Supabase.instance.client
          .from('users')
          .update({
            'status': 'Inactive',
            'last_use': DateTime.now().toIso8601String(),
          })
          .eq('ev_registration_no', evNumber);

      _showMessage('Driver deactivated successfully');
      _evNumberController.clear();
      _loadDrivers(); // Refresh lists
    } catch (e) {
      print('Error deactivating driver: $e');
      _showMessage('Error deactivating driver');
    }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B3E3E)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Text(
                      'EV Drivers ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.people),
                  ],
                ),
                Text(
                  'Total: ${_activeDrivers.length}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Active drivers table
          Expanded(
            flex: 3,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Table header
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(2),
                        4: FlexColumnWidth(1),
                        5: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          children: [
                            _tableHeader('Name'),
                            _tableHeader('Role'),
                            _tableHeader('EV Number'),
                            _tableHeader('Email'),
                            _tableHeader('Status'),
                            _tableHeader('Action'),
                          ],
                        ),
                      ],
                    ),

                    // Table body
                    Expanded(
                      child:
                          _activeDrivers.isEmpty
                              ? Center(child: Text('No active drivers found'))
                              : ListView.builder(
                                itemCount: _activeDrivers.length,
                                itemBuilder: (context, index) {
                                  final driver = _activeDrivers[index];
                                  return Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(2),
                                      1: FlexColumnWidth(1.5),
                                      2: FlexColumnWidth(1.5),
                                      3: FlexColumnWidth(2),
                                      4: FlexColumnWidth(1),
                                      5: FlexColumnWidth(1),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                        ),
                                        children: [
                                          _tableCell(driver['name'] ?? ''),
                                          _tableCell(driver['role'] ?? ''),
                                          _tableCell(
                                            driver['ev_registration_no'] ?? '',
                                          ),
                                          _tableCell(driver['email'] ?? ''),
                                          _tableCell(driver['status'] ?? ''),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8.0,
                                            ),
                                            child: TextButton(
                                              onPressed: () {
                                                // View logs action
                                              },
                                              child: const Text(
                                                'View Logs',
                                                style: TextStyle(
                                                  color: Color(0xFF8B3E3E),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bottom section (Deactivate + Inactive drivers)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                // Deactivate driver section
                Expanded(
                  child: Card(
                    color: Colors.grey.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              'Deactivate EV Driver',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _evNumberController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter EV Number',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.arrow_forward,
                                    color: Colors.grey.shade900,
                                  ),
                                  onPressed: _deactivateDriver,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Inactive drivers
                Expanded(
                  child: Card(
                    color: const Color(0xFF8B3E3E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              'Inactive EV Driver',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            child:
                                _inactiveDrivers.isEmpty
                                    ? const Center(
                                      child: Text(
                                        'No inactive drivers',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: _inactiveDrivers.length,
                                      itemBuilder: (context, index) {
                                        final driver = _inactiveDrivers[index];
                                        final lastUse =
                                            driver['last_use'] != null
                                                ? DateFormat(
                                                  'MMMM d, y',
                                                ).format(
                                                  DateTime.parse(
                                                    driver['last_use'],
                                                  ),
                                                )
                                                : 'Unknown';

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4.0,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                driver['ev_number'] ?? '',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                lastUse,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(text),
    );
  }
}

class UsersContent extends StatelessWidget {
  const UsersContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const UsersScreen();
  }
}
