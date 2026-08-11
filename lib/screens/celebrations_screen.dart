import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class CelebrationsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CelebrationsScreen({super.key, required this.user});

  @override
  State<CelebrationsScreen> createState() => _CelebrationsScreenState();
}

class _CelebrationsScreenState extends State<CelebrationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _birthdays = [];
  List<Map<String, dynamic>> _anniversaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCelebrations();
  }

  Future<void> _loadCelebrations() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final currentMonth = now.month;

    final employees = await _supabase
        .from('employees')
        .select('employee_id, first_name, last_name, date_of_birth, join_date, position, department, phone')
        .eq('status', 'Active');

    final allEmployees = List<Map<String, dynamic>>.from(employees);
    
    final birthdays = allEmployees.where((e) {
      if (e['date_of_birth'] == null) return false;
      final dob = DateTime.tryParse(e['date_of_birth'].toString());
      return dob != null && dob.month == currentMonth;
    }).toList();
    birthdays.sort((a, b) => DateTime.parse(a['date_of_birth'].toString()).day.compareTo(DateTime.parse(b['date_of_birth'].toString()).day));

    final anniversaries = allEmployees.where((e) {
      if (e['join_date'] == null) return false;
      final jd = DateTime.tryParse(e['join_date'].toString());
      return jd != null && jd.month == currentMonth;
    }).toList();
    anniversaries.sort((a, b) => DateTime.parse(a['join_date'].toString()).day.compareTo(DateTime.parse(b['join_date'].toString()).day));

    setState(() {
      _birthdays = birthdays;
      _anniversaries = anniversaries;
      _loading = false;
    });
  }

  Future<void> _sendBirthdayWish(Map<String, dynamic> emp) async {
    final empId = emp['employee_id']?.toString() ?? '';
    final empName = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}';
    final currentUserName = widget.user['name'] ?? '';
    final currentUserId = widget.user['employee_id'] ?? '';

    final birthdayEmojis = ['🎂', '🎉', '🎊', '🎁', '🥳', '🎈', '💐', '🎀'];
    final randomEmoji = birthdayEmojis[DateTime.now().millisecond % birthdayEmojis.length];
    final message = '🎂 Happy Birthday $empName! $randomEmoji Wishing you an amazing day filled with joy and celebration! 🎉🎁';

    try {
      final convId = await ChatService.createDMConversation(
        currentUserId, currentUserName, empId, empName,
      );

      if (convId != null) {
        await ChatService.sendMessage(
          conversationId: convId,
          senderId: currentUserId,
          senderName: currentUserName,
          message: message,
          messageType: 'text',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Birthday wish sent to $empName! 🎉'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not create conversation'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _callEmployee(Map<String, dynamic> emp) async {
    final phone = emp['phone']?.toString();
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _showEmployeeOptions(Map<String, dynamic> emp, Color color) {
    final isBirthday = emp['date_of_birth'] != null;
    final empName = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}';
    final title = isBirthday ? '🎂 $empName' : '🎊 $empName';

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: color.withOpacity(0.1),
                child: Row(children: [
                  CircleAvatar(backgroundColor: color, child: Icon(isBirthday ? Icons.cake : Icons.work, color: Colors.white)),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ),
              if (isBirthday)
                ListTile(
                  leading: const Icon(Icons.message, color: Color(0xFFCC0000)),
                  title: const Text('Send Birthday Wish'),
                  subtitle: const Text('Send an automatic birthday message via chat'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendBirthdayWish(emp);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF3182CE)),
                title: const Text('Open Chat'),
                subtitle: Text('Chat directly with ${emp['first_name'] ?? ''}'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: widget.user)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone, color: Color(0xFF38A169)),
                title: const Text('Call'),
                subtitle: Text(emp['phone']?.toString() ?? 'No phone number'),
                onTap: () {
                  Navigator.pop(ctx);
                  _callEmployee(emp);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Color(0xFFD4AF37)),
                title: const Text('Share via WhatsApp'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final message = isBirthday 
                      ? '🎂 Happy Birthday ${empName}! 🎉' 
                      : '🎊 Happy Work Anniversary ${empName}! 🎉';
                  final url = ChatService.getWhatsAppShareUrl(message);
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎉 Celebrations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : RefreshIndicator(
              onRefresh: _loadCelebrations,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildSection('🎂 Birthdays This Month', _birthdays, Colors.pink, true),
                  const SizedBox(height: 20),
                  _buildSection('🎊 Work Anniversaries This Month', _anniversaries, const Color(0xFFD4AF37), false),
                ]),
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items, Color color, bool isBirthday) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
      const SizedBox(height: 12),
      if (items.isEmpty)
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8DCC8))), child: const Center(child: Text('None this month'))),
      ...items.map((emp) {
        final date = isBirthday ? emp['date_of_birth'] : emp['join_date'];
        final day = DateTime.tryParse(date?.toString() ?? '')?.day ?? 0;
        final years = !isBirthday ? DateTime.now().year - (DateTime.tryParse(date?.toString() ?? '')?.year ?? 0) : null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () => _showEmployeeOptions(emp, color),
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(isBirthday ? Icons.cake : Icons.work, color: color)),
            title: Text('${emp['first_name']} ${emp['last_name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${emp['position'] ?? ''} • ${emp['department'] ?? ''}\n${DateFormat('MMMM d').format(DateTime(DateTime.now().year, DateTime.now().month, day))}${years != null ? ' ($years years)' : ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('Day $day', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        );
      }),
    ]);
  }
}