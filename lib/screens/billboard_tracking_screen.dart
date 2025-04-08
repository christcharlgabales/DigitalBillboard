import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillboardTrackingScreen extends StatefulWidget {
  const BillboardTrackingScreen({super.key});

  @override
  State<BillboardTrackingScreen> createState() =>
      _BillboardTrackingScreenState();
}

class _BillboardTrackingScreenState extends State<BillboardTrackingScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> billboards = [];
  Map<String, dynamic>? selectedBillboard;
  bool isTracking = false;
  Stream<Position>? positionStream;

  @override
  void initState() {
    super.initState();
    _loadBillboards();
  }

  Future<void> _loadBillboards() async {
    final response = await supabase.from('billboards').select();
    setState(() {
      billboards = List<Map<String, dynamic>>.from(response);
    });
  }

  void _startTracking() {
    final userId = supabase.auth.currentUser!.id;

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    positionStream!.listen((position) async {
      final currentLat = position.latitude;
      final currentLng = position.longitude;
      final billboardLat = selectedBillboard!['latitude'];
      final billboardLng = selectedBillboard!['longitude'];

      double distance = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        billboardLat,
        billboardLng,
      );

      print('Distance: $distance m');

      if (distance < 50) {
        // ✅ Within range, trigger alert
        await supabase.from('alerts').insert({
          'user_id': userId,
          'billboard_id': selectedBillboard!['id'],
        });
        setState(() {
          isTracking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🚨 Alert triggered within 50 meters!')),
        );
      }
    });

    setState(() {
      isTracking = true;
    });
  }

  Widget _buildBillboardCard(Map<String, dynamic> billboard) {
    return ListTile(
      title: Text(billboard['name']),
      subtitle: Text('Location: ${billboard['location']}'),
      onTap: () {
        setState(() {
          selectedBillboard = billboard;
        });
      },
      trailing: Icon(
        Icons.radio_button_checked,
        color:
            selectedBillboard?['id'] == billboard['id']
                ? Colors.redAccent
                : Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Billboard & Track'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            selectedBillboard == null
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a Billboard:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: billboards.map(_buildBillboardCard).toList(),
                      ),
                    ),
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Billboard:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        title: Text(selectedBillboard!['name']),
                        subtitle: Text(
                          'Lat: ${selectedBillboard!['latitude']}, Lng: ${selectedBillboard!['longitude']}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.gps_fixed),
                      label: Text(
                        isTracking ? 'Tracking...' : 'Start Tracking',
                      ),
                      onPressed: isTracking ? null : _startTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
