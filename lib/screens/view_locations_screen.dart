import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting

class ViewLocationsScreen extends StatefulWidget {
  const ViewLocationsScreen({super.key});

  @override
  State<ViewLocationsScreen> createState() => _ViewLocationsScreenState();
}

class _ViewLocationsScreenState extends State<ViewLocationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _loading = false;
        });
        return;
      }

      // Updated query without .execute()
      final data = await _supabase
          .from('locations')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false);

      setState(() {
        _locations = List<Map<String, dynamic>>.from(data);
        for (var loc in _locations) {
          final rawTime = loc['timestamp'];
          final dt =
              DateTime.parse(
                rawTime,
              ).toLocal(); // Ensure time is converted to local

          print('RAW TIMESTAMP: $rawTime');
          print('AS LOCAL: ${dt.toLocal()}');
        }

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal(); // Ensure .toLocal()
      final formatter = DateFormat('MMM d, yyyy - h:mm a');
      return formatter.format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Locations'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              )
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loadLocations,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
              : _locations.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No locations found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tap the "Send My Location" button on the home screen',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadLocations,
                color: Colors.redAccent,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    final loc = _locations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                          ),
                        ),
                        title: Text(
                          'Lat: ${loc['latitude']?.toStringAsFixed(6)}, '
                          'Lng: ${loc['longitude']?.toStringAsFixed(6)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Recorded: ${_formatDateTime(loc['timestamp'])}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        onTap: () {
                          // Show more details in a dialog
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Location Details'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Latitude: ${loc['latitude']}'),
                                      Text('Longitude: ${loc['longitude']}'),
                                      Text(
                                        'Time: ${_formatDateTime(loc['timestamp'])}',
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
