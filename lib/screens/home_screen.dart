import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home'), backgroundColor: Colors.blueAccent),
      body: Center(
        child: Text(
          'Welcome to Alert to Divert!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
