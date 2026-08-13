import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../services/location_service.dart';
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
  List<Map<String, dynamic>> _todayRecords = [];

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Clock In/Out');
    _updateTime();
    _getLocation();
    _checkTodayStatus();
  }

  void _updateTime() {
    setState(() => _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now()));
    Future.delayed(const Duration(seconds: 1), _updateTime);
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationName = 'Permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final isInOffice = LocationService.isWithinOffice(position.latitude, position.longitude);
      setState(() => _locationName = isInOffice ?? 'Outside Office');
    } catch (e) {
      setState(() => _locationName = 'WTC Abuja');
    }
  }

  Future<void> _checkTodayStatus() async {
    try {
      final empId = widget.user['employee_id']?.toString() ?? '';
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final records = await _supabase
          .from('gps_attendance')
          .select('*')
          .eq('employee_id', empId)
          .eq('sync_date', today)
          .order('created_at', ascending: true);

      if (records.isNotEmpty) {
        _todayRecords = List<Map<String, dynamic>>.from(records);
        final hasClockedIn = records.any((r) => r['clock_type'] == 'In');
        final hasClockedOut = records.any((r) => r['clock_type'] == 'Out');

        if (hasClockedIn && !hasClockedOut) {
          setState(() => _clockType = 'OUT');
        } else if (hasClockedIn && hasClockedOut) {
          setState(() => _clockType = 'DONE');
        }
      }
    } catch (_) {}
  }

  Future<void> _clockInOut() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to clock in/out'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnWifi = connectivityResult == ConnectivityResult.wifi;

      final result = await LocationService.submitGPSClock(
        widget.user['employee_id']?.toString() ?? '',
        widget.user['name']?.toString() ?? '',
        _clockType == 'IN' ? 'In' : 'Out',
        position.latitude,
        position.longitude,
        ipAddress: isOnWifi ? '192.168.100.1' : null,
      );

      await _checkTodayStatus();
      setState(() => _locationName = result['location'] as String? ?? 'Remote');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: result['success'] == true ? const Color(0xFF38a169) : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _clockType == 'DONE';
    final buttonColor = _clockType == 'IN' 
        ? const Color(0xFF38a169) 
        : _clockType == 'OUT' 
            ? const Color(0xFFCC0000) 
            : Colors.grey;

    final buttonText = _clockType == 'IN' 
        ? 'CLOCK IN' 
        : _clockType == 'OUT' 
            ? 'CLOCK OUT' 
            : 'COMPLETED';

    final buttonIcon = _clockType == 'IN' 
        ? Icons.login 
        : _clockType == 'OUT' 
            ? Icons.logout 
            : Icons.check_circle;

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
                  color: buttonColor.withOpacity(0.1),
                  border: Border.all(color: buttonColor, width: 4),
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
                  onPressed: _loading || isDone ? null : _clockInOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(30),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(buttonText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Icon(buttonIcon, color: Colors.white, size: 30),
                        ]),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _infoColumn('Office', _locationName),
                    _infoColumn('Status', isDone ? 'Completed' : _clockType == 'IN' ? 'Clocking In' : 'Clocking Out'),
                    _infoColumn('Method', 'GPS'),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              // Today's records
              if (_todayRecords.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Today\'s Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ..._todayRecords.map((r) => ListTile(
                      dense: true,
                      leading: Icon(
                        r['clock_type'] == 'In' ? Icons.login : Icons.logout,
                        color: r['status'] == 'Approved' ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      title: Text('${r['clock_type']} at ${r['clock_time']}', style: const TextStyle(fontSize: 12)),
                      trailing: Text(r['status'] ?? '', style: TextStyle(fontSize: 11, color: r['status'] == 'Approved' ? Colors.green : Colors.orange)),
                    )),
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