import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class KudosScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const KudosScreen({super.key, required this.user});

  @override
  State<KudosScreen> createState() => _KudosScreenState();
}

class _KudosScreenState extends State<KudosScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _kudos = [];
  bool _loading = true;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Teamwork', 'Innovation', 'Leadership', 'Customer Service', 'General'];

  @override
  void initState() {
    super.initState();
    _loadKudos();
  }

  Future<void> _loadKudos() async {
    setState(() => _loading = true);
    final data = await _supabase
        .from('kudos')
        .select('*')
        .order('created_at', ascending: false)
        .limit(50);
    setState(() {
      _kudos = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _giveKudos() async {
    final messageController = TextEditingController();
    String category = 'General';
    Map<String, dynamic>? selectedEmployee;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Give Kudos 👏'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder(
                  future: _supabase.from('employees').select('employee_id, first_name, last_name').eq('status', 'Active').limit(100),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    final employees = List<Map<String, dynamic>>.from(snapshot.data!);
                    return DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedEmployee,
                      decoration: const InputDecoration(labelText: 'Recognize', border: OutlineInputBorder()),
                      items: employees.map((emp) {
                        return DropdownMenuItem(
                          value: emp,
                          child: Text('${emp['first_name']} ${emp['last_name']}'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedEmployee = val),
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: _categories.where((c) => c != 'All').map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => category = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder(), hintText: 'What did they do?'),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedEmployee == null || messageController.text.trim().isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _supabase.from('kudos').insert({
                          'sender_id': widget.user['employee_id'],
                          'sender_name': widget.user['name'] ?? 'Anonymous',
                          'receiver_id': selectedEmployee!['employee_id'],
                          'receiver_name': '${selectedEmployee!['first_name']} ${selectedEmployee!['last_name']}',
                          'message': messageController.text.trim(),
                          'category': category,
                        });
                        _loadKudos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kudos sent! 🎉'), backgroundColor: Colors.green),
                        );
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
                child: const Text('Send Kudos'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _likeKudos(int kudosId) async {
    final empId = widget.user['employee_id'] ?? '';
    final existing = await _supabase
        .from('kudos_likes')
        .select()
        .eq('kudos_id', kudosId)
        .eq('employee_id', empId)
        .maybeSingle();

    if (existing != null) {
      await _supabase.from('kudos_likes').delete().eq('id', existing['id']);
    } else {
      await _supabase.from('kudos_likes').insert({'kudos_id': kudosId, 'employee_id': empId});
    }
    _loadKudos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Recognition Wall')),
      floatingActionButton: FloatingActionButton(
        onPressed: _giveKudos,
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: const Color(0xFFD4AF37).withOpacity(0.2),
                    checkmarkColor: const Color(0xFFD4AF37),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
                : RefreshIndicator(
                    onRefresh: _loadKudos,
                    child: _kudos.isEmpty
                        ? const Center(child: Text('No kudos yet. Be the first! 🎉'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _kudos.length,
                            itemBuilder: (context, index) {
                              final k = _kudos[index];
                              if (_selectedCategory != 'All' && k['category'] != _selectedCategory) return const SizedBox();
                              return _buildKudosCard(k);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKudosCard(Map<String, dynamic> k) {
    final categoryIcons = {
      'Teamwork': Icons.group,
      'Innovation': Icons.lightbulb,
      'Leadership': Icons.star,
      'Customer Service': Icons.support_agent,
      'General': Icons.favorite,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: const Color(0xFFCC0000), child: Text(k['sender_name']?.toString().substring(0, 1) ?? '', style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 8),
                Text(k['sender_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Text(' → ', style: TextStyle(fontWeight: FontWeight.bold)),
                CircleAvatar(radius: 20, backgroundColor: const Color(0xFFD4AF37), child: Text(k['receiver_name']?.toString().substring(0, 1) ?? '', style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 8),
                Text(k['receiver_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(categoryIcons[k['category']] ?? Icons.favorite, color: const Color(0xFFD4AF37), size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(k['message'] ?? '', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _likeKudos(k['id']),
                  child: Row(children: [
                    const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${k['likes'] ?? 0}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 16),
                Text(DateFormat('MMM d').format(DateTime.parse(k['created_at'].toString())), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}