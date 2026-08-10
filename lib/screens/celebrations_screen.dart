import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CelebrationsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CelebrationsScreen({super.key, required this.user});

  @override
  State<CelebrationsScreen> createState() => _CelebrationsScreenState();
}

class _CelebrationsScreenState extends State<CelebrationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _birthdays = [];
  List<Map<String, dynamic>> _anniversaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCelebrations();
  }

  Future<void> _loadCelebrations() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final currentMonth = now.month;

    final employees = await _supabase
        .from('employees')
        .select('employee_id, first_name, last_name, date_of_birth, join_date, position, department')
        .eq('status', 'Active')
        .limit(200);

    final allEmployees = List<Map<String, dynamic>>.from(employees);
    
    final birthdays = allEmployees.where((e) {
      if (e['date_of_birth'] == null) return false;
      final dob = DateTime.tryParse(e['date_of_birth'].toString());
      return dob != null && dob.month == currentMonth;
    }).toList();
    birthdays.sort((a, b) => DateTime.parse(a['date_of_birth'].toString()).day.compareTo(DateTime.parse(b['date_of_birth'].toString()).day));

    final anniversaries = allEmployees.where((e) {
      if (e['join_date'] == null) return false;
      final jd = DateTime.tryParse(e['join_date'].toString());
      return jd != null && jd.month == currentMonth;
    }).toList();
    anniversaries.sort((a, b) => DateTime.parse(a['join_date'].toString()).day.compareTo(DateTime.parse(b['join_date'].toString()).day));

    setState(() {
      _birthdays = birthdays;
      _anniversaries = anniversaries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎉 Celebrations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : RefreshIndicator(
              onRefresh: _loadCelebrations,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildSection('🎂 Birthdays This Month', _birthdays, Colors.pink),
                  const SizedBox(height: 20),
                  _buildSection('🎊 Work Anniversaries This Month', _anniversaries, const Color(0xFFD4AF37)),
                ]),
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
      const SizedBox(height: 12),
      if (items.isEmpty)
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8DCC8))), child: const Center(child: Text('None this month'))),
      ...items.map((emp) {
        final date = title.contains('Birthday') ? emp['date_of_birth'] : emp['join_date'];
        final day = DateTime.tryParse(date?.toString() ?? '')?.day ?? 0;
        final years = title.contains('Anniversaries') ? DateTime.now().year - (DateTime.tryParse(date?.toString() ?? '')?.year ?? 0) : null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(title.contains('Birthday') ? Icons.cake : Icons.work, color: color)),
            title: Text('${emp['first_name']} ${emp['last_name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${emp['position'] ?? ''} • ${emp['department'] ?? ''}\n${DateFormat('MMMM d').format(DateTime(DateTime.now().year, DateTime.now().month, day))}${years != null ? ' ($years years)' : ''}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('Day $day', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        );
      }),
    ]);
  }
}