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
              _isLoading = false;
            });
          } catch (e) {
            print('Error fetching additional logs: $e');
            setState(() {
              _logs = alerts;
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _logs = alerts;
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
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading logs: $e');
      setState(() {
        _logs = [];
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
        backgroundColor: const Color(0xFF8B3E3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _getLogTypeColor(String type) {
    switch (type) {
      case 'Emergency':
        return Colors.red;
      case 'System':
        return Colors.blue;
      case 'User':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Icon _getLogTypeIcon(String type) {
    switch (type) {
      case 'Emergency':
        return Icon(Icons.warning_amber, color: Colors.white);
      case 'System':
        return Icon(Icons.computer, color: Colors.white);
      case 'User':
        return Icon(Icons.person, color: Colors.white);
      default:
        return Icon(Icons.info, color: Colors.white);
    }
  }

  void _filterLogs(String type) {
    setState(() {
      _selectedLogType = type;
      _isLoading = true;
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B3E3E)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Logs',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              // Filter dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedLogType,
                  icon: const Icon(Icons.filter_list),
                  underline: SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _filterLogs(newValue);
                    }
                  },
                  items:
                      _logTypes.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _logs.isEmpty
                  ? Center(child: Text('No logs found'))
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final timestamp = DateFormat(
                              'MMM d, y HH:mm',
                            ).format(DateTime.parse(log['created_at']));
                            final logType = log['type'] ?? 'Unknown';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getLogTypeColor(logType),
                                child: _getLogTypeIcon(logType),
                              ),
                              title: Text(
                                log['message'] ??
                                    log['description'] ??
                                    'Log entry',
                              ),
                              subtitle: Row(
                                children: [
                                  Text(timestamp),
                                  SizedBox(width: 10),
                                  Chip(
                                    label: Text(
                                      logType,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                    backgroundColor: _getLogTypeColor(logType),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  if (log['user'] != null) ...[
                                    SizedBox(width: 10),
                                    Text('User: ${log['user']}'),
                                  ],
                                ],
                              ),
                              isThreeLine: true,
                              dense: true,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
        ),
      ],
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
