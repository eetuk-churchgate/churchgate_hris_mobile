import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../services/engagement_service.dart';

class ClockScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ClockScreen({super.key, required this.user});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  final _supabase = Supabase.instance.client;
  String _clockType = 'IN';
  String _locationName = 'Fetching location...';
  String _currentTime = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Clock In/Out');
    _updateTime();
    _getLocation();
  }

  void _updateTime() {
    setState(() => _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now()));
    Future.delayed(const Duration(seconds: 1), _updateTime);
  }

  Future<void> _getLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() => _locationName = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}');
    } catch (e) {
      setState(() => _locationName = 'WTC Abuja');
    }
  }

  Future<void> _clockInOut() async {
    setState(() => _loading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      await _supabase.from('gps_attendance').insert({
        'employee_id': widget.user['employee_id'],
        'clock_type': _clockType,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location_name': _locationName,
        'clock_time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'sync_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      setState(() => _clockType = _clockType == 'IN' ? 'OUT' : 'IN');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Clock ${_clockType == 'OUT' ? 'IN' : 'OUT'} recorded!'), backgroundColor: const Color(0xFF38a169)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to record. Try again.'), backgroundColor: Colors.red),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(title: const Text('⏰ Clock In / Out')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Churchgate Group', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('Attendance Clock', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _clockType == 'IN' ? const Color(0xFF38a169).withOpacity(0.1) : const Color(0xFFCC0000).withOpacity(0.1),
                  border: Border.all(color: _clockType == 'IN' ? const Color(0xFF38a169) : const Color(0xFFCC0000), width: 4),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_currentTime, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  Text(DateFormat('EEEE, MMM d').format(DateTime.now()), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 24),
              Text('📍 $_locationName', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 30),
              SizedBox(
                width: 200, height: 200,
                child: ElevatedButton(
                  onPressed: _loading ? null : _clockInOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _clockType == 'IN' ? const Color(0xFF38a169) : const Color(0xFFCC0000),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(30),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_clockType == 'IN' ? 'CLOCK IN' : 'CLOCK OUT', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Icon(_clockType == 'IN' ? Icons.login : Icons.logout, color: Colors.white, size: 30),
                        ]),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _infoColumn('Office', 'WTC Abuja'),
                    _infoColumn('Status', _clockType == 'IN' ? 'Clocking In' : 'Clocking Out'),
                    _infoColumn('Method', 'GPS'),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
    ]);
  }
}