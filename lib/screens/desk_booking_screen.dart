import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DeskBookingScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DeskBookingScreen({super.key, required this.user});

  @override
  State<DeskBookingScreen> createState() => _DeskBookingScreenState();
}

class _DeskBookingScreenState extends State<DeskBookingScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _bookings = [];
  Map<String, dynamic>? _myBooking;
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedFloor = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final rooms = await _supabase.from('desks').select('*').eq('is_active', true);
    final bookings = await _supabase.from('desk_bookings').select('*').eq('booking_date', dateStr);
    final myBooking = await _supabase.from('desk_bookings').select('*, desks(*)').eq('employee_id', widget.user['employee_id']).eq('booking_date', dateStr).maybeSingle();
    setState(() { _rooms = List<Map<String, dynamic>>.from(rooms); _bookings = List<Map<String, dynamic>>.from(bookings); _myBooking = myBooking != null ? Map<String, dynamic>.from(myBooking) : null; _loading = false; });
  }

  Future<void> _showBookingDialog(Map<String, dynamic> room) async {
    final nameCtrl = TextEditingController(text: widget.user['name'] ?? '');
    final notesCtrl = TextEditingController();
    DateTime bookingDate = _selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Book Room ${room['desk_number']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Your Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Date'), subtitle: Text(DateFormat('EEE, MMM d, yyyy').format(bookingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: bookingDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                if (picked != null) setDialogState(() => bookingDate = picked);
              },
            ),
            Row(children: [
              Expanded(child: ListTile(title: const Text('Start'), subtitle: Text(startTime != null ? startTime!.format(context) : 'Select'), trailing: const Icon(Icons.access_time), onTap: () async { final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now()); if (t != null) setDialogState(() => startTime = t); })),
              Expanded(child: ListTile(title: const Text('End'), subtitle: Text(endTime != null ? endTime!.format(context) : 'Select'), trailing: const Icon(Icons.access_time), onTap: () async { final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1)); if (t != null) setDialogState(() => endTime = t); })),
            ]),
            const SizedBox(height: 12),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () async {
              Navigator.pop(ctx);
              final dateStr = DateFormat('yyyy-MM-dd').format(bookingDate);
              await _supabase.from('desk_bookings').upsert({'desk_id': room['id'], 'employee_id': widget.user['employee_id'], 'employee_name': nameCtrl.text.trim(), 'booking_date': dateStr, 'status': 'active'});
              DateTime? bookedUntil;
              if (endTime != null) bookedUntil = DateTime(bookingDate.year, bookingDate.month, bookingDate.day, endTime!.hour, endTime!.minute);
              await _supabase.from('desks').update({'status': 'Booked', 'booked_by': widget.user['employee_id'], 'booked_until': bookedUntil?.toIso8601String(), 'booking_notes': notesCtrl.text.trim()}).eq('id', room['id']);
              _loadData();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room ${room['desk_number']} booked! ✅'), backgroundColor: Colors.green));
            }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)), child: const Text('Confirm Booking')),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelBooking() async {
    if (_myBooking == null) return;
    final roomId = _myBooking!['desk_id'];
    await _supabase.from('desk_bookings').delete().eq('id', _myBooking!['id']);
    await _supabase.from('desks').update({'status': 'Available', 'booked_by': null, 'booked_until': null, 'booking_notes': null}).eq('id', roomId);
    _loadData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled'), backgroundColor: Colors.orange));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (picked != null) { setState(() => _selectedDate = picked); _loadData(); }
  }

  Color _statusColor(String? status) { switch (status) { case 'Available': return Colors.green; case 'Booked': return Colors.blue; case 'Occupied': return Colors.orange; case 'Maintenance': return Colors.red; default: return Colors.grey; } }

  @override
  Widget build(BuildContext context) {
    final floors = ['All', ..._rooms.map((d) => d['floor']?.toString() ?? '').toSet()];
    final filteredRooms = _selectedFloor == 'All' ? _rooms : _rooms.where((d) => d['floor'] == _selectedFloor).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('🏢 Room Booking'), actions: [IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate)]),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(12), color: const Color(0xFF1A1A1A), child: Row(children: [Text(DateFormat('EEEE, MMM d').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const Spacer(), if (_myBooking != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text('Room ${_myBooking!['desks']?['desk_number'] ?? ''}', style: const TextStyle(color: Colors.green, fontSize: 12)))])),
        SizedBox(height: 45, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), itemCount: floors.length, itemBuilder: (context, index) { final f = floors[index]; return Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(f), selected: f == _selectedFloor, onSelected: (_) => setState(() => _selectedFloor = f), selectedColor: const Color(0xFFCC0000).withOpacity(0.1), checkmarkColor: const Color(0xFFCC0000))); })),
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [_legendDot(Colors.green, 'Available'), const SizedBox(width: 12), _legendDot(Colors.blue, 'Booked'), const SizedBox(width: 12), _legendDot(Colors.orange, 'Occupied'), const SizedBox(width: 12), _legendDot(Colors.red, 'Maintenance')])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))) : GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1), itemCount: filteredRooms.length, itemBuilder: (context, index) {
          final room = filteredRooms[index]; final status = room['status'] ?? 'Available'; final color = _statusColor(status); final isMine = _myBooking != null && _myBooking!['desk_id'] == room['id']; final isAvailable = status == 'Available'; final bookedUntil = room['booked_until'] != null ? DateTime.parse(room['booked_until'].toString()) : null;
          return GestureDetector(onTap: isMine ? _cancelBooking : (isAvailable ? () => _showBookingDialog(room) : null), child: Container(decoration: BoxDecoration(color: isMine ? const Color(0xFF38A169) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isMine ? Colors.green : color, width: isMine ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isMine ? Icons.check_circle : Icons.meeting_room, color: isMine ? Colors.white : color, size: 32), const SizedBox(height: 6), Text('Room ${room['desk_number']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isMine ? Colors.white : const Color(0xFF1A1A1A))), Text(room['floor'] ?? '', style: TextStyle(fontSize: 10, color: isMine ? Colors.white70 : Colors.grey.shade600)), Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: isMine ? Colors.white24 : color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: isMine ? Colors.white : color, fontSize: 10, fontWeight: FontWeight.bold))), if (bookedUntil != null) Text('Until ${DateFormat('HH:mm').format(bookedUntil)}', style: TextStyle(fontSize: 9, color: isMine ? Colors.white54 : Colors.grey.shade500))])));
        })),
        if (_myBooking != null) Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _cancelBooking, icon: const Icon(Icons.cancel, color: Colors.red), label: const Text('Cancel My Booking', style: TextStyle(color: Colors.red)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red))))),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) { return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))]); }
}