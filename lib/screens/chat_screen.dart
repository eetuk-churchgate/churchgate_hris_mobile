import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _onlineUsers = [];
  Map<int, String> _typingUsers = {};
  Map<String, dynamic>? _activeConversation;
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _messageSubscription;
  RealtimeChannel? _typingSubscription;
  Timer? _pollTimer;
  String? _replyingTo;
  String? _replyingToSender;
  bool _showEmojiPicker = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _allEmployees = [];

  final List<String> _quickEmojis = ['👍', '❤️', '😂', '🎉', '🔥', '💯', '🙏', '😊', '👏', '🚀'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _loadOnlineUsers();
    _setUserOnline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _messageSubscription?.unsubscribe();
    _typingSubscription?.unsubscribe();
    _pollTimer?.cancel();
    _setUserOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _setUserOffline();
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_activeConversation == null || !mounted) return;
      try {
        final latest = await ChatService.getMessages(_activeConversation!['id']);
        if (mounted && latest.length > _messages.length) {
          setState(() => _messages = latest);
          _scrollToBottom();
        }
      } catch (_) {}
    });
  }

  Future<void> _setUserOnline() async {
    await ChatService.setPresence(widget.user['employee_id'] ?? '', widget.user['name'] ?? '', true, device: 'mobile');
  }

  Future<void> _setUserOffline() async {
    await ChatService.setPresence(widget.user['employee_id'] ?? '', widget.user['name'] ?? '', false);
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final data = await ChatService.getConversations(widget.user['employee_id'] ?? '');
    // Load participant names for each DM conversation
    for (var conv in data) {
      if (conv['type'] == 'direct') {
        final participants = await ChatService.getParticipants(conv['id']);
        final other = participants.firstWhere(
          (p) => p['employee_id'] != widget.user['employee_id'],
          orElse: () => participants.isNotEmpty ? participants.first : {'employee_name': 'Unknown'},
        );
        conv['display_name'] = other['employee_name'] ?? 'Unknown';
      } else {
        conv['display_name'] = conv['name'] ?? 'Group';
      }
    }
    setState(() { _conversations = data; _loading = false; });
  }

  Future<void> _loadOnlineUsers() async {
    final data = await ChatService.getOnlineUsers();
    if (mounted) setState(() => _onlineUsers = data);
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    _pollTimer?.cancel();
    
    setState(() { _activeConversation = conversation; _messages = []; });
    _messageSubscription?.unsubscribe();
    _typingSubscription?.unsubscribe();

    final messages = await ChatService.getMessages(conversation['id']);
    final participants = await ChatService.getParticipants(conversation['id']);
    await ChatService.markAsRead(conversation['id'], widget.user['employee_id'] ?? '');

    setState(() { _messages = messages; _participants = participants; });

    _messageSubscription = ChatService.subscribeToMessages(conversation['id'], (message) {
      if (mounted) {
        final exists = _messages.any((m) => m['id'] == message['id']);
        if (!exists) {
          setState(() { _messages.add(Map<String, dynamic>.from(message)); });
          ChatService.markAsRead(conversation['id'], widget.user['employee_id'] ?? '');
          _scrollToBottom();
        }
      }
    });

    _typingSubscription = ChatService.subscribeToTyping(conversation['id'], (typing) {
      if (mounted) {
        final empId = typing['employee_id']?.toString() ?? '';
        if (empId != widget.user['employee_id']) {
          setState(() {
            if (typing['is_typing'] == true) {
              _typingUsers[conversation['id']] = typing['employee_name']?.toString() ?? '';
            } else {
              _typingUsers.remove(conversation['id']);
            }
          });
        }
      }
    });

    _startPolling();
    _scrollToBottom();
    _loadConversations();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _replyingTo == null) return;
    if (_activeConversation == null) return;
    setState(() => _sending = true);

    final replyToId = _replyingTo != null ? int.tryParse(_replyingTo!) : null;
    final messageText = text;

    _messageController.clear();
    setState(() { _replyingTo = null; _replyingToSender = null; _showEmojiPicker = false; });

    try {
      await ChatService.sendMessage(
        conversationId: _activeConversation!['id'],
        senderId: widget.user['employee_id'] ?? '',
        senderName: widget.user['name'] ?? '',
        message: messageText, messageType: 'text', replyToId: replyToId,
      );
      await ChatService.setTyping(_activeConversation!['id'], widget.user['employee_id'] ?? '', widget.user['name'] ?? '', false);

      final updatedMessages = await ChatService.getMessages(_activeConversation!['id']);
      if (mounted) { setState(() => _messages = updatedMessages); _scrollToBottom(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red));
    }
    setState(() => _sending = false);
  }

  Future<void> _startNewChat() async {
    _searchController.clear();
    final employees = await _supabase.from('employees').select('employee_id, first_name, last_name, position, department').eq('status', 'Active').neq('employee_id', widget.user['employee_id'] ?? '').order('first_name').limit(1000);
    setState(() { _allEmployees = List<Map<String, dynamic>>.from(employees); _isSearching = true; _searchResults = _allEmployees; });
  }

  Future<void> _createDM(Map<String, dynamic> employee) async {
    final convId = await ChatService.createDMConversation(widget.user['employee_id'] ?? '', widget.user['name'] ?? '', employee['employee_id'] ?? '', '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}');
    if (convId != null) {
      setState(() => _isSearching = false);
      await _loadConversations();
      final conversations = await ChatService.getConversations(widget.user['employee_id'] ?? '');
      final newConv = conversations.firstWhere((c) => c['id'] == convId, orElse: () => conversations.first);
      _openConversation(newConv);
    }
  }

  Future<void> _createGroupChat() async {
    final nameController = TextEditingController();
    List<Map<String, String>> selectedMembers = [];
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Text('Create Group Chat'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Group Name', border: OutlineInputBorder())),
        const SizedBox(height: 12), const Text('Select Members:'), const SizedBox(height: 8),
        SizedBox(height: 200, child: FutureBuilder(
          future: _supabase.from('employees').select('employee_id, first_name, last_name').neq('employee_id', widget.user['employee_id']),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final employees = List<Map<String, dynamic>>.from(snapshot.data!);
            return ListView.builder(itemCount: employees.length, itemBuilder: (context, index) {
              final emp = employees[index];
              final empId = emp['employee_id']?.toString() ?? '';
              final empName = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}';
              return CheckboxListTile(title: Text(empName), subtitle: Text(empId), value: selectedMembers.any((m) => m['id'] == empId), onChanged: (val) {
                setDialogState(() { if (val == true) { selectedMembers.add({'id': empId, 'name': empName}); } else { selectedMembers.removeWhere((m) => m['id'] == empId); } });
              });
            });
          },
        )),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: selectedMembers.isEmpty || nameController.text.trim().isEmpty ? null : () async {
          Navigator.pop(ctx);
          await ChatService.createGroupConversation(nameController.text.trim(), widget.user['employee_id'] ?? '', widget.user['name'] ?? '', selectedMembers);
          _loadConversations();
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)), child: const Text('Create')),
      ],
    )));
  }

  Future<void> _makeCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _callEmployee(Map<String, dynamic> emp) async {
    final phone = emp['phone']?.toString();
    if (phone != null && phone.isNotEmpty) { await _makeCall(phone); } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available'), backgroundColor: Colors.orange)); }
  }

  Future<void> _callParticipant() async {
    final otherParticipant = _participants.firstWhere((p) => p['employee_id'] != widget.user['employee_id'], orElse: () => _participants.first);
    final empId = otherParticipant['employee_id']?.toString() ?? '';
    try {
      final empData = await _supabase.from('employees').select('phone').eq('employee_id', empId).maybeSingle();
      final phone = empData?['phone']?.toString();
      if (phone != null && phone.isNotEmpty) { await _makeCall(phone); } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available'), backgroundColor: Colors.orange)); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get phone number'), backgroundColor: Colors.orange)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: _activeConversation != null ? _buildChatHeader() : const Text('Team Chat'), actions: [
        if (_activeConversation != null) ...[IconButton(icon: const Icon(Icons.phone), onPressed: _callParticipant)],
        if (_activeConversation == null) PopupMenuButton(itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'new_chat', child: ListTile(leading: Icon(Icons.chat), title: Text('New Chat'))),
          const PopupMenuItem(value: 'new_group', child: ListTile(leading: Icon(Icons.group_add), title: Text('New Group'))),
        ], onSelected: (val) { if (val == 'new_chat') _startNewChat(); if (val == 'new_group') _createGroupChat(); }),
      ]),
      body: _isSearching ? _buildSearchView() : _activeConversation == null ? _buildConversationsList() : _buildChatView(),
    );
  }

  Widget _buildChatHeader() {
    final isGroup = _activeConversation!['type'] == 'group';
    final name = isGroup ? _activeConversation!['name'] ?? 'Group' : _participants.firstWhere((p) => p['employee_id'] != widget.user['employee_id'], orElse: () => {'employee_name': 'Unknown'})['employee_name'] ?? 'Unknown';
    final otherEmpId = isGroup ? null : _participants.firstWhere((p) => p['employee_id'] != widget.user['employee_id'], orElse: () => {'employee_id': null})['employee_id'];
    final isOnline = otherEmpId != null && _onlineUsers.any((u) => u['employee_id'] == otherEmpId);
    return GestureDetector(onTap: () { _pollTimer?.cancel(); setState(() => _activeConversation = null); }, child: Row(children: [
      Stack(children: [CircleAvatar(radius: 16, backgroundColor: isGroup ? const Color(0xFFD4AF37) : const Color(0xFFCC0000), child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14))), if (isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)))]),
      const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), if (_typingUsers.containsKey(_activeConversation!['id'])) Text('${_typingUsers[_activeConversation!['id']]} typing...', style: TextStyle(fontSize: 10, color: Colors.green.shade300))]),
    ]));
  }

  Widget _buildConversationsList() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
    return RefreshIndicator(onRefresh: () async { await _loadConversations(); await _loadOnlineUsers(); }, child: _conversations.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade400), const SizedBox(height: 16), Text('No conversations yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)), const SizedBox(height: 8),
      ElevatedButton.icon(onPressed: _startNewChat, icon: const Icon(Icons.add), label: const Text('Start a Chat'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000))),
    ])) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _conversations.length, itemBuilder: (context, index) => _buildConversationTile(_conversations[index])));
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final isGroup = conv['type'] == 'group';
    final name = conv['display_name'] ?? (isGroup ? (conv['name'] ?? 'Group') : 'Chat');
    final lastMsg = conv['last_message'] ?? 'No messages yet';
    final time = conv['last_message_at'] != null ? DateFormat('HH:mm').format(DateTime.parse(conv['last_message_at'].toString())) : '';
    return Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(
      leading: CircleAvatar(backgroundColor: isGroup ? const Color(0xFFD4AF37) : const Color(0xFFCC0000), child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16))),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      onTap: () => _openConversation(conv),
    ));
  }

  Widget _buildChatView() {
    return Column(children: [
      Expanded(child: GestureDetector(onTap: () => setState(() => _showEmojiPicker = false), child: ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(12), itemCount: _messages.length, itemBuilder: (context, index) { final msg = _messages[index]; return _buildMessageBubble(msg, msg['sender_id'] == widget.user['employee_id']); }))),
      _buildMessageInput(), if (_showEmojiPicker) _buildEmojiPicker(),
    ]);
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: GestureDetector(onLongPress: () => _showMessageOptions(msg), child: Container(margin: const EdgeInsets.only(bottom: 8), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isMe ? const Color(0xFFCC0000) : Colors.white, borderRadius: BorderRadius.circular(16).copyWith(bottomRight: isMe ? const Radius.circular(4) : null, bottomLeft: isMe ? null : const Radius.circular(4)), border: isMe ? null : Border.all(color: const Color(0xFFE8DCC8))), child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(msg['sender_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFCC0000)))),
      Text(msg['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : const Color(0xFF1A1A1A), fontSize: 14)), const SizedBox(height: 4),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(DateFormat('HH:mm').format(DateTime.parse(msg['sent_at'].toString())), style: TextStyle(fontSize: 10, color: isMe ? Colors.white54 : Colors.grey)),
        if (isMe) ...[const SizedBox(width: 4), Icon(msg['is_read'] == true ? Icons.done_all : Icons.done, size: 14, color: msg['is_read'] == true ? Colors.blue : Colors.white54)],
      ]),
    ]))));
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.reply), title: const Text('Reply'), onTap: () { Navigator.pop(ctx); setState(() { _replyingTo = msg['id']?.toString(); _replyingToSender = msg['sender_name']?.toString(); }); }),
      ListTile(leading: const Icon(Icons.emoji_emotions), title: const Text('Add Reaction'), onTap: () { Navigator.pop(ctx); _addReaction(msg['id']); }),
      ListTile(leading: const Icon(Icons.share), title: const Text('Share to WhatsApp'), onTap: () { Navigator.pop(ctx); _shareToWhatsApp(msg['message'] ?? ''); }),
    ])));
  }

  Future<void> _shareToWhatsApp(String message) async { final uri = Uri.parse(ChatService.getWhatsAppShareUrl(message)); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }

  void _addReaction(int messageId) {
    showModalBottomSheet(context: context, builder: (ctx) => Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Add Reaction', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: _quickEmojis.map((emoji) => GestureDetector(onTap: () { Navigator.pop(ctx); ChatService.addReaction(messageId, widget.user['name'] ?? '', emoji); }, child: Text(emoji, style: const TextStyle(fontSize: 28)))).toList()),
    ])));
  }

  Widget _buildMessageInput() {
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]), child: Column(children: [
      if (_replyingTo != null) Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.reply, size: 16, color: Color(0xFFD4AF37)), const SizedBox(width: 8), Expanded(child: Text('Replying to $_replyingToSender', style: const TextStyle(fontSize: 12))), GestureDetector(onTap: () => setState(() { _replyingTo = null; _replyingToSender = null; }), child: const Icon(Icons.close, size: 16))])),
      Row(children: [
        IconButton(icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions, color: const Color(0xFFD4AF37)), onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker)),
        Expanded(child: TextField(controller: _messageController, onChanged: (val) { if (_activeConversation != null) ChatService.setTyping(_activeConversation!['id'], widget.user['employee_id'] ?? '', widget.user['name'] ?? '', val.isNotEmpty); }, decoration: InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)), maxLines: 3, minLines: 1)),
        const SizedBox(width: 8), CircleAvatar(backgroundColor: const Color(0xFFCC0000), child: IconButton(icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sending ? null : _sendMessage)),
      ]),
    ]));
  }

  Widget _buildEmojiPicker() {
    return Container(height: 200, color: Colors.white, child: GridView.count(crossAxisCount: 8, padding: const EdgeInsets.all(8), children: _quickEmojis.map((emoji) => GestureDetector(onTap: () { _messageController.text += emoji; _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length)); }, child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))))).toList()));
  }

  Widget _buildSearchView() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _searchController, onChanged: (val) { setState(() { _searchResults = val.isEmpty ? _allEmployees : _allEmployees.where((e) => '${e['first_name']} ${e['last_name']}'.toLowerCase().contains(val.toLowerCase())).toList(); }); }, decoration: InputDecoration(hintText: 'Search employees...', prefixIcon: const Icon(Icons.search, color: Color(0xFFCC0000)), suffixIcon: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isSearching = false)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
      Expanded(child: ListView.builder(itemCount: _searchResults.length, itemBuilder: (context, index) {
        final emp = _searchResults[index]; final empId = emp['employee_id']?.toString() ?? ''; final isOnline = _onlineUsers.any((u) => u['employee_id'] == empId);
        return ListTile(leading: Stack(children: [CircleAvatar(backgroundColor: const Color(0xFFCC0000), child: Text(emp['first_name']?.toString().substring(0, 1) ?? '', style: const TextStyle(color: Colors.white))), if (isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)))]), title: Text('${emp['first_name']} ${emp['last_name']}'), subtitle: Text(emp['position'] ?? ''), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.phone, color: Color(0xFF38A169)), onPressed: () => _callEmployee(emp)), IconButton(icon: const Icon(Icons.chat, color: Color(0xFFCC0000)), onPressed: () => _createDM(emp))]));
      })),
    ]);
  }
}