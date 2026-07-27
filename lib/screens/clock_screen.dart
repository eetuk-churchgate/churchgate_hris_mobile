import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/location_service.dart';

class ClockScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ClockScreen({super.key, required this.user});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  String _locationStatus = 'Checking location...';
  bool _loading = false;
  List<Map<String, dynamic>> _records = [];
  String _correctionReason = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationStatus = '⚠️ Location permission denied');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final isInOffice = LocationService.isWithinOffice(position.latitude, position.longitude);
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnWifi = connectivityResult == ConnectivityResult.wifi;

      setState(() {
        if (isInOffice != null && isOnWifi) {
          _locationStatus = '✅ Ready - At $isInOffice on WiFi';
        } else if (isInOffice != null && !isOnWifi) {
          _locationStatus = '⚠️ At $isInOffice but not on WiFi';
        } else if (isInOffice == null && isOnWifi) {
          _locationStatus = '⚠️ On WiFi but outside office';
        } else {
          _locationStatus = '❌ Outside office - Mobile data';
        }
      });
    } catch (e) {
      setState(() => _locationStatus = '⚠️ Cannot determine location');
    }
  }

  Future<void> _loadRecords() async {
    final empId = widget.user['employee_id'] ?? '';
    try {
      final records = await LocationService.getGPSRecords(empId);
      if (mounted) setState(() => _records = records);
    } catch (e) {
      // Failed to load records
    }
  }

  Future<void> _clockInOut(String type) async {
    setState(() => _loading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required to clock in/out'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnWifi = connectivityResult == ConnectivityResult.wifi;

      final result = await LocationService.submitGPSClock(
        widget.user['employee_id'] ?? '',
        widget.user['name'] ?? '',
        type,
        position.latitude,
        position.longitude,
        ipAddress: isOnWifi ? '192.168.100.1' : null,
      );

      if (mounted) {
        setState(() {
          _locationStatus = result['message'] as String;
          _loading = false;
        });

        _loadRecords();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: result['success'] == true ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clock In/Out')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _locationStatus.contains('✅') ? Colors.green : const Color(0xFFD4AF37),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _locationStatus.contains('✅') ? Icons.verified : Icons.gps_fixed,
                    size: 48,
                    color: _locationStatus.contains('✅') ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Text(_locationStatus, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _checkCurrentStatus,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Status', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 70,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () => _clockInOut('In'),
                      icon: const Icon(Icons.login, size: 24),
                      label: const Text('Clock In', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 70,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () => _clockInOut('Out'),
                      icon: const Icon(Icons.logout, size: 24),
                      label: const Text('Clock Out', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCC0000),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showCorrectionDialog(),
              icon: const Icon(Icons.edit_note),
              label: const Text('Missed Clock? Request Correction'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No clock records yet', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (ctx, i) {
                        final r = _records[i];
                        final isApproved = r['status'] == 'Approved';
                        final icon = r['clock_type'] == 'In' ? Icons.login 
                            : r['clock_type'] == 'Out' ? Icons.logout : Icons.edit;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: Icon(icon, color: isApproved ? Colors.green : Colors.orange, size: 20),
                            title: Text('${r['clock_type']} - ${r['location_name'] ?? 'Remote'}',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text('${r['sync_date']} at ${r['clock_time']}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(r['status'] ?? 'Pending',
                                  style: TextStyle(color: isApproved ? Colors.green : Colors.orange, fontSize: 11)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCorrectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Missed Clock Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Explain why you missed clocking in/out:'),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Forgot biometric, system error...',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => _correctionReason = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocationService.submitCorrection(
                widget.user['employee_id'] ?? '',
                widget.user['name'] ?? '',
                DateTime.now().toString().substring(0, 10),
                _correctionReason,
              );
              _loadRecords();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Correction submitted for approval')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}