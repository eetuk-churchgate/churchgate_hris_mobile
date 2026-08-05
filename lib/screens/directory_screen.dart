import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/engagement_service.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';
  String _selectedDept = 'All';
  List<String> _departments = ['All'];

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Directory');
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('employees')
          .select('*')
          .order('first_name', ascending: true);

      final depts = <String>{'All'};
      for (var emp in response) {
        if (emp['department'] != null) depts.add(emp['department'].toString());
      }

      setState(() {
        _employees = List<Map<String, dynamic>>.from(response);
        _filtered = List<Map<String, dynamic>>.from(response);
        _departments = depts.toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _filterEmployees() {
    setState(() {
      _filtered = _employees.where((emp) {
        final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.toLowerCase();
        final dept = emp['department']?.toString() ?? '';
        final matchesSearch = _searchQuery.isEmpty || 
            name.contains(_searchQuery.toLowerCase()) ||
            (emp['email']?.toString() ?? '').contains(_searchQuery.toLowerCase()) ||
            (emp['position']?.toString() ?? '').contains(_searchQuery.toLowerCase());
        final matchesDept = _selectedDept == 'All' || dept == _selectedDept;
        return matchesSearch && matchesDept;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Text('Directory (${_filtered.length})'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  onChanged: (v) {
                    _searchQuery = v;
                    _filterEmployees();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, position...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFCC0000)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Row(
                  children: _departments.map((dept) {
                    final isSelected = _selectedDept == dept;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedDept = dept);
                          _filterEmployees();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFCC0000) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? const Color(0xFFCC0000) : Colors.grey.shade300),
                          ),
                          child: Text(dept, style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : _filtered.isEmpty
              ? const Center(child: Text('No employees found', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadEmployees,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final emp = _filtered[index];
                      return _buildEmployeeCard(emp);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final position = emp['position'] ?? '';
    final dept = emp['department'] ?? '';
    final phone = emp['phone'] ?? '';
    final email = emp['email'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFFCC0000),
          child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(position, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            Text('$dept${phone.isNotEmpty ? ' • $phone' : ''}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.phone_outlined, color: Color(0xFFCC0000)),
          onPressed: () {
            // Call functionality
          },
        ),
        onTap: () {
          _showEmployeeDetail(emp);
        },
      ),
    );
  }

  void _showEmployeeDetail(Map<String, dynamic> emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFFCC0000),
                    child: Text(
                      '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.isNotEmpty 
                          ? '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'[0].toUpperCase() 
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Center(child: Text(emp['position'] ?? '', style: TextStyle(color: Colors.grey.shade600))),
                const SizedBox(height: 20),
                _detailRow(Icons.business, 'Department', emp['department'] ?? 'N/A'),
                _detailRow(Icons.badge, 'Employee ID', emp['employee_id'] ?? 'N/A'),
                _detailRow(Icons.email, 'Email', emp['email'] ?? 'N/A'),
                _detailRow(Icons.phone, 'Phone', emp['phone'] ?? 'N/A'),
                _detailRow(Icons.calendar_today, 'Joined', emp['join_date']?.toString()?.substring(0, 10) ?? 'N/A'),
                _detailRow(Icons.star, 'Grade', emp['grade'] ?? 'N/A'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFCC0000), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}