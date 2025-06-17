import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class WebBillboardDashboard extends StatefulWidget {
  const WebBillboardDashboard({super.key});

  @override
  State<WebBillboardDashboard> createState() => _WebBillboardDashboardState();
}

class _WebBillboardDashboardState extends State<WebBillboardDashboard>
    with TickerProviderStateMixin {
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
  bool _mapInitialized = false;
  bool _isGlobalTracking = false;

  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};

  // Slider animation controller
  late AnimationController _sliderController;
  late Animation<double> _sliderAnimation;
  bool _isSliderActive = false;

  // Selected billboard for activation
  Map<String, dynamic>? _activationBillboard;

  @override
  void initState() {
    super.initState();
    _sliderController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sliderAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sliderController, curve: Curves.easeInOut),
    );

    insertDefaultBillboard();
    fetchBillboards();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _sliderController.dispose();
    for (final stream in positionStreams.values) {
      stream.cancel();
    }
    positionStreams.clear();
    if (_mapInitialized && _mapController != null) {
      _mapController!.dispose();
    }
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
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
      const double latitude = 8.954462;
      const double longitude = 125.581300;

      final existing = await Supabase.instance.client
          .from('billboards')
          .select()
          .eq('name', 'Billboard 1 - Butuan North');

      if (existing.isEmpty) {
        await Supabase.instance.client.from('billboards').insert({
          'id': const Uuid().v4(),
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

        if (_mapInitialized) {
          updateMap();
        }
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

  void _onSliderChanged(double value) {
    if (value >= 0.9 && !_isSliderActive) {
      _isSliderActive = true;
      _sliderController.forward();
      _toggleGlobalTracking();
    } else if (value < 0.1 && _isSliderActive) {
      _isSliderActive = false;
      _sliderController.reverse();
      _stopGlobalTracking();
    }
  }

  void _toggleGlobalTracking() {
    if (_isGlobalTracking) {
      _stopGlobalTracking();
    } else {
      _startGlobalTracking();
    }
  }

  void _startGlobalTracking() {
    setState(() {
      _isGlobalTracking = true;
    });

    // Start tracking all billboards
    for (final billboard in billboards) {
      final String billboardId = billboard['id'];
      if (!trackingStatus.containsKey(billboardId) ||
          !(trackingStatus[billboardId] ?? false)) {
        setState(() {
          selectedBillboard = billboard;
        });
        startTracking();
      }
    }
  }

  void _stopGlobalTracking() {
    setState(() {
      _isGlobalTracking = false;
    });

    // Stop tracking all billboards
    final List<String> billboardIds = trackingStatus.keys.toList();
    for (final billboardId in billboardIds) {
      stopTrackingById(billboardId);
    }
  }

  void startTracking() async {
    if (selectedBillboard == null) return;

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

        if (_mapInitialized && _mapController != null) {
          try {
            await _mapController!.animateCamera(
              CameraUpdate.newLatLng(newPosition),
            );
          } catch (e) {
            print('Error animating camera: $e');
          }
        }

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

        if (distance < 50 && !(triggerStatus[billboardId] ?? false)) {
          await _triggerAlert(billboardId, userId, billboardData);
        } else if (distance >= 50 && (triggerStatus[billboardId] ?? false)) {
          await _clearAlert(billboardId, userId, billboardData);
        }

        if (_mapInitialized) {
          updateMap();
        }
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

    if (_mapInitialized) {
      updateMap();
    }
  }

  Future<void> _triggerAlert(
    String billboardId,
    String userId,
    Map<String, dynamic> billboardData,
  ) async {
    try {
      await Supabase.instance.client.from('alerts').insert({
        'user_id': userId,
        'billboard_id': billboardId,
        'triggered_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          triggerStatus[billboardId] = true;
        });
        _showAlertNotification(
          'Alert triggered for ${billboardData['name']}!',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showAlertNotification('Failed to trigger alert: $e', isSuccess: false);
      }
    }
  }

  Future<void> _clearAlert(
    String billboardId,
    String userId,
    Map<String, dynamic> billboardData,
  ) async {
    try {
      await Supabase.instance.client.from('alerts').delete().match({
        'user_id': userId,
        'billboard_id': billboardId,
      });

      if (mounted) {
        setState(() {
          triggerStatus[billboardId] = false;
        });
        _showAlertNotification(
          'Alert cleared for ${billboardData['name']}!',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showAlertNotification('Failed to clear alert: $e', isSuccess: false);
      }
    }
  }

  void _showAlertNotification(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void stopTrackingById(String billboardId) {
    positionStreams[billboardId]?.cancel();
    positionStreams.remove(billboardId);

    setState(() {
      trackingStatus[billboardId] = false;
    });

    if (_mapInitialized) {
      updateMap();
    }
  }

  void _onMarkerTap(Map<String, dynamic> billboard) {
    setState(() {
      _activationBillboard = billboard;
    });
    _showBillboardActivationDialog(billboard);
  }

  void _showBillboardActivationDialog(Map<String, dynamic> billboard) {
    final String billboardId = billboard['id'];
    final bool isTracking = trackingStatus[billboardId] ?? false;
    final bool isTriggered = triggerStatus[billboardId] ?? false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.campaign, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      billboard['name'] ?? 'Billboard',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      billboard['id']?.toString().substring(0, 8) ?? 'BB-XXX',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location: ${billboard['latitude']?.toStringAsFixed(4)}, ${billboard['longitude']?.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusChip(
                      'Tracking',
                      isTracking,
                      isTracking ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusChip(
                      'Alert',
                      isTriggered,
                      isTriggered ? Colors.orange : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _manuallyActivateBillboard(billboard);
              },
              icon: const Icon(Icons.flash_on),
              label: const Text('ACTIVATE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(String label, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? color : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manuallyActivateBillboard(
    Map<String, dynamic> billboard,
  ) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _showAlertNotification('User is not logged in', isSuccess: false);
      return;
    }

    final String billboardId = billboard['id'];
    final String userId = currentUser.id;

    try {
      // Check if alert already exists
      final existing = await Supabase.instance.client
          .from('alerts')
          .select()
          .eq('user_id', userId)
          .eq('billboard_id', billboardId);

      if (existing.isNotEmpty) {
        // Clear existing alert
        await Supabase.instance.client.from('alerts').delete().match({
          'user_id': userId,
          'billboard_id': billboardId,
        });

        setState(() {
          triggerStatus[billboardId] = false;
        });

        _showAlertNotification(
          'Alert cleared for ${billboard['name']}!',
          isSuccess: true,
        );
      } else {
        // Create new alert
        await Supabase.instance.client.from('alerts').insert({
          'user_id': userId,
          'billboard_id': billboardId,
          'triggered_at': DateTime.now().toUtc().toIso8601String(),
        });

        setState(() {
          triggerStatus[billboardId] = true;
        });

        _showAlertNotification(
          'Alert manually activated for ${billboard['name']}!',
          isSuccess: true,
        );
      }

      updateMap();
    } catch (e) {
      _showAlertNotification(
        'Failed to activate billboard: $e',
        isSuccess: false,
      );
    }
  }

  void updateMap() {
    if (!mounted || !_mapInitialized || _mapController == null) return;

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
        final bool isTriggered = triggerStatus[billboardId] ?? false;

        // Use different colors based on status
        final double markerHue =
            isTriggered
                ? BitmapDescriptor.hueOrange
                : isTracking
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed;

        _markers.add(
          Marker(
            markerId: MarkerId('billboard_$billboardId'),
            position: billboardLatLng,
            infoWindow: InfoWindow(
              title: billboard['name'] ?? 'Billboard',
              snippet:
                  isTriggered
                      ? 'Alert Triggered!'
                      : isTracking
                      ? 'Currently tracking'
                      : 'Tap to activate',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
            onTap: () => _onMarkerTap(billboard),
          ),
        );

        if (isTracking) {
          _circles.add(
            Circle(
              circleId: CircleId('billboardRadius_$billboardId'),
              center: billboardLatLng,
              radius: 50,
              fillColor: (isTriggered ? Colors.orange : Colors.green)
                  .withOpacity(0.3),
              strokeColor: isTriggered ? Colors.orange : Colors.green,
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
          infoWindow: const InfoWindow(title: 'Emergency Vehicle'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapInitialized = true;
    updateMap();
  }

  Widget _buildSlideToStartButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              _isGlobalTracking
                  ? [Colors.green[400]!, Colors.green[600]!]
                  : [Colors.red[400]!, Colors.red[600]!],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (_isGlobalTracking ? Colors.green : Colors.red).withOpacity(
              0.3,
            ),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background track
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.black.withOpacity(0.1),
            ),
          ),
          // Slider thumb
          AnimatedBuilder(
            animation: _sliderAnimation,
            builder: (context, child) {
              return Positioned(
                left:
                    4 +
                    (_sliderAnimation.value *
                        (MediaQuery.of(context).size.width * 0.9 - 68)),
                top: 4,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final RenderBox box =
                        context.findRenderObject() as RenderBox;
                    final double localX =
                        box.globalToLocal(details.globalPosition).dx;
                    final double progress =
                        (localX - 30) / (box.size.width - 60);
                    _onSliderChanged(progress.clamp(0.0, 1.0));
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isGlobalTracking ? Icons.pause : Icons.play_arrow,
                      color: _isGlobalTracking ? Colors.green : Colors.red,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
          // Text
          Center(
            child: Text(
              _isGlobalTracking ? 'TRACKING ACTIVE' : 'START >>> TRACKING',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCameraPosition = CameraPosition(
      target: currentPosition ?? const LatLng(8.949962, 125.581300),
      zoom: 15,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.warning, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'ALERT TO DIVERT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body:
          errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            errorMessage = null;
                          });
                          fetchBillboards();
                          _requestLocationPermission();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : Column(
                children: [
                  // Map Section
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: GoogleMap(
                        initialCameraPosition: initialCameraPosition,
                        onMapCreated: _onMapCreated,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        zoomControlsEnabled: false,
                        markers: _markers,
                        circles: _circles,
                        mapType: MapType.normal,
                      ),
                    ),
                  ),

                  // Status Information
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            'Billboards',
                            billboards.length.toString(),
                            Icons.campaign,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            'Tracking',
                            trackingStatus.values
                                .where((v) => v)
                                .length
                                .toString(),
                            Icons.track_changes,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            'Alerts',
                            triggerStatus.values
                                .where((v) => v)
                                .length
                                .toString(),
                            Icons.warning,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Slide to Start Button
                  Container(
                    margin: const EdgeInsets.all(16),
                    child: _buildSlideToStartButton(),
                  ),
                ],
              ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
