import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tracking_screen.dart';

class BillboardSelectionScreen extends StatefulWidget {
  const BillboardSelectionScreen({super.key});

  @override
  State<BillboardSelectionScreen> createState() =>
      _BillboardSelectionScreenState();
}

class _BillboardSelectionScreenState extends State<BillboardSelectionScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> billboards = [];
  dynamic selectedBillboard;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    fetchBillboards();
  }

  Future<void> fetchBillboards() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    try {
      final response = await supabase.from('billboards').select();
      setState(() {
        billboards = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load billboards: $e")));
    }
  }

  void startTracking() {
    if (selectedBillboard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a billboard to continue.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => TrackingScreen(
              billboardLat: selectedBillboard['latitude'],
              billboardLng: selectedBillboard['longitude'],
              billboardId: selectedBillboard['id'],
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select a Billboard"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasError
                ? const Center(child: Text("Error loading billboards."))
                : billboards.isEmpty
                ? const Center(child: Text("No billboards available."))
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Choose a billboard",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<dynamic>(
                      items:
                          billboards.map<DropdownMenuItem<dynamic>>((
                            billboard,
                          ) {
                            return DropdownMenuItem(
                              value: billboard,
                              child: Text(
                                '${billboard['name']} - ${billboard['location']}',
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedBillboard = value;
                        });
                      },
                      value: selectedBillboard,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed:
                            selectedBillboard == null ? null : startTracking,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Start Tracking"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
