import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LeaveScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const LeaveScreen({super.key, required this.user});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    final empId = widget.user['employee_id'] ?? '';
    final data = await ApiService.getMyLeaveRequests(empId);
    setState(() {
      _requests = data;
      _loading = false;
    });
  }

  Future<void> _submitRequest() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Request'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Reason for leave...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, 'test');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (reason != null) {
      setState(() => _loading = true);
      await ApiService.submitLeaveRequest({
        'request_id': 'REQ-${DateTime.now().millisecondsSinceEpoch}',
        'employee_id': widget.user['employee_id'],
        'employee_name': widget.user['name'],
        'department': widget.user['department'],
        'leave_type': 'Annual Leave',
        'from_date': DateTime.now().toString().substring(0, 10),
        'to_date': DateTime.now().add(const Duration(days: 1)).toString().substring(0, 10),
        'no_of_days': 1,
        'reason': reason,
        'status': 'Submitted',
        'submitted_at': DateTime.now().toString(),
      });
      _loadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests')),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitRequest,
        backgroundColor: const Color(0xFFCC0000),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(child: Text('No leave requests yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final r = _requests[index];
                    final status = r['status'] ?? 'Pending';
                    Color statusColor;
                    switch (status) {
                      case 'Approved':
                        statusColor = Colors.green;
                        break;
                      case 'Rejected':
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.orange;
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.beach_access, color: statusColor),
                        title: Text('${r['leave_type']} - ${r['no_of_days']} day(s)'),
                        subtitle: Text('${r['from_date']} to ${r['to_date']}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}