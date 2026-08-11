import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminRoomManager extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminRoomManager({super.key, required this.user});

  @override
  State<AdminRoomManager> createState() => _AdminRoomManagerState();
}

class _AdminRoomManagerState extends State<AdminRoomManager> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
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
      _rooms = List<Map<String, dynamic>>.from(data);
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
            TextField(controller: numberController, decoration: const InputDecoration(labelText: 'Room Number', hintText: 'e.g., CR-04', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: floorController, decoration: const InputDecoration(labelText: 'Floor/Location', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: zoneController, decoration: const InputDecoration(labelText: 'Zone', border: OutlineInputBorder())),
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
                'status': 'Available',
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

  Future<void> _setRoomStatus(Map<String, dynamic> room) async {
    String status = room['status'] ?? 'Available';
    final notesController = TextEditingController(text: room['booking_notes'] ?? '');
    DateTime? bookedUntil = room['booked_until'] != null ? DateTime.parse(room['booked_until'].toString()) : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Room ${room['desk_number']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: ['Available', 'Booked', 'Occupied', 'Maintenance'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setDialogState(() => status = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: Text(bookedUntil != null ? 'Until: ${DateFormat('MMM d, h:mm a').format(bookedUntil!)}' : 'Set time limit'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(hours: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (date != null) {
                      final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))));
                      if (time != null) {
                        setDialogState(() => bookedUntil = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                      }
                    }
                  },
                ),
                if (status == 'Booked')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Notify user when booking is confirmed', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _supabase.from('desks').update({
                    'status': status,
                    'booking_notes': notesController.text.trim(),
                    'booked_until': bookedUntil?.toIso8601String(),
                  }).eq('id', room['id']);
                  _loadRooms();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room ${room['desk_number']} updated to $status'), backgroundColor: Colors.green));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
                child: const Text('Update'),
              ),
            ],
          );
        },
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

  Color _statusColor(String? status) {
    switch (status) {
      case 'Available': return Colors.green;
      case 'Booked': return Colors.blue;
      case 'Occupied': return Colors.orange;
      case 'Maintenance': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'Available': return Icons.check_circle;
      case 'Booked': return Icons.book_online;
      case 'Occupied': return Icons.meeting_room;
      case 'Maintenance': return Icons.build;
      default: return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final floors = _rooms.map((d) => d['floor']?.toString() ?? '').toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏢 Room Manager'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addRoom),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : RefreshIndicator(
              onRefresh: _loadRooms,
              child: _rooms.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.meeting_room, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No rooms yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(onPressed: _addRoom, icon: const Icon(Icons.add), label: const Text('Add First Room'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000))),
                    ]))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: floors.map((floor) {
                        final floorRooms = _rooms.where((d) => d['floor'] == floor).toList();
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(floor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)))),
                          ...floorRooms.map((room) {
                            final isActive = room['is_active'] == true;
                            final status = room['status'] ?? 'Available';
                            final color = _statusColor(status);
                            final bookedUntil = room['booked_until'] != null ? DateTime.parse(room['booked_until'].toString()) : null;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color, width: 2)),
                              child: ExpansionTile(
                                leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(_statusIcon(status), color: color, size: 20)),
                                title: Text('Room ${room['desk_number']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Row(children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
                                  if (!isActive) const Text(' (Inactive)', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                ]),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      _detailRow('Floor', room['floor'] ?? ''),
                                      _detailRow('Zone', room['zone'] ?? 'N/A'),
                                      _detailRow('Status', status),
                                      if (bookedUntil != null) _detailRow('Booked Until', DateFormat('MMM d, yyyy - h:mm a').format(bookedUntil)),
                                      if (room['booking_notes'] != null && room['booking_notes'].toString().isNotEmpty) _detailRow('Notes', room['booking_notes']),
                                      const SizedBox(height: 12),
                                      Row(children: [
                                        Expanded(child: ElevatedButton.icon(onPressed: () => _setRoomStatus(room), icon: const Icon(Icons.edit, size: 16), label: const Text('Set Status'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)))),
                                        const SizedBox(width: 8),
                                        IconButton(icon: Icon(isActive ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => _toggleRoom(room['id'], isActive), tooltip: isActive ? 'Deactivate' : 'Activate'),
                                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRoom(room['id']), tooltip: 'Delete'),
                                      ]),
                                    ]),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ]);
                      }).toList(),
                    ),
            ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}