import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

class BillboardTrackingScreen extends StatefulWidget {
  const BillboardTrackingScreen({super.key});

  @override
  State<BillboardTrackingScreen> createState() =>
      _BillboardTrackingScreenState();
}

class _BillboardTrackingScreenState extends State<BillboardTrackingScreen> {
  List<Map<String, dynamic>> billboards = [];
  Map<String, dynamic>? selectedBillboard;
  bool isTracking = false;
  StreamSubscription<Position>? _positionStream;
  LatLng? currentPosition;
  bool hasTriggered = false;

  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    insertDefaultBillboard();
    fetchBillboards();
  }

  Future<void> insertDefaultBillboard() async {
    const double latitude = 8.954462; // ~500m north of 8.949962
    const double longitude = 125.581300;

    final existing = await Supabase.instance.client
        .from('billboards')
        .select()
        .eq('name', 'Billboard 1 - Butuan North');

    if (existing.isEmpty) {
      await Supabase.instance.client.from('billboards').insert({
        'id': const Uuid().v4(), // Generate UUID
        'name': 'Billboard 1 - Butuan North',
        'latitude': latitude,
        'longitude': longitude,
      });
    }
  }

  Future<void> fetchBillboards() async {
    final response = await Supabase.instance.client.from('billboards').select();
    setState(() {
      billboards = List<Map<String, dynamic>>.from(response);
    });
  }

  void startTracking() async {
    if (selectedBillboard == null) return;

    setState(() => isTracking = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      final currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() => currentPosition = currentLatLng);

      mapController.move(currentLatLng, mapController.camera.zoom);

      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        selectedBillboard!['latitude'] as double,
        selectedBillboard!['longitude'] as double,
      );

      print('Distance: $distance meters');

      if (distance < 50 && !hasTriggered) {
        await Supabase.instance.client.from('alerts').insert({
          'user_id': userId,
          'billboard_id': selectedBillboard!['id'],
        });

        hasTriggered = true;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('📢 Alert triggered!')));
      } else if (distance >= 50 && hasTriggered) {
        await Supabase.instance.client.from('alerts').delete().match({
          'user_id': userId,
          'billboard_id': selectedBillboard!['id'],
        });

        hasTriggered = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Alert cleared!')));
      }
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    setState(() {
      isTracking = false;
      hasTriggered = false;
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billboardLatLng =
        selectedBillboard == null
            ? null
            : LatLng(
              selectedBillboard!['latitude'] as double,
              selectedBillboard!['longitude'] as double,
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Billboard'),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<Map<String, dynamic>>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Choose a billboard',
              ),
              value: selectedBillboard,
              items:
                  billboards.map((billboard) {
                    return DropdownMenuItem(
                      value: billboard,
                      child: Text(billboard['name']),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() => selectedBillboard = value);
                final newLatLng = LatLng(
                  value!['latitude'] as double,
                  value['longitude'] as double,
                );
                mapController.move(newLatLng, 17);
              },
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentPosition ?? const LatLng(0, 0),
                initialZoom: 15,
                interactionOptions: const InteractionOptions(),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                if (billboardLatLng != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: billboardLatLng,
                        color: Colors.red.withOpacity(0.3),
                        borderStrokeWidth: 1,
                        borderColor: Colors.red,
                        radius: 50,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (billboardLatLng != null)
                      Marker(
                        point: billboardLatLng,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    if (currentPosition != null)
                      Marker(
                        point: currentPosition!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                isTracking
                    ? ElevatedButton.icon(
                      onPressed: stopTracking,
                      icon: const Icon(Icons.pause),
                      label: const Text('Stop Tracking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                    : ElevatedButton.icon(
                      onPressed:
                          selectedBillboard == null ? null : startTracking,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Tracking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
