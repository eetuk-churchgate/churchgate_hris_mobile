import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRoomManager extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminRoomManager({super.key, required this.user});

  @override
  State<AdminRoomManager> createState() => _AdminRoomManagerState();
}

class _AdminRoomManagerState extends State<AdminRoomManager> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _desks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    final data = await _supabase.from('desks').select('*').order('floor').order('desk_number');
    setState(() {
      _desks = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _addRoom() async {
    final numberController = TextEditingController();
    final floorController = TextEditingController();
    final zoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: numberController, decoration: const InputDecoration(labelText: 'Room Number', hintText: 'e.g., A06', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: floorController, decoration: const InputDecoration(labelText: 'Floor', hintText: 'e.g., Ground Floor', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: zoneController, decoration: const InputDecoration(labelText: 'Zone', hintText: 'e.g., Zone A', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: numberController.text.isEmpty || floorController.text.isEmpty ? null : () async {
              Navigator.pop(ctx);
              await _supabase.from('desks').insert({
                'desk_number': numberController.text.trim(),
                'floor': floorController.text.trim(),
                'zone': zoneController.text.trim(),
                'is_active': true,
              });
              _loadRooms();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room added! ✅'), backgroundColor: Colors.green));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBulkRooms() async {
    final prefixController = TextEditingController();
    final floorController = TextEditingController();
    final zoneController = TextEditingController();
    final countController = TextEditingController(text: '5');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Multiple Rooms'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: prefixController, decoration: const InputDecoration(labelText: 'Prefix', hintText: 'e.g., A', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: floorController, decoration: const InputDecoration(labelText: 'Floor', hintText: 'e.g., Ground Floor', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: zoneController, decoration: const InputDecoration(labelText: 'Zone', hintText: 'e.g., Zone A', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: countController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Count', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: prefixController.text.isEmpty || floorController.text.isEmpty ? null : () async {
              Navigator.pop(ctx);
              final prefix = prefixController.text.trim();
              final floor = floorController.text.trim();
              final zone = zoneController.text.trim();
              final count = int.tryParse(countController.text) ?? 5;
              final startNum = _desks.where((d) => d['desk_number']?.toString().startsWith(prefix) == true).length + 1;
              
              for (int i = 0; i < count; i++) {
                await _supabase.from('desks').insert({
                  'desk_number': '$prefix${(startNum + i).toString().padLeft(2, '0')}',
                  'floor': floor,
                  'zone': zone,
                  'is_active': true,
                });
              }
              _loadRooms();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count desks added! ✅'), backgroundColor: Colors.green));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
            child: const Text('Add All'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRoom(int id, bool currentStatus) async {
    await _supabase.from('desks').update({'is_active': !currentStatus}).eq('id', id);
    _loadRooms();
  }

  Future<void> _deleteRoom(int id) async {
    await _supabase.from('desks').delete().eq('id', id);
    _loadRooms();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room deleted'), backgroundColor: Colors.orange));
  }

  @override
  Widget build(BuildContext context) {
    final floors = _desks.map((d) => d['floor']?.toString() ?? '').toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏢 Room Manager'),
        actions: [
          PopupMenuButton(
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'single', child: ListTile(leading: Icon(Icons.add), title: Text('Add Single Room'))),
              const PopupMenuItem(value: 'bulk', child: ListTile(leading: Icon(Icons.add_box), title: Text('Add Multiple Rooms'))),
            ],
            onSelected: (val) {
              if (val == 'single') _addRoom();
              if (val == 'bulk') _addBulkRooms();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : RefreshIndicator(
              onRefresh: _loadRooms,
              child: _desks.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chair, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No desks yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(onPressed: _addRoom, icon: const Icon(Icons.add), label: const Text('Add First Room'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000))),
                    ]))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: floors.map((floor) {
                        final floorRooms = _desks.where((d) => d['floor'] == floor).toList();
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(floor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)))),
                          ...floorRooms.map((desk) {
                            final isActive = desk['is_active'] == true;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1), child: Icon(Icons.chair, color: isActive ? Colors.green : Colors.grey, size: 20)),
                                title: Text('Room ${desk['desk_number']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${desk['floor']} • Zone: ${desk['zone'] ?? 'N/A'}'),
                                trailing: PopupMenuButton(
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(child: Text(isActive ? 'Deactivate' : 'Activate'), onTap: () => _toggleRoom(desk['id'], isActive)),
                                    PopupMenuItem(child: const Text('Delete', style: TextStyle(color: Colors.red)), onTap: () => _deleteRoom(desk['id'])),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ]);
                      }).toList(),
                    ),
            ),
    );
  }
}