import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import 'directory_screen.dart';
import '../services/engagement_service.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _onlineUsers = [];
  Map<String, int> _unreadCounts = {};
  bool _loading = true;
  int _totalUnread = 0;

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Team Chat');
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _subscribeToMessages();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final userEmail = widget.user['email'] ?? '';
      final userDept = widget.user['department'] ?? '';
      
      final conversations = await ChatService.getConversations(userEmail);
      final groups = await _supabase.from('chat_messages').select('*').eq('is_group', true).order('created_at', ascending: false);
      
      int unread = 0;
      for (var c in conversations) {
        final count = await ChatService.getUnreadCount(userEmail);
        _unreadCounts[c['sender_email']] = count;
        unread += count;
      }
      
      setState(() {
        _conversations = conversations;
        _totalUnread = unread;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _subscribeToMessages() {
    _supabase.from('chat_messages').stream(primaryKey: ['id']).listen((data) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('💬 Team Chat'),
            if (_totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$_totalUnread', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFCC0000),
          labelColor: const Color(0xFFCC0000),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Groups'),
            Tab(text: 'Online'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChatsList(),
                _buildGroupsList(),
                _buildOnlineList(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFCC0000),
        onPressed: () => _showNewChatDialog(),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildChatsList() {
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('No conversations yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _showNewChatDialog, child: const Text('Start a Chat')),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        final unread = _unreadCounts[conv['sender_email']] ?? 0;
        return _buildChatTile(conv, unread);
      },
    );
  }

  Widget _buildChatTile(Map<String, dynamic> conv, int unread) {
    final name = conv['sender_name'] ?? 'Unknown';
    final lastMsg = conv['message'] ?? '';
    final time = _formatTime(conv['created_at']?.toString());
    final isOnline = _onlineUsers.any((u) => u['email'] == conv['sender_email']);

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFCC0000),
            child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (isOnline)
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(child: Text(name, style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal))),
          Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? Colors.black87 : Colors.grey))),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFCC0000), shape: BoxShape.circle),
              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatDetailScreen(user: widget.user, chatPartner: {'name': name, 'email': conv['sender_email']}),
        )).then((_) => _loadData());
      },
    );
  }

  Widget _buildGroupsList() {
    final dept = widget.user['department'] ?? '';
    return ListView(
      children: [
        _buildGroupTile('$dept Team', 'Department group chat', Icons.groups, dept),
        _buildGroupTile('All Staff', 'Company-wide announcements', Icons.business, 'all'),
        _buildGroupTile('Management', 'Leadership team', Icons.stars, 'management'),
        _buildGroupTile('Social', 'Fun & social chat', Icons.celebration, 'social'),
      ],
    );
  }

  Widget _buildGroupTile(String name, String desc, IconData icon, String dept) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFCC0000).withOpacity(0.1),
        child: Icon(icon, color: const Color(0xFFCC0000)),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatDetailScreen(user: widget.user, isGroup: true, department: dept),
        ));
      },
    );
  }

  Widget _buildOnlineList() {
    return const Center(child: Text('Online users will appear here', style: TextStyle(color: Colors.grey)));
  }

  void _showNewChatDialog() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectoryScreen()));
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (dt.day == now.day) return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      if (dt.day == now.day - 1) return 'Yesterday';
      return '${dt.day}/${dt.month}';
    } catch (e) {
      return '';
    }
  }
}