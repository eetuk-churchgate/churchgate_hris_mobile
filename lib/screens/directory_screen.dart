import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    final data = await ApiService.getEmployees();
    setState(() {
      _employees = data;
      _filtered = data;
      _loading = false;
    });
  }

  void _search(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _employees;
      } else {
        _filtered = _employees.where((e) {
          final name = '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.toLowerCase();
          final dept = (e['department'] ?? '').toLowerCase();
          final pos = (e['position'] ?? '').toLowerCase();
          return name.contains(query.toLowerCase()) ||
              dept.contains(query.toLowerCase()) ||
              pos.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Directory'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by name, department, position...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFCC0000)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No employees found', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEmployees,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final e = _filtered[index];
                      final initials = '${e['first_name']?.toString().substring(0, 1) ?? ''}${e['last_name']?.toString().substring(0, 1) ?? ''}';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: const Color(0xFFCC0000),
                            child: Text(initials.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(
                            '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${e['position'] ?? ''}'),
                              Text('${e['department'] ?? ''} • ${e['region'] ?? ''}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (e['status'] == 'Active') ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              e['status'] ?? 'Active',
                              style: TextStyle(
                                color: (e['status'] == 'Active') ? Colors.green : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          onTap: () {
                            _showEmployeeDetails(context, e);
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showEmployeeDetails(BuildContext context, Map<String, dynamic> emp) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFCC0000),
                    child: Text(
                      '${emp['first_name']?.toString().substring(0, 1) ?? ''}${emp['last_name']?.toString().substring(0, 1) ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${emp['first_name']} ${emp['last_name']}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(emp['position'] ?? '', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow(Icons.business, 'Department', emp['department'] ?? 'N/A'),
              _detailRow(Icons.location_on, 'Region', emp['region'] ?? 'N/A'),
              _detailRow(Icons.corporate_fare, 'Subsidiary', emp['subsidiary'] ?? 'N/A'),
              _detailRow(Icons.email, 'Email', emp['email'] ?? 'N/A'),
              _detailRow(Icons.phone, 'Phone', emp['phone'] ?? 'N/A'),
              _detailRow(Icons.calendar_today, 'Join Date', emp['join_date']?.toString().substring(0, 10) ?? 'N/A'),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFCC0000)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade700))),
        ],
      ),
    );
  }
}