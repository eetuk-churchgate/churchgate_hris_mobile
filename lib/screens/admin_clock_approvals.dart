import '../services/engagement_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminClockApprovalsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminClockApprovalsScreen({super.key, required this.user});

  @override
  State<AdminClockApprovalsScreen> createState() => _AdminClockApprovalsScreenState();
}

class _AdminClockApprovalsScreenState extends State<AdminClockApprovalsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingClocks = [];
  List<Map<String, dynamic>> _allClocks = [];
  bool _loading = true;
  String _filterStatus = 'Pending';

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Admin Approvals');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load pending clocks
      final pending = await _supabase
          .from('gps_attendance')
          .select()
          .eq('status', 'Pending')
          .order('created_at', ascending: false)
          .limit(50);
      
      // Load all clocks
      final all = await _supabase
          .from('gps_attendance')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      setState(() {
        _pendingClocks = List<Map<String, dynamic>>.from(pending);
        _allClocks = List<Map<String, dynamic>>.from(all);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _approveClock(int id) async {
    try {
      await _supabase
          .from('gps_attendance')
          .update({
            'status': 'Approved',
            'approved_by': widget.user['name'] ?? 'Admin',
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clock approved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectClock(int id) async {
    try {
      await _supabase
          .from('gps_attendance')
          .update({
            'status': 'Rejected',
            'approved_by': widget.user['name'] ?? 'Admin',
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clock rejected'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredClocks {
    if (_filterStatus == 'All') return _allClocks;
    if (_filterStatus == 'Pending') return _pendingClocks;
    return _allClocks.where((c) => c['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clock Approvals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                _statBox('Pending', _pendingClocks.length.toString(), Colors.orange),
                const SizedBox(width: 12),
                _statBox('Approved', _allClocks.where((c) => c['status'] == 'Approved').length.toString(), Colors.green),
                const SizedBox(width: 12),
                _statBox('Rejected', _allClocks.where((c) => c['status'] == 'Rejected').length.toString(), Colors.red),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['Pending', 'Approved', 'Rejected', 'All'].map((status) {
                final isSelected = _filterStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filterStatus = status),
                    selectedColor: const Color(0xFFCC0000).withOpacity(0.1),
                    checkmarkColor: const Color(0xFFCC0000),
                  ),
                );
              }).toList(),
            ),
          ),

          // Clock List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
                : _filteredClocks.isEmpty
                    ? const Center(child: Text('No records found'))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredClocks.length,
                          itemBuilder: (context, index) {
                            final clock = _filteredClocks[index];
                            return _buildClockCard(clock);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildClockCard(Map<String, dynamic> clock) {
    final status = clock['status'] ?? 'Pending';
    final isPending = status == 'Pending';
    final clockType = clock['clock_type'] ?? 'Unknown';
    
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clock['employee_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'ID: ${clock['employee_id'] ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details row
            Row(
              children: [
                _detailChip(Icons.login, clockType),
                const SizedBox(width: 8),
                _detailChip(Icons.location_on, clock['location_name'] ?? 'Remote'),
                const SizedBox(width: 8),
                _detailChip(Icons.access_time, '${clock['sync_date']} ${clock['clock_time']}'),
              ],
            ),

            // Approved/Rejected by
            if (clock['approved_by'] != null) ...[
              const SizedBox(height: 8),
              Text(
                '${status} by ${clock['approved_by']} on ${clock['approved_at']?.toString().substring(0, 10) ?? ''}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ],

            // Action buttons for pending
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveClock(clock['id']),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectClock(clock['id']),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
