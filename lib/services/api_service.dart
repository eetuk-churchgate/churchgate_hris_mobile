import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static final _supabase = Supabase.instance.client;

  // Get current user
  static Map<String, dynamic>? get currentUser => null;

  // Attendance
  static Future<List<Map<String, dynamic>>> getMyAttendance(String employeeId) async {
    final data = await _supabase
        .from('attendance')
        .select()
        .eq('employee_id', employeeId)
        .order('sync_date', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(data);
  }

  // Leave requests
  static Future<List<Map<String, dynamic>>> getMyLeaveRequests(String employeeId) async {
    final data = await _supabase
        .from('leave_requests')
        .select()
        .eq('employee_id', employeeId)
        .order('submitted_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(data);
  }

  // Submit leave request
  static Future<void> submitLeaveRequest(Map<String, dynamic> data) async {
    await _supabase.from('leave_requests').insert(data);
  }

  // Employees directory
  static Future<List<Map<String, dynamic>>> getEmployees() async {
    final data = await _supabase
        .from('employees')
        .select()
        .eq('status', 'Active')
        .order('first_name')
        .limit(100);
    return List<Map<String, dynamic>>.from(data);
  }

  // Performance KPIs
  static Future<List<Map<String, dynamic>>> getMyKPIs(String userName) async {
    final data = await _supabase
        .from('performance_data')
        .select()
        .eq('user_name', userName);
    return List<Map<String, dynamic>>.from(data);
  }
}