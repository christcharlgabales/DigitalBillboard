import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillboardScreen extends StatefulWidget {
  final String billboardId;
  final String billboardName;

  const BillboardScreen({
    Key? key,
    required this.billboardId,
    required this.billboardName,
  }) : super(key: key);

  @override
  State<BillboardScreen> createState() => _BillboardScreenState();
}

class _BillboardScreenState extends State<BillboardScreen> {
  List<Map<String, dynamic>> alerts = [];

  @override
  void initState() {
    super.initState();
    listenToAlerts();
  }

  void listenToAlerts() {
    Supabase.instance.client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('billboard_id', widget.billboardId)
        .listen((data) {
          setState(() {
            alerts = data;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final hasAlert = alerts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Billboard: ${widget.billboardName}'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child:
            hasAlert
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 100),
                    const SizedBox(height: 20),
                    const Text(
                      '🚨 Emergency Vehicle Nearby!',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
                : const Text(
                  'No Alerts',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
      ),
    );
  }
}
