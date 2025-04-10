import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'billboard_screen.dart'; // Import the new alert display screen

class BillboardSelectionScreen extends StatefulWidget {
  const BillboardSelectionScreen({super.key});

  @override
  State<BillboardSelectionScreen> createState() =>
      _BillboardSelectionScreenState();
}

class _BillboardSelectionScreenState extends State<BillboardSelectionScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> billboards = [];

  @override
  void initState() {
    super.initState();
    fetchBillboards();
  }

  Future<void> fetchBillboards() async {
    final response = await supabase.from('billboards').select();
    setState(() {
      billboards = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Billboard")),
      body: ListView.builder(
        itemCount: billboards.length,
        itemBuilder: (context, index) {
          final b = billboards[index];
          return Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.location_on),
              title: Text("Billboard: ${b['code']}"),
              subtitle: Text("Location: ${b['location']}"),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => BillboardScreen(
                            billboardId: b['id'],
                            billboardName: b['code'] ?? 'Unnamed',
                          ),
                    ),
                  );
                },
                child: const Text("ACTIVATE"),
              ),
            ),
          );
        },
      ),
    );
  }
}
