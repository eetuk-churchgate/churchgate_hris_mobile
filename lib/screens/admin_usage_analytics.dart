import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminUsageAnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminUsageAnalyticsScreen({super.key, required this.user});

  @override
  State<AdminUsageAnalyticsScreen> createState() => _AdminUsageAnalyticsScreenState();
}

class _AdminUsageAnalyticsScreenState extends State<AdminUsageAnalyticsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  
  int _totalUsers = 0;
  int _todayUsers = 0;
  int _androidUsers = 0;
  int _iosUsers = 0;
  int _monthlyUsers = 0;
  List<Map<String, dynamic>> _recentLogins = [];
  List<Map<String, dynamic>> _dailyStats = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      // Total unique users
      final totalResult = await _supabase
          .from('app_usage_logs')
          .select('employee_id');
      final totalUnique = totalResult.map((r) => r['employee_id']).toSet();
      _totalUsers = totalUnique.length;

      // Today's users
      final todayResult = await _supabase
          .from('app_usage_logs')
          .select('employee_id')
          .gte('created_at', DateTime.now().toString().substring(0, 10));
      final todayUnique = todayResult.map((r) => r['employee_id']).toSet();
      _todayUsers = todayUnique.length;

      // Monthly users
      final monthAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final monthlyResult = await _supabase
          .from('app_usage_logs')
          .select('employee_id')
          .gte('created_at', monthAgo);
      final monthlyUnique = monthlyResult.map((r) => r['employee_id']).toSet();
      _monthlyUsers = monthlyUnique.length;

      // By platform
      final platformData = await _supabase
          .from('app_usage_logs')
          .select('platform, employee_id')
          .gte('created_at', monthAgo);
      
      final androidSet = <String>{};
      final iosSet = <String>{};
      for (var r in platformData) {
        if (r['platform'] == 'android') {
          androidSet.add(r['employee_id']?.toString() ?? '');
        } else if (r['platform'] == 'ios') {
          iosSet.add(r['employee_id']?.toString() ?? '');
        }
      }
      _androidUsers = androidSet.length;
      _iosUsers = iosSet.length;

      // Recent logins
      final recentData = await _supabase
          .from('app_usage_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(20);
      _recentLogins = List<Map<String, dynamic>>.from(recentData);

      // Daily stats (last 7 days)
      _dailyStats = [];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = date.toString().substring(0, 10);
        final nextDateStr = date.add(const Duration(days: 1)).toString().substring(0, 10);
        
        final dayData = await _supabase
            .from('app_usage_logs')
            .select('employee_id')
            .gte('created_at', dateStr)
            .lt('created_at', nextDateStr);
        
        _dailyStats.add({
          'date': dateStr,
          'count': dayData.length,
          'unique': dayData.map((r) => r['employee_id']).toSet().length,
        });
      }
    } catch (e) {
      // Keep empty state
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _statCard('Total Users', '$_totalUsers', Icons.people, const Color(0xFF805AD5)),
                        _statCard('Today', '$_todayUsers', Icons.today, const Color(0xFF3182CE)),
                        _statCard('This Month', '$_monthlyUsers', Icons.calendar_month, const Color(0xFF38A169)),
                        _statCard('Active Now', '${_todayUsers}', Icons.online_prediction, const Color(0xFFD69E2E)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Platform Breakdown
                    const Text('Platform Breakdown',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _platformCard('Android', '$_androidUsers', Icons.android, const Color(0xFF38A169)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _platformCard('iOS', '$_iosUsers', Icons.apple, const Color(0xFF1A1A1A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 7-Day Chart
                    const Text('Last 7 Days',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8DCC8)),
                      ),
                      child: Column(
                        children: _dailyStats.map((day) {
                          final maxCount = _dailyStats.map((d) => d['count'] as int).fold(0, (a, b) => a > b ? a : b);
                          final count = day['count'] as int;
                          final unique = day['unique'] as int;
                          final dateStr = day['date'] as String;
                          final barWidth = maxCount > 0 ? (count / maxCount * 200).toDouble() : 0.0;
                          final dayName = DateFormat('EEE').format(DateTime.parse(dateStr));

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 35,
                                  child: Text(dayName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      Container(
                                        height: 24,
                                        width: barWidth > 8 ? barWidth : 8,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFCC0000), Color(0xFFD4AF37)],
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '$unique unique',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Recent Logins
                    const Text('Recent Activity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 12),
                    if (_recentLogins.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8DCC8)),
                        ),
                        child: const Center(child: Text('No login data yet', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ..._recentLogins.take(10).map((log) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: log['platform'] == 'android'
                                  ? const Color(0xFF38A169).withOpacity(0.1)
                                  : const Color(0xFF1A1A1A).withOpacity(0.1),
                              child: Icon(
                                log['platform'] == 'android' ? Icons.android : Icons.apple,
                                color: log['platform'] == 'android' ? const Color(0xFF38A169) : const Color(0xFF1A1A1A),
                                size: 16,
                              ),
                            ),
                            title: Text(
                              log['employee_name'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              'ID: ${log['employee_id'] ?? 'N/A'}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            trailing: Text(
                              _formatTime(log['created_at']?.toString()),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8DCC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _platformCard(String platform, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8DCC8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(platform, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('MMM d').format(dt);
    } catch (e) {
      return '';
    }
  }
}