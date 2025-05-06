import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _selectedLogType = 'All';
  final List<String> _logTypes = ['All', 'Emergency', 'System', 'User'];
  final Color _primaryColor = const Color(0xFF8B3E3E);
  int _totalLogs = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      String query = 'emergency_alerts';
      if (_selectedLogType == 'System') {
        query = 'system_logs';
      } else if (_selectedLogType == 'User') {
        query = 'user_activity_logs';
      }

      // Default to emergency_alerts if the selected type is All or Emergency
      if (_selectedLogType == 'All' || _selectedLogType == 'Emergency') {
        final alertResponse = await Supabase.instance.client
            .from('emergency_alerts')
            .select('*, profiles(full_name)')
            .order('created_at', ascending: false)
            .limit(100);

        List<Map<String, dynamic>> alerts = List<Map<String, dynamic>>.from(
          alertResponse,
        );
        for (var alert in alerts) {
          alert['type'] = 'Emergency';
          alert['user'] = alert['profiles']?['full_name'] ?? 'Unknown';
        }

        if (_selectedLogType == 'All') {
          // If 'All' is selected, also fetch system logs and user activity
          try {
            final systemResponse = await Supabase.instance.client
                .from('system_logs')
                .select('*')
                .order('created_at', ascending: false)
                .limit(50);

            List<Map<String, dynamic>> systemLogs =
                List<Map<String, dynamic>>.from(systemResponse);
            for (var log in systemLogs) {
              log['type'] = 'System';
            }

            final userResponse = await Supabase.instance.client
                .from('user_activity_logs')
                .select('*, profiles(full_name)')
                .order('created_at', ascending: false)
                .limit(50);

            List<Map<String, dynamic>> userLogs =
                List<Map<String, dynamic>>.from(userResponse);
            for (var log in userLogs) {
              log['type'] = 'User';
              log['user'] = log['profiles']?['full_name'] ?? 'Unknown';
            }

            // Combine all logs and sort by date
            List<Map<String, dynamic>> allLogs = [
              ...alerts,
              ...systemLogs,
              ...userLogs,
            ];
            allLogs.sort(
              (a, b) => DateTime.parse(
                b['created_at'],
              ).compareTo(DateTime.parse(a['created_at'])),
            );

            setState(() {
              _logs = allLogs;
              _totalLogs = allLogs.length;
              _isLoading = false;
            });
          } catch (e) {
            print('Error fetching additional logs: $e');
            setState(() {
              _logs = alerts;
              _totalLogs = alerts.length;
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _logs = alerts;
            _totalLogs = alerts.length;
            _isLoading = false;
          });
        }
      } else {
        final response = await Supabase.instance.client
            .from(query)
            .select('*, profiles(full_name)')
            .order('created_at', ascending: false)
            .limit(100);

        List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(
          response,
        );
        for (var log in logs) {
          log['type'] = _selectedLogType;
          log['user'] = log['profiles']?['full_name'] ?? 'Unknown';
        }

        setState(() {
          _logs = logs;
          _totalLogs = logs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading logs: $e');
      setState(() {
        _logs = [];
        _totalLogs = 0;
        _isLoading = false;
      });
      _showMessage('Error loading logs: ${e.toString().substring(0, 100)}');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _primaryColor,
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Alert Logs',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          'i',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Total: $_totalLogs',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: Colors.black),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade800,
                          width: 1,
                        ),
                      ),
                    ),
                    children: [
                      _buildTableHeader('Date'),
                      _buildTableHeader('Time'),
                      _buildTableHeader('Billboard No.'),
                      _buildTableHeader('EV Number'),
                      _buildTableHeader('Type'),
                      _buildTableHeader('Result'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _logs.isEmpty
                      ? Center(
                        child: Text(
                          'No logs found',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final dateTime = DateTime.parse(log['created_at']);
                          final date = DateFormat(
                            'MM - dd - yyyy',
                          ).format(dateTime);
                          final time = DateFormat('h:mm a').format(dateTime);

                          // Handle different log formats
                          final billboardNo = log['billboard_id'] ?? 'BB - 001';
                          final evNumber =
                              log['ev_number'] ??
                              (log['vehicle_id'] ?? 'Unknown');
                          final type =
                              log['alert_type'] ??
                              (log['auto_manual'] ?? 'Unknown');
                          final result =
                              log['result'] ?? (log['status'] ?? 'Success');

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.2),
                                1: FlexColumnWidth(1),
                                2: FlexColumnWidth(1.2),
                                3: FlexColumnWidth(1.2),
                                4: FlexColumnWidth(1),
                                5: FlexColumnWidth(1),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade800,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    _buildTableCell(date),
                                    _buildTableCell(time),
                                    _buildTableCell(billboardNo),
                                    _buildTableCell(evNumber),
                                    _buildTableCell(type),
                                    _buildTableCell(result),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(
                    Icons.playlist_add_check,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Select',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    // Implement select functionality
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    // Implement clear functionality
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(text, style: TextStyle(color: Colors.white)),
    );
  }
}

// LogsContent widget that's used within the dashboard
class LogsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const LogsScreen();
  }
}
