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

  @override
  void initState() {
    super.initState();
    fetchBillboards();
  }

  Future<void> fetchBillboards() async {
    try {
      final response = await supabase.from('billboards').select();
      setState(() {
        billboards = response;
      });
    } catch (e) {
      debugPrint('Error fetching billboards: $e');
    }
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
        child: Column(
          children: [
            const Text("Choose a billboard"),
            const SizedBox(height: 8),
            DropdownButtonFormField<dynamic>(
              items:
                  billboards.map<DropdownMenuItem<dynamic>>((billboard) {
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
              decoration: const InputDecoration(border: UnderlineInputBorder()),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed:
                  selectedBillboard == null
                      ? null
                      : () {
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
                      },
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start Tracking"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
