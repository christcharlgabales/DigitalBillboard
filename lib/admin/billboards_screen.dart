// billboard_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BillboardsScreen extends StatefulWidget {
  const BillboardsScreen({super.key});

  @override
  State<BillboardsScreen> createState() => _BillboardsScreenState();
}

class _BillboardsScreenState extends State<BillboardsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _billboards = [];
  bool _isLoading = true;
  Set<Marker> _markers = {};
  Map<String, dynamic>? _selectedBillboard;
  late GoogleMapController mapController;

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBillboards();
  }

  Future<void> _loadBillboards() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase.from('billboards').select('*');
      setState(() {
        _billboards = List<Map<String, dynamic>>.from(response);
        _createMarkers();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading billboards: $e');
      _showMessage('Error loading billboards');
      setState(() => _isLoading = false);
    }
  }

  void _createMarkers() {
    _markers.clear();
    for (var billboard in _billboards) {
      if (billboard['latitude'] != null && billboard['longitude'] != null) {
        try {
          final double lat = double.parse(billboard['latitude'].toString());
          final double lng = double.parse(billboard['longitude'].toString());
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
              snippet: billboard['location'] ?? '',
              onTap: () {
                setState(() {
                  _selectedBillboard = billboard;
                });
              },
            ),
            onTap: () {
              setState(() {
                _selectedBillboard = billboard;
              });
            },
          );
          _markers.add(marker);
        } catch (e) {
          print('Error parsing coordinates for billboard ${billboard['id']}');
        }
      }
    }
  }

  Future<void> _addBillboard() async {
    final lat = _latController.text.trim();
    final lng = _lngController.text.trim();
    if (lat.isEmpty || lng.isEmpty) {
      _showMessage('Latitude and Longitude required');
      return;
    }

    try {
      await supabase.from('billboards').insert({
        'latitude': lat,
        'longitude': lng,
        'name': 'New Billboard',
        'location': 'Unknown Location',
        'image_url': '', // Optional: adjust based on schema
        'active': false,
      });
      _latController.clear();
      _lngController.clear();
      _showMessage('Billboard added');
      _loadBillboards();
    } catch (e) {
      print('Error adding billboard: $e');
      _showMessage('Failed to add billboard');
    }
  }

  Future<void> _deleteBillboard(int id) async {
    try {
      await supabase.from('billboards').delete().eq('id', id);
      _showMessage('Billboard deleted');
      _selectedBillboard = null;
      _loadBillboards();
    } catch (e) {
      print('Error deleting billboard: $e');
      _showMessage('Failed to delete billboard');
    }
  }

  Future<void> _toggleActiveStatus(Map<String, dynamic> billboard) async {
    final id = billboard['id'];
    final newStatus = !(billboard['active'] == true);
    try {
      await supabase
          .from('billboards')
          .update({'active': newStatus})
          .eq('id', id);
      _showMessage('Billboard status updated');
      _loadBillboards();
    } catch (e) {
      print('Error updating status: $e');
      _showMessage('Failed to update status');
    }
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B3E3E)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Welcome + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Welcome Back!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                '${DateTime.now().toLocal().toString().split(' ')[0]}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Map
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 250,
              child: GoogleMap(
                onMapCreated: (controller) {
                  mapController = controller;
                },
                initialCameraPosition: const CameraPosition(
                  target: LatLng(8.9526, 125.5298), // Butuan City
                  zoom: 13,
                ),
                markers: _markers,
                myLocationEnabled: false,
                zoomControlsEnabled: true,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Add New Billboard
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Billboard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lngController,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addBillboard,
                        child: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B3E3E),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Billboard Details Card
          if (_selectedBillboard != null)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBillboard!['location'] ?? 'Unknown Location',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Latitude: ${_selectedBillboard!['latitude']}'),
                    Text('Longitude: ${_selectedBillboard!['longitude']}'),
                    const SizedBox(height: 8),
                    if (_selectedBillboard!['image_url'] != null &&
                        _selectedBillboard!['image_url'] != '')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _selectedBillboard!['image_url'],
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _toggleActiveStatus(_selectedBillboard!);
                          },
                          icon: Icon(
                            _selectedBillboard!['active'] == true
                                ? Icons.toggle_on
                                : Icons.toggle_off,
                          ),
                          label: Text(
                            _selectedBillboard!['active'] == true
                                ? 'Deactivate'
                                : 'Activate',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B3E3E),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            _deleteBillboard(_selectedBillboard!['id']);
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
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

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }
}
