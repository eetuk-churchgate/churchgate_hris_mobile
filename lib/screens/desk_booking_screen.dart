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
  List<Map<String, dynamic>> _desks = [];
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
    
    final desks = await _supabase.from('desks').select('*').eq('is_active', true);
    final bookings = await _supabase.from('desk_bookings').select('*').eq('booking_date', dateStr);
    final myBooking = await _supabase.from('desk_bookings').select('*, desks(*)').eq('employee_id', widget.user['employee_id']).eq('booking_date', dateStr).maybeSingle();

    setState(() {
      _desks = List<Map<String, dynamic>>.from(desks);
      _bookings = List<Map<String, dynamic>>.from(bookings);
      _myBooking = myBooking != null ? Map<String, dynamic>.from(myBooking) : null;
      _loading = false;
    });
  }

  Future<void> _bookDesk(int deskId, String deskNumber) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    await _supabase.from('desk_bookings').upsert({
      'desk_id': deskId,
      'employee_id': widget.user['employee_id'],
      'employee_name': widget.user['name'],
      'booking_date': dateStr,
      'status': 'active',
    });
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Desk $deskNumber booked! ✅'), backgroundColor: Colors.green));
  }

  Future<void> _cancelBooking() async {
    if (_myBooking == null) return;
    await _supabase.from('desk_bookings').delete().eq('id', _myBooking!['id']);
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled'), backgroundColor: Colors.orange));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final floors = ['All', ..._desks.map((d) => d['floor']?.toString() ?? '').toSet()];
    final filteredDesks = _selectedFloor == 'All' ? _desks : _desks.where((d) => d['floor'] == _selectedFloor).toList();
    final bookedDeskIds = _bookings.map((b) => b['desk_id']).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏢 Desk Booking'),
        actions: [IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate)],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                Text(DateFormat('EEEE, MMM d').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_myBooking != null)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text('Desk ${_myBooking!['desks']?['desk_number'] ?? ''}', style: const TextStyle(color: Colors.green, fontSize: 12))),
              ],
            ),
          ),
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: floors.length,
              itemBuilder: (context, index) {
                final f = floors[index];
                final isSelected = f == _selectedFloor;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(label: Text(f), selected: isSelected, onSelected: (_) => setState(() => _selectedFloor = f), selectedColor: const Color(0xFFCC0000).withOpacity(0.1), checkmarkColor: const Color(0xFFCC0000)),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1),
                    itemCount: filteredDesks.length,
                    itemBuilder: (context, index) {
                      final desk = filteredDesks[index];
                      final deskId = desk['id'];
                      final isBooked = bookedDeskIds.contains(deskId);
                      final isMine = _myBooking != null && _myBooking!['desk_id'] == deskId;
                      return GestureDetector(
                        onTap: isBooked && !isMine ? null : () => isMine ? _cancelBooking() : _bookDesk(deskId, desk['desk_number']?.toString() ?? ''),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFF38A169) : isBooked ? Colors.grey.shade300 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isMine ? Colors.green : isBooked ? Colors.grey : const Color(0xFFE8DCC8), width: isMine ? 2 : 1),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(isBooked ? Icons.event_seat : Icons.chair, color: isMine ? Colors.white : isBooked ? Colors.grey : const Color(0xFFCC0000), size: 28),
                            const SizedBox(height: 4),
                            Text(desk['desk_number']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: isMine ? Colors.white : const Color(0xFF1A1A1A))),
                            Text(desk['floor']?.toString() ?? '', style: TextStyle(fontSize: 10, color: isMine ? Colors.white70 : Colors.grey.shade600)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          if (_myBooking != null)
            Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _cancelBooking, icon: const Icon(Icons.cancel, color: Colors.red), label: const Text('Cancel My Booking', style: TextStyle(color: Colors.red)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)))))
        ],
      ),
    );
  }
}