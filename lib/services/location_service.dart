// lib/services/location_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class LocationService {
  static final _supabase = Supabase.instance.client;

  // Office locations with 40m geofence radius
  static const Map<String, Map<String, dynamic>> officeLocations = {
    'WTC Abuja': {
      'latitude': 9.0488599,
      'longitude': 7.4730175,
      'radius': 40,
    },
    'Lagos Towers': {
      'latitude': 6.4353608,
      'longitude': 3.4275034,
      'radius': 40,
    },
  };

  // Office network IP ranges for verification
  static const List<String> officeNetworkIPs = [
    '192.168.100.',
    '192.168.106.',
    '10.100.',
  ];

  static bool isOnOfficeNetwork(String? ipAddress) {
    if (ipAddress == null) return false;
    for (var range in officeNetworkIPs) {
      if (ipAddress.startsWith(range)) return true;
    }
    return false;
  }

  static String? isWithinOffice(double lat, double lng) {
    for (var entry in officeLocations.entries) {
      final office = entry.value;
      final distance = _calculateDistance(
        lat, lng,
        office['latitude'] as double,
        office['longitude'] as double,
      );
      if (distance <= (office['radius'] as int)) {
        return entry.key;
      }
    }
    return null;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double degree) => degree * pi / 180;

  static Future<Map<String, dynamic>> submitGPSClock(
    String employeeId, 
    String employeeName, 
    String clockType,
    double lat, 
    double lng, 
    {String? ipAddress}
  ) async {
    
    final locationName = isWithinOffice(lat, lng);
    final isNetwork = isOnOfficeNetwork(ipAddress);
    final now = DateTime.now();
    
    String status;
    String message;
    
    if (locationName != null) {
      status = 'Approved';
      message = '✅ $clockType verified at $locationName (GPS)';
    } else {
      status = 'Pending';
      message = '⚠️ Outside office geofence. $clockType submitted for approval.';
    }
    
    final data = {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'clock_type': clockType,
      'latitude': lat,
      'longitude': lng,
      'location_name': locationName ?? 'Remote',
      'sync_date': now.toString().substring(0, 10),
      'clock_time': now.toString().substring(11, 16),
      'status': status,
    };
    
    await _supabase.from('gps_attendance').insert(data);
    
    return {
      'success': status == 'Approved',
      'location': locationName ?? 'Remote',
      'network_verified': isNetwork,
      'message': message,
    };
  }

  static Future<void> submitCorrection(String employeeId, String employeeName, 
      String date, String reason) async {
    await _supabase.from('gps_attendance').insert({
      'employee_id': employeeId,
      'employee_name': employeeName,
      'clock_type': 'Correction',
      'sync_date': date,
      'clock_time': DateTime.now().toString().substring(11, 16),
      'status': 'Pending',
      'location_name': reason,
    });
  }

  static Future<List<Map<String, dynamic>>> getGPSRecords(String employeeId) async {
    final data = await _supabase
        .from('gps_attendance')
        .select()
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(data);
  }
}