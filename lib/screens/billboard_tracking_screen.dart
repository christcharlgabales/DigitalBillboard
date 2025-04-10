import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    fetchBillboards();
  }

  Future<void> fetchBillboards() async {
    final response = await Supabase.instance.client.from('billboards').select();
    setState(() {
      billboards = List<Map<String, dynamic>>.from(response);
    });
  }

  void startTracking() {
    if (selectedBillboard == null) return;

    setState(() => isTracking = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;
    bool hasTriggered = false;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        selectedBillboard!['latitude'],
        selectedBillboard!['longitude'],
      );

      print('Distance: $distance meters');

      if (distance < 50 && !hasTriggered) {
        // Trigger alert if not already triggered
        await Supabase.instance.client.from('alerts').insert({
          'user_id': userId,
          'billboard_id': selectedBillboard!['id'],
        });

        hasTriggered = true;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('📢 Alert triggered!')));
      } else if (distance >= 50 && hasTriggered) {
        // Remove alert if user moves out of radius
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
    setState(() => isTracking = false);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Billboard'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<Map<String, dynamic>>(
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
              onChanged: (value) => setState(() => selectedBillboard = value),
            ),
            const SizedBox(height: 30),
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
                  onPressed: selectedBillboard == null ? null : startTracking,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Tracking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
