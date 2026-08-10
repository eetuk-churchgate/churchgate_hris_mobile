import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'attendance_screen.dart';
import 'leave_screen.dart';
import 'directory_screen.dart';
import 'performance_full_screen.dart';
import 'clock_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'notifications_screen.dart';
import 'lms_screen.dart';
import 'admin_clock_approvals.dart';
import 'attendance_report_screen.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'news_feed_screen.dart';
import 'wellness_screen.dart';
import 'ai_assistant_screen.dart';
import 'payslip_screen.dart';
import 'kudos_screen.dart';
import 'pulse_survey_screen.dart';
import 'celebrations_screen.dart';
import 'desk_booking_screen.dart';
import 'admin_survey_manager.dart';
import 'admin_room_manager.dart';
import '../services/engagement_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic> _userData = {};
  String? _profileImageBase64;
  bool _loading = true;
  int _pendingRequests = 0;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Dashboard');
    _loadFullProfile();
    _loadProfilePicture();
    _loadPendingCounts();
    _loadRecentActivities();
  }

  Future<void> _loadFullProfile() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final empId = widget.user['employee_id'] ?? '';
      final response = await _supabase.from('employees').select().eq('employee_id', empId).maybeSingle();
      if (response != null) {
        setState(() { _userData = Map<String, dynamic>.from(widget.user); _userData.addAll(Map<String, dynamic>.from(response)); });
      } else { setState(() => _userData = widget.user); }
    } catch (e) { setState(() => _userData = widget.user); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfilePicture() async {
    try {
      final userId = widget.user['id'];
      if (userId != null) {
        final response = await _supabase.from('profile_pics').select('image_data').eq('user_id', userId.toString()).order('created_at', ascending: false).limit(1).maybeSingle();
        if (response != null && response['image_data'] != null) { if (mounted) setState(() => _profileImageBase64 = response['image_data'].toString()); }
      }
    } catch (e) {}
  }

  Future<void> _loadPendingCounts() async {
    try {
      final empId = widget.user['employee_id'] ?? '';
      final leaveData = await _supabase.from('leave_requests').select().eq('employee_id', empId).neq('status', 'Approved').neq('status', 'Rejected');
      if (mounted) setState(() => _pendingRequests = leaveData.length);
    } catch (e) {}
  }

  Future<void> _loadRecentActivities() async {
    try {
      final empId = widget.user['employee_id'] ?? '';
      final userName = widget.user['name'] ?? '';
      List<Map<String, dynamic>> activities = [];
      final gpsClocks = await _supabase.from('gps_attendance').select().eq('employee_id', empId).order('created_at', ascending: false).limit(5);
      for (var c in gpsClocks) { activities.add({'icon': Icons.access_time, 'title': 'GPS ${c['clock_type'] ?? 'Clock'}', 'subtitle': '${c['location_name'] ?? 'Remote'} - ${c['status'] ?? 'Pending'}', 'date': _formatDate(c['sync_date']?.toString(), c['clock_time']?.toString())}); }
      final leaves = await _supabase.from('leave_requests').select().eq('employee_id', empId).order('submitted_at', ascending: false).limit(5);
      for (var l in leaves) { activities.add({'icon': Icons.calendar_today, 'title': 'Leave ${l['status'] ?? 'Submitted'}', 'subtitle': '${l['leave_type'] ?? 'Leave'} - ${l['no_of_days'] ?? 0} day(s)', 'date': _formatDate(l['submitted_at']?.toString()?.substring(0, 10))}); }
      final kpis = await _supabase.from('kpi_history').select().eq('user_name', userName).order('created_at', ascending: false).limit(5);
      for (var k in kpis) { activities.add({'icon': Icons.trending_up, 'title': 'KPI ${k['action'] ?? 'Updated'}', 'subtitle': '${k['kpi_name'] ?? 'KPI'} - ${k['pillar'] ?? ''}', 'date': _formatDate(k['created_at']?.toString()?.substring(0, 10))}); }
      final attendance = await _supabase.from('attendance').select().eq('employee_id', empId).order('created_at', ascending: false).limit(5);
      for (var a in attendance) { activities.add({'icon': Icons.check_circle, 'title': 'Attendance Recorded', 'subtitle': '${a['source'] ?? 'System'} - ${a['status'] ?? 'Present'}', 'date': _formatDate(a['sync_date']?.toString())}); }
      activities.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      if (mounted) setState(() => _recentActivities = activities.take(10).toList());
    } catch (e) {}
  }

  String _formatDate(String? date, [String? time]) {
    if (date == null || date.isEmpty) return '';
    try {
      final now = DateTime.now().toString().substring(0, 10);
      if (date == now) return 'Today${time != null ? ' at $time' : ''}';
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toString().substring(0, 10);
      if (date == yesterday) return 'Yesterday${time != null ? ' at $time' : ''}';
      final parts = date.split('-');
      if (parts.length == 3) { const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']; final month = int.tryParse(parts[1]) ?? 1; return '${months[month - 1]} ${parts[2]}, ${parts[0]}${time != null ? ' at $time' : ''}'; }
      return '$date${time != null ? ' at $time' : ''}';
    } catch (e) { return date; }
  }

  Uint8List _fromBase64(String base64String) { try { return base64Decode(base64String); } catch (e) { return Uint8List(0); } }

  void _navigateAndTrack(Widget page, String module) { EngagementService.trackPageView(module: module); Navigator.push(context, MaterialPageRoute(builder: (_) => page)); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))));
    String name = '';
    if (_userData['name'] != null && _userData['name'].toString().isNotEmpty) { name = _userData['name'].toString(); } else if (_userData['first_name'] != null) { name = '${_userData['first_name']} ${_userData['last_name'] ?? ''}'; }
    if (name.isEmpty) name = 'Staff';
    String position = _userData['position']?.toString() ?? 'Employee';
    String department = _userData['department']?.toString() ?? '';
    String region = _userData['region']?.toString() ?? '';
    String initials = name.substring(0, 1).toUpperCase();
    String role = widget.user['role']?.toString() ?? 'Employee';
    String employeeId = _userData['employee_id']?.toString() ?? '';
    bool isAdmin = role == 'Admin' || role == 'HR' || role == 'Super Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(title: const Text('Churchgate HRIS'), actions: [Stack(children: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => _navigateAndTrack(NotificationsScreen(user: _userData), 'Notifications')), if (_unreadNotifications > 0) Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('$_unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 10))))])]),
      drawer: _buildDrawer(context, name, initials, role, department, isAdmin),
      body: RefreshIndicator(
        onRefresh: () async { await _loadFullProfile(); await _loadProfilePicture(); await _loadPendingCounts(); await _loadRecentActivities(); },
        child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D2A1F)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD4AF37), width: 1), boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))]), child: Row(children: [GestureDetector(onTap: () => _navigateAndTrack(ProfileScreen(user: _userData), 'Profile'), child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD4AF37), width: 2)), child: CircleAvatar(radius: 35, backgroundColor: const Color(0xFFCC0000), backgroundImage: _profileImageBase64 != null ? MemoryImage(_fromBase64(_profileImageBase64!)) : null, child: _profileImageBase64 == null ? Text(initials, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)) : null))), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Color(0xFFF5E6CC), fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(position, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12))), if (department.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('$department${region.isNotEmpty ? ' • $region' : ''}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)))])), const Icon(Icons.chevron_right, color: Color(0xFFD4AF37))])),
          const SizedBox(height: 20),
          Row(children: [Icon(Icons.wb_sunny, color: Colors.orange.shade700, size: 18), const SizedBox(width: 6), Text('Today: ${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Text('🟢 Office Day', style: TextStyle(fontSize: 11, color: Colors.green)))]),
          const SizedBox(height: 16),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
            _statCard('Attendance', 'Present', Icons.check_circle, const Color(0xFF38A169), () => _navigateAndTrack(AttendanceScreen(user: _userData), 'Attendance')),
            _statCard('Leave Balance', '24 days', Icons.beach_access, const Color(0xFF3182CE), () => _navigateAndTrack(LeaveScreen(user: _userData), 'Leave Requests')),
            _statCard('Clock In/Out', 'WTC Abuja', Icons.access_time, const Color(0xFFCC0000), () => _navigateAndTrack(ClockScreen(user: _userData), 'Clock In/Out')),
            _statCard('Performance', 'View KPIs', Icons.trending_up, const Color(0xFFD4AF37), () => _navigateAndTrack(PerformanceFullScreen(user: _userData), 'Performance')),
            if (isAdmin) _statCard('Report', 'View', Icons.assessment, const Color(0xFF805AD5), () => _navigateAndTrack(AttendanceReportScreen(user: _userData), 'Attendance Report')),
            _statCard('Training', 'Courses', Icons.school, const Color(0xFF3182CE), () => _navigateAndTrack(LMSScreen(user: _userData), 'Training')),
          ]),
          const SizedBox(height: 24),
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))), const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _actionBtn(Icons.access_time, 'Clock In', const Color(0xFFCC0000), () => _navigateAndTrack(ClockScreen(user: _userData), 'Clock In/Out')), const SizedBox(width: 12),
            _actionBtn(Icons.calendar_today, 'Leave', const Color(0xFF3182CE), () => _navigateAndTrack(LeaveScreen(user: _userData), 'Leave Requests')), const SizedBox(width: 12),
            _actionBtn(Icons.people, 'Directory', const Color(0xFF38A169), () => _navigateAndTrack(const DirectoryScreen(), 'Directory')), const SizedBox(width: 12),
            _actionBtn(Icons.trending_up, 'KPI', const Color(0xFFD4AF37), () => _navigateAndTrack(PerformanceFullScreen(user: _userData), 'Performance')), const SizedBox(width: 12),
            _actionBtn(Icons.school, 'Training', const Color(0xFF3182CE), () => _navigateAndTrack(LMSScreen(user: _userData), 'Training')), const SizedBox(width: 12),
            _actionBtn(Icons.chat, 'Chat', const Color(0xFF3182CE), () => _navigateAndTrack(ChatScreen(user: _userData), 'Team Chat')), const SizedBox(width: 12),
            _actionBtn(Icons.emoji_events, 'Kudos', const Color(0xFFD4AF37), () => _navigateAndTrack(KudosScreen(user: _userData), 'Kudos')), const SizedBox(width: 12),
            _actionBtn(Icons.poll, 'Survey', const Color(0xFF805AD5), () => _navigateAndTrack(PulseSurveyScreen(user: _userData), 'Surveys')), const SizedBox(width: 12),
            _actionBtn(Icons.cake, 'Celebrate', Colors.pink, () => _navigateAndTrack(CelebrationsScreen(user: _userData), 'Celebrations')), const SizedBox(width: 12),
            _actionBtn(Icons.chair, 'Room', const Color(0xFF1A1A1A), () => _navigateAndTrack(DeskBookingScreen(user: _userData), 'Room Booking')), const SizedBox(width: 12),
            _actionBtn(Icons.article, 'News', const Color(0xFF805AD5), () => _navigateAndTrack(NewsFeedScreen(user: _userData), 'News Feed')), const SizedBox(width: 12),
            _actionBtn(Icons.spa, 'Wellness', const Color(0xFF38A169), () => _navigateAndTrack(WellnessScreen(user: _userData), 'Wellness')), const SizedBox(width: 12),
            _actionBtn(Icons.smart_toy, 'AI Help', const Color(0xFFD4AF37), () => _navigateAndTrack(AIAssistantScreen(user: _userData), 'AI Assistant')), const SizedBox(width: 12),
            _actionBtn(Icons.receipt, 'Payslip', const Color(0xFF1A1A1A), () => _navigateAndTrack(PayslipScreen(user: _userData), 'Payslips')),
            if (isAdmin) ...[
              const SizedBox(width: 12), _actionBtn(Icons.assessment, 'Report', const Color(0xFF805AD5), () => _navigateAndTrack(AttendanceReportScreen(user: _userData), 'Attendance Report')),
              const SizedBox(width: 12), _actionBtn(Icons.admin_panel_settings, 'Approvals', const Color(0xFF1A1A1A), () => _navigateAndTrack(AdminClockApprovalsScreen(user: _userData), 'Admin Approvals')),
              const SizedBox(width: 12), _actionBtn(Icons.poll, 'Surveys', const Color(0xFF805AD5), () => _navigateAndTrack(AdminSurveyManager(user: _userData), 'Survey Manager')),
              const SizedBox(width: 12), _actionBtn(Icons.chair, 'Rooms', const Color(0xFF1A1A1A), () => _navigateAndTrack(AdminRoomManager(user: _userData), 'Room Manager')),
            ],
            const SizedBox(width: 12), _actionBtn(Icons.person, 'Profile', const Color(0xFFD4AF37), () => _navigateAndTrack(ProfileScreen(user: _userData), 'Profile')),
            const SizedBox(width: 12), _actionBtn(Icons.inbox, 'Requests', const Color(0xFFD69E2E), () => _navigateAndTrack(RequestsScreen(user: _userData), 'Requests')),
          ])),
          const SizedBox(height: 24),
          const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))), const SizedBox(height: 12),
          if (_recentActivities.isEmpty) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8DCC8))), child: const Center(child: Text('No recent activity', style: TextStyle(color: Colors.grey)))) else Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8DCC8))), child: Column(children: _recentActivities.asMap().entries.map((entry) { final index = entry.key; final activity = entry.value; return Column(children: [_activityItem(activity['icon'] as IconData, activity['title'] as String, activity['date'] as String, activity['subtitle'] as String), if (index < _recentActivities.length - 1) const Divider()]); }).toList())),
          const SizedBox(height: 16),
          Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)), child: Text('ID: $employeeId', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w500)))),
          const SizedBox(height: 20),
        ])),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String name, String initials, String role, String department, bool isAdmin) {
    return Drawer(child: ListView(padding: EdgeInsets.zero, children: [
      Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2D2A1F)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 2))), child: DrawerHeader(margin: EdgeInsets.zero, padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [CircleAvatar(radius: 30, backgroundColor: const Color(0xFFCC0000), backgroundImage: _profileImageBase64 != null ? MemoryImage(_fromBase64(_profileImageBase64!)) : null, child: _profileImageBase64 == null ? Text(initials, style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)) : null), const SizedBox(height: 10), Text(name, style: const TextStyle(color: Color(0xFFF5E6CC), fontSize: 16, fontWeight: FontWeight.bold)), Text('$role${department.isNotEmpty ? ' • $department' : ''}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11))]))),
      _drawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
      _drawerItem(Icons.access_time, 'Clock In/Out', () { Navigator.pop(context); _navigateAndTrack(ClockScreen(user: _userData), 'Clock In/Out'); }),
      if (isAdmin) _drawerItem(Icons.assessment, 'Attendance Report', () { Navigator.pop(context); _navigateAndTrack(AttendanceReportScreen(user: _userData), 'Attendance Report'); }),
      _drawerItem(Icons.calendar_today, 'Leave Requests', () { Navigator.pop(context); _navigateAndTrack(LeaveScreen(user: _userData), 'Leave Requests'); }),
      _drawerItem(Icons.check_circle, 'Attendance', () { Navigator.pop(context); _navigateAndTrack(AttendanceScreen(user: _userData), 'Attendance'); }),
      _drawerItem(Icons.trending_up, 'Performance', () { Navigator.pop(context); _navigateAndTrack(PerformanceFullScreen(user: _userData), 'Performance'); }),
      _drawerItem(Icons.school, 'Training & Courses', () { Navigator.pop(context); _navigateAndTrack(LMSScreen(user: _userData), 'Training'); }),
      _drawerItem(Icons.chat, 'Team Chat', () { Navigator.pop(context); _navigateAndTrack(ChatScreen(user: _userData), 'Team Chat'); }),
      _drawerItem(Icons.emoji_events, 'Kudos Wall', () { Navigator.pop(context); _navigateAndTrack(KudosScreen(user: _userData), 'Kudos'); }),
      _drawerItem(Icons.poll, 'Pulse Surveys', () { Navigator.pop(context); _navigateAndTrack(PulseSurveyScreen(user: _userData), 'Surveys'); }),
      _drawerItem(Icons.cake, 'Celebrations', () { Navigator.pop(context); _navigateAndTrack(CelebrationsScreen(user: _userData), 'Celebrations'); }),
      _drawerItem(Icons.chair, 'Room Booking', () { Navigator.pop(context); _navigateAndTrack(DeskBookingScreen(user: _userData), 'Room Booking'); }),
      _drawerItem(Icons.article, 'News Feed', () { Navigator.pop(context); _navigateAndTrack(NewsFeedScreen(user: _userData), 'News Feed'); }),
      _drawerItem(Icons.spa, 'Wellness', () { Navigator.pop(context); _navigateAndTrack(WellnessScreen(user: _userData), 'Wellness'); }),
      _drawerItem(Icons.smart_toy, 'AI Assistant', () { Navigator.pop(context); _navigateAndTrack(AIAssistantScreen(user: _userData), 'AI Assistant'); }),
      _drawerItem(Icons.receipt, 'Payslips', () { Navigator.pop(context); _navigateAndTrack(PayslipScreen(user: _userData), 'Payslips'); }),
      if (isAdmin) _drawerItem(Icons.admin_panel_settings, 'Clock Approvals', () { Navigator.pop(context); _navigateAndTrack(AdminClockApprovalsScreen(user: _userData), 'Admin Approvals'); }),
      if (isAdmin) _drawerItem(Icons.poll, 'Survey Manager', () { Navigator.pop(context); _navigateAndTrack(AdminSurveyManager(user: _userData), 'Survey Manager'); }),
      if (isAdmin) _drawerItem(Icons.chair, 'Room Manager', () { Navigator.pop(context); _navigateAndTrack(AdminRoomManager(user: _userData), 'Room Manager'); }),
      _drawerItem(Icons.people, 'Directory', () { Navigator.pop(context); _navigateAndTrack(const DirectoryScreen(), 'Directory'); }),
      _drawerItem(Icons.inbox, 'My Requests', () { Navigator.pop(context); _navigateAndTrack(RequestsScreen(user: _userData), 'Requests'); }),
      _drawerItem(Icons.notifications, 'Notifications', () { Navigator.pop(context); _navigateAndTrack(NotificationsScreen(user: _userData), 'Notifications'); }),
      _drawerItem(Icons.person, 'My Profile', () { Navigator.pop(context); _navigateAndTrack(ProfileScreen(user: _userData), 'Profile'); }),
      const Divider(),
      _drawerItem(Icons.logout, 'Sign Out', () { EngagementService.trackPageView(module: 'Logout', action: 'sign_out'); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false); }, red: true),
    ]));
  }

  Widget _statCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8DCC8)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Row(children: [Icon(icon, color: color, size: 22), const Spacer(), Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400)]), const Spacer(), Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)), Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))])));
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Column(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))), child: Icon(icon, color: color, size: 22)), const SizedBox(height: 6), Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700))]));
  }

  Widget _activityItem(IconData icon, String title, String date, String subtitle) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Icon(icon, color: const Color(0xFFCC0000), size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)), Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11))])), Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 10))]));
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {bool red = false}) {
    return ListTile(leading: Icon(icon, color: red ? Colors.red : const Color(0xFFCC0000), size: 22), title: Text(title, style: TextStyle(fontSize: 13, color: red ? Colors.red : const Color(0xFF1A1A1A))), onTap: onTap, dense: true);
  }

  String _getMonthName(int month) { const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']; return months[month - 1]; }
}