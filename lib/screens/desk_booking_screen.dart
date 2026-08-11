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

    setState(() {
      _rooms = List<Map<String, dynamic>>.from(rooms);
      _bookings = List<Map<String, dynamic>>.from(bookings);
      _myBooking = myBooking != null ? Map<String, dynamic>.from(myBooking) : null;
      _loading = false;
    });
  }

  Future<void> _bookRoom(int roomId, String roomNumber) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    await _supabase.from('desk_bookings').upsert({
      'desk_id': roomId,
      'employee_id': widget.user['employee_id'],
      'employee_name': widget.user['name'],
      'booking_date': dateStr,
      'status': 'active',
    });
    await _supabase.from('desks').update({'status': 'Booked', 'booked_by': widget.user['employee_id']}).eq('id', roomId);
    _loadData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room $roomNumber booked! ✅'), backgroundColor: Colors.green));
  }

  Future<void> _cancelBooking() async {
    if (_myBooking == null) return;
    final roomId = _myBooking!['desk_id'];
    await _supabase.from('desk_bookings').delete().eq('id', _myBooking!['id']);
    await _supabase.from('desks').update({'status': 'Available', 'booked_by': null}).eq('id', roomId);
    _loadData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled'), backgroundColor: Colors.orange));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
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

  @override
  Widget build(BuildContext context) {
    final floors = ['All', ..._rooms.map((d) => d['floor']?.toString() ?? '').toSet()];
    final filteredRooms = _selectedFloor == 'All' ? _rooms : _rooms.where((d) => d['floor'] == _selectedFloor).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('🏢 Room Booking'), actions: [IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate)]),
      body: Column(
        children: [
          Container(padding: const EdgeInsets.all(12), color: const Color(0xFF1A1A1A), child: Row(children: [
            Text(DateFormat('EEEE, MMM d').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_myBooking != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text('Room ${_myBooking!['desks']?['desk_number'] ?? ''}', style: const TextStyle(color: Colors.green, fontSize: 12))),
          ])),
          SizedBox(height: 45, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), itemCount: floors.length, itemBuilder: (context, index) {
            final f = floors[index];
            return Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(f), selected: f == _selectedFloor, onSelected: (_) => setState(() => _selectedFloor = f), selectedColor: const Color(0xFFCC0000).withOpacity(0.1), checkmarkColor: const Color(0xFFCC0000)));
          })),
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            _legendDot(Colors.green, 'Available'), const SizedBox(width: 12),
            _legendDot(Colors.blue, 'Booked'), const SizedBox(width: 12),
            _legendDot(Colors.orange, 'Occupied'), const SizedBox(width: 12),
            _legendDot(Colors.red, 'Maintenance'),
          ])),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1),
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = filteredRooms[index];
                      final status = room['status'] ?? 'Available';
                      final color = _statusColor(status);
                      final isMine = _myBooking != null && _myBooking!['desk_id'] == room['id'];
                      final isAvailable = status == 'Available';
                      final bookedUntil = room['booked_until'] != null ? DateTime.parse(room['booked_until'].toString()) : null;
                      return GestureDetector(
                        onTap: isMine ? _cancelBooking : (isAvailable ? () => _bookRoom(room['id'], room['desk_number']?.toString() ?? '') : null),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFF38A169) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isMine ? Colors.green : color, width: isMine ? 2 : 1),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(isMine ? Icons.check_circle : Icons.meeting_room, color: isMine ? Colors.white : color, size: 32),
                            const SizedBox(height: 6),
                            Text('Room ${room['desk_number']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isMine ? Colors.white : const Color(0xFF1A1A1A))),
                            Text(room['floor'] ?? '', style: TextStyle(fontSize: 10, color: isMine ? Colors.white70 : Colors.grey.shade600)),
                            Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: isMine ? Colors.white24 : color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: isMine ? Colors.white : color, fontSize: 10, fontWeight: FontWeight.bold))),
                            if (bookedUntil != null) Text('Until ${DateFormat('HH:mm').format(bookedUntil)}', style: TextStyle(fontSize: 9, color: isMine ? Colors.white54 : Colors.grey.shade500)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          if (_myBooking != null)
            Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _cancelBooking, icon: const Icon(Icons.cancel, color: Colors.red), label: const Text('Cancel My Booking', style: TextStyle(color: Colors.red)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red))))),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }
}