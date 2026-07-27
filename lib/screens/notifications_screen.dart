import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _recentActivity = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final empId = widget.user['employee_id'] ?? '';
    
    try {
      // Load attendance
      final attendance = await _supabase.from('attendance')
          .select().eq('employee_id', empId).order('sync_date', ascending: false).limit(5);
      
      // Load leave requests
      final leaves = await _supabase.from('leave_requests')
          .select().eq('employee_id', empId).order('submitted_at', ascending: false).limit(5);
      
      // Load KPIs
      final kpis = await _supabase.from('performance_data')
          .select().eq('user_name', widget.user['name'] ?? '').limit(5);
      
      // Load GPS clocks
      final clocks = await _supabase.from('gps_attendance')
          .select().eq('employee_id', empId).order('created_at', ascending: false).limit(5);
      
      List<Map<String, dynamic>> activity = [];
      
      for (var a in List<Map<String, dynamic>>.from(attendance)) {
        activity.add({
          'icon': Icons.fingerprint,
          'title': 'Biometric Clock',
          'subtitle': '${a['sync_date']} at ${a['in_time'] ?? 'N/A'}',
          'date': a['sync_date']?.toString() ?? '',
          'color': Colors.blue,
        });
      }
      
      for (var l in List<Map<String, dynamic>>.from(leaves)) {
        activity.add({
          'icon': Icons.calendar_today,
          'title': 'Leave ${l['status'] ?? 'Submitted'}',
          'subtitle': '${l['leave_type']} - ${l['no_of_days']} days',
          'date': l['submitted_at']?.toString().substring(0, 10) ?? '',
          'color': l['status'] == 'Approved' ? Colors.green : Colors.orange,
        });
      }
      
      for (var k in List<Map<String, dynamic>>.from(kpis)) {
        activity.add({
          'icon': Icons.trending_up,
          'title': 'KPI: ${k['pillar_name'] ?? 'Update'}',
          'subtitle': 'Status: ${k['submission_status'] ?? 'Draft'}',
          'date': k['created_at']?.toString().substring(0, 10) ?? '',
          'color': Colors.purple,
        });
      }
      
      for (var c in List<Map<String, dynamic>>.from(clocks)) {
        activity.add({
          'icon': Icons.access_time,
          'title': 'GPS Clock ${c['clock_type']}',
          'subtitle': '${c['location_name'] ?? 'Unknown'} - ${c['status']}',
          'date': c['sync_date']?.toString() ?? '',
          'color': c['status'] == 'Approved' ? Colors.green : Colors.orange,
        });
      }
      
      activity.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      
      setState(() {
        _recentActivity = activity.take(15).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _recentActivity.length,
                itemBuilder: (ctx, i) {
                  final a = _recentActivity[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (a['color'] as Color).withValues(alpha: 0.1),
                        child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
                      ),
                      title: Text(a['title'] as String, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(a['subtitle'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      trailing: Text(a['date'] as String, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}