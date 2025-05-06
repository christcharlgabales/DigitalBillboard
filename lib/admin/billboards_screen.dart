import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BillboardsScreen extends StatefulWidget {
  const BillboardsScreen({super.key});

  @override
  State<BillboardsScreen> createState() => _BillboardsScreenState();
}

class _BillboardsScreenState extends State<BillboardsScreen> {
  List<Map<String, dynamic>> _billboards = [];
  bool _isLoading = true;
  bool _mapView = true;
  Set<Marker> _markers = {};
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();
    _loadBillboards();
  }

  Future<void> _loadBillboards() async {
    try {
      final response = await Supabase.instance.client
          .from('billboards')
          .select('*')
          .order('name');

      setState(() {
        _billboards = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      _createMarkers();
    } catch (e) {
      print('Error loading billboards: $e');
      setState(() => _isLoading = false);
      _showMessage('Error loading billboards');
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
              snippet: billboard['active'] == true ? 'Active' : 'Inactive',
            ),
          );

          _markers.add(marker);
        } catch (e) {
          print('Error creating marker for billboard ${billboard['id']}: $e');
        }
      }
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

  void _toggleView() {
    setState(() {
      _mapView = !_mapView;
    });
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
                'Billboard Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  // View toggle
                  ToggleButtons(
                    isSelected: [_mapView, !_mapView],
                    onPressed: (index) {
                      setState(() {
                        _mapView = index == 0;
                      });
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Icon(Icons.map),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Icon(Icons.list),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  // Add billboard button
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Add new billboard functionality
                    },
                    icon: Icon(Icons.add),
                    label: Text('Add Billboard'),
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
        Expanded(child: _mapView ? _buildMapView() : _buildListView()),
      ],
    );
  }

  Widget _buildMapView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
    );
  }

  Widget _buildListView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: _billboards.length,
            itemBuilder: (context, index) {
              final billboard = _billboards[index];
              final isActive = billboard['active'] == true;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive ? Colors.green : Colors.red,
                  child: Icon(Icons.location_on, color: Colors.white),
                ),
                title: Text(
                  billboard['name'] ?? 'Billboard ${billboard['id']}',
                ),
                subtitle: Text(
                  'Location: ${billboard['latitude']}, ${billboard['longitude']}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: isActive,
                      activeColor: const Color(0xFF8B3E3E),
                      onChanged: (value) {
                        // TODO: Toggle billboard active status
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        // TODO: Edit billboard
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        // TODO: Delete billboard
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// BillboardsContent widget that's used within the dashboard
class BillboardsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const BillboardsScreen();
  }
}
