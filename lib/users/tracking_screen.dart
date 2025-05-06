import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrackingScreen extends StatefulWidget {
  final double billboardLat;
  final double billboardLng;
  final String billboardId;

  const TrackingScreen({
    super.key,
    required this.billboardLat,
    required this.billboardLng,
    required this.billboardId,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Stream<Position>? positionStream;
  bool isTracking = false;
  bool alertTriggered = false;

  void startTracking() {
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
    positionStream!.listen((Position position) async {
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.billboardLat,
        widget.billboardLng,
      );

      if (distance < 50 && !alertTriggered) {
        await triggerAlert(position);
        setState(() {
          alertTriggered = true;
        });
      }
    });

    setState(() {
      isTracking = true;
    });
  }

  Future<void> triggerAlert(Position position) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    await Supabase.instance.client.from('alerts').insert({
      'user_id': userId,
      'billboard_id': widget.billboardId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'triggered_at': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("🚨 Alert Triggered!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tracking...")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isTracking)
              ElevatedButton(
                onPressed: startTracking,
                child: const Text("▶ START"),
              )
            else if (alertTriggered)
              const Text(
                "✅ Within range. Alert sent!",
                style: TextStyle(fontSize: 20),
              )
            else
              const Text(
                "📡 Tracking your location...",
                style: TextStyle(fontSize: 20),
              ),
          ],
        ),
      ),
    );
  }
}
