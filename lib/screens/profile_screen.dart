import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _positionController;
  bool _editing = false;
  List<Map<String, dynamic>> _leaveBalances = [];
  bool _loadingBalances = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name'] ?? '');
    _emailController = TextEditingController(text: widget.user['email'] ?? '');
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _positionController = TextEditingController(text: widget.user['position'] ?? '');
    _loadLeaveBalances();
  }

  Future<void> _loadLeaveBalances() async {
    setState(() => _loadingBalances = true);
    try {
      final empId = widget.user['employee_id'] ?? '';
      final data = await _supabase
          .from('leave_balances')
          .select()
          .eq('employee_id', empId);
      
      setState(() => _leaveBalances = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      // Keep empty on error
    }
    setState(() => _loadingBalances = false);
  }

  Color _getLeaveColor(String leaveType) {
    switch (leaveType.toLowerCase()) {
      case 'annual leave':
        return Colors.green;
      case 'sick leave':
        return Colors.blue;
      case 'compassionate':
      case 'compassionate leave':
        return Colors.orange;
      case 'maternity':
      case 'maternity leave':
        return Colors.purple;
      case 'paternity':
      case 'paternity leave':
        return Colors.teal;
      case 'study leave':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.save : Icons.edit),
            onPressed: () {
              setState(() => _editing = !_editing);
              if (!_editing) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated!')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Photo
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFFCC0000),
                    child: Text(
                      '${widget.user['name']?.toString().substring(0, 1) ?? 'U'}',
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                  if (_editing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFCC0000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Profile Fields
            _buildField('Name', _nameController),
            _buildField('Email', _emailController),
            _buildField('Phone', _phoneController),
            _buildField('Position', _positionController),
            
            // Read-only fields
            _buildReadOnly('Department', widget.user['department'] ?? 'N/A'),
            _buildReadOnly('Employee ID', widget.user['employee_id'] ?? 'N/A'),
            _buildReadOnly('Role', widget.user['role'] ?? 'N/A'),
            _buildReadOnly('Region', widget.user['region'] ?? 'N/A'),
            _buildReadOnly('Subsidiary', widget.user['subsidiary'] ?? 'N/A'),
            _buildReadOnly('Join Date', widget.user['join_date']?.toString().substring(0, 10) ?? 'N/A'),
            
            const SizedBox(height: 24),
            
            // Leave Balance Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Leave Balances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFCC0000)),
                          onPressed: _loadLeaveBalances,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingBalances)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: Color(0xFFCC0000)),
                        ),
                      )
                    else if (_leaveBalances.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No leave balances found', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ..._leaveBalances.map((leave) {
                        final color = _getLeaveColor(leave['leave_type'] ?? '');
                        final balance = leave['balance']?.toString() ?? '0';
                        final entitled = leave['entitled']?.toString() ?? '0';
                        final taken = leave['total_taken']?.toString() ?? '0';
                        final year = leave['year']?.toString() ?? '';
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.beach_access, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        leave['leave_type'] ?? 'Leave',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      if (year.isNotEmpty)
                                        Text('Year: $year', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$balance days',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      'Entitled: $entitled | Taken: $taken',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        enabled: _editing,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: _editing ? Colors.white : Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildReadOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}