import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  LatLng? currentPosition;
  bool isLoading = true;
  String? errorMessage;

  // Maps to track state per billboard
  Map<String, bool> trackingStatus = {};
  Map<String, bool> triggerStatus = {};
  Map<String, StreamSubscription<Position>> positionStreams = {};

  GoogleMapController? _mapController;

  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    insertDefaultBillboard();
    fetchBillboards();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          errorMessage = 'Location services are disabled.';
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            errorMessage = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          errorMessage = 'Location permissions are permanently denied.';
        });
        return;
      }

      // Get the current position
      final Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to get current location: $e';
        });
      }
    }
  }

  Future<void> insertDefaultBillboard() async {
    try {
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
    } catch (e) {
      print('Error inserting default billboard: $e');
    }
  }

  Future<void> fetchBillboards() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await Supabase.instance.client
          .from('billboards')
          .select()
          .order('name');

      if (mounted) {
        setState(() {
          if (response != null) {
            billboards = List<Map<String, dynamic>>.from(response);
          } else {
            billboards = [];
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load billboards: $e';
          isLoading = false;
        });
      }
    }
  }

  void startTracking() async {
    if (selectedBillboard == null) return;
    if (_mapController == null) return;

    final String billboardId = selectedBillboard!['id'];

    setState(() {
      trackingStatus[billboardId] = true;
    });

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        errorMessage = 'User is not logged in';
        trackingStatus[billboardId] = false;
      });
      return;
    }

    final userId = currentUser.id;

    positionStreams[billboardId] = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) async {
        if (!mounted) return;

        final newPosition = LatLng(position.latitude, position.longitude);

        setState(() {
          currentPosition = newPosition;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));

        // Calculate distance for this specific billboard
        final billboardData = billboards.firstWhere(
          (b) => b['id'] == billboardId,
          orElse: () => <String, dynamic>{},
        );

        if (billboardData.isEmpty ||
            billboardData['latitude'] == null ||
            billboardData['longitude'] == null) {
          return;
        }

        final double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          billboardData['latitude'] as double,
          billboardData['longitude'] as double,
        );

        print('Distance to ${billboardData['name']}: $distance meters');

        // Use 50 meters as the radius
        if (distance < 50 && !(triggerStatus[billboardId] ?? false)) {
          try {
            await Supabase.instance.client.from('alerts').insert({
              'user_id': userId,
              'billboard_id': billboardId,
            });

            if (mounted) {
              setState(() {
                triggerStatus[billboardId] = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '📢 Alert triggered for ${billboardData['name']}!',
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to trigger alert: $e')),
              );
            }
          }
        } else if (distance >= 50 && (triggerStatus[billboardId] ?? false)) {
          try {
            await Supabase.instance.client.from('alerts').delete().match({
              'user_id': userId,
              'billboard_id': billboardId,
            });

            if (mounted) {
              setState(() {
                triggerStatus[billboardId] = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Alert cleared for ${billboardData['name']}!',
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to clear alert: $e')),
              );
            }
          }
        }

        updateMap();
      },
      onError: (dynamic error) {
        if (mounted) {
          setState(() {
            errorMessage = 'Location stream error: $error';
            trackingStatus[billboardId] = false;
          });
        }
      },
    );
  }

  void stopTracking() {
    if (selectedBillboard == null) return;

    final String billboardId = selectedBillboard!['id'];

    positionStreams[billboardId]?.cancel();
    positionStreams.remove(billboardId);

    setState(() {
      trackingStatus[billboardId] = false;
      // We don't reset triggerStatus here as it will be cleared when
      // user gets back in range
    });
  }

  void updateMap() {
    if (!mounted) return;

    _markers.clear();
    _circles.clear();

    // Add markers and circles for all billboards
    for (final billboard in billboards) {
      if (billboard['latitude'] != null && billboard['longitude'] != null) {
        final billboardLatLng = LatLng(
          billboard['latitude'] as double,
          billboard['longitude'] as double,
        );

        final String billboardId = billboard['id'];
        final bool isTracking = trackingStatus[billboardId] ?? false;

        // Use a different hue for tracked billboards
        final double markerHue =
            isTracking ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed;

        _markers.add(
          Marker(
            markerId: MarkerId('billboard_$billboardId'),
            position: billboardLatLng,
            infoWindow: InfoWindow(
              title: billboard['name'] ?? 'Billboard',
              snippet: isTracking ? 'Currently tracking' : 'Not tracking',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          ),
        );

        if (isTracking) {
          _circles.add(
            Circle(
              circleId: CircleId('billboardRadius_$billboardId'),
              center: billboardLatLng,
              radius: 50, // 50 meters
              fillColor: Colors.green.withOpacity(0.3),
              strokeColor: Colors.green,
              strokeWidth: 2,
            ),
          );
        }
      }
    }

    // Add current user location marker
    if (currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: currentPosition!,
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    setState(() {});
  }

  @override
  void dispose() {
    // Cancel all active position streams
    for (final stream in positionStreams.values) {
      stream.cancel();
    }
    positionStreams.clear();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Default to Butuan if no current position
    final initialCameraPosition = CameraPosition(
      target: currentPosition ?? const LatLng(8.949962, 125.581300),
      zoom: 15,
    );

    final bool isCurrentBillboardTracking =
        selectedBillboard != null
            ? (trackingStatus[selectedBillboard!['id']] ?? false)
            : false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Billboard'),
        backgroundColor: Colors.redAccent,
      ),
      body:
          errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            errorMessage = null;
                          });
                          fetchBillboards();
                          _requestLocationPermission();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child:
                        isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonFormField<Map<String, dynamic>>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Choose a billboard',
                                border: OutlineInputBorder(),
                              ),
                              value: selectedBillboard,
                              hint: const Text('Select a billboard'),
                              items:
                                  billboards.isEmpty
                                      ? []
                                      : billboards.map((billboard) {
                                        final bool isTracking =
                                            trackingStatus[billboard['id']] ??
                                            false;
                                        return DropdownMenuItem<
                                          Map<String, dynamic>
                                        >(
                                          value: billboard,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  billboard['name'] ??
                                                      'Unnamed Billboard',
                                                ),
                                              ),
                                              if (isTracking)
                                                const Icon(
                                                  Icons.track_changes,
                                                  color: Colors.green,
                                                  size: 18,
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => selectedBillboard = value);
                                  if (_mapController != null &&
                                      value['latitude'] != null &&
                                      value['longitude'] != null) {
                                    _mapController!.animateCamera(
                                      CameraUpdate.newLatLng(
                                        LatLng(
                                          value['latitude'] as double,
                                          value['longitude'] as double,
                                        ),
                                      ),
                                    );
                                    _mapController!.animateCamera(
                                      CameraUpdate.zoomTo(17),
                                    );
                                  }
                                  updateMap();
                                }
                              },
                            ),
                  ),
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition: initialCameraPosition,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        updateMap();
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapToolbarEnabled: true,
                      zoomControlsEnabled: true,
                      markers: _markers,
                      circles: _circles,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child:
                        isCurrentBillboardTracking
                            ? ElevatedButton.icon(
                              onPressed: stopTracking,
                              icon: const Icon(Icons.pause),
                              label: const Text('Stop Tracking'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            )
                            : ElevatedButton.icon(
                              onPressed:
                                  selectedBillboard == null || isLoading
                                      ? null
                                      : startTracking,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Tracking'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                  ),
                  if (positionStreams.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 16.0,
                        left: 16.0,
                        right: 16.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tracking ${positionStreams.length} billboard${positionStreams.length > 1 ? 's' : ''}',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }
}
