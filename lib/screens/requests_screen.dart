import '../services/engagement_service.dart';
import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const RequestsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Requests Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Full requests available on web app', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('hris.churchgate.com', style: TextStyle(color: Color(0xFFCC0000))),
          ],
        ),
      ),
    );
  }
}
