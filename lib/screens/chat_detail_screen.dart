import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../services/engagement_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? chatPartner;
  final bool isGroup;
  final String? department;

  const ChatDetailScreen({super.key, required this.user, this.chatPartner, this.isGroup = false, this.department});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _showEmojiPicker = false;

  final List<String> _emojis = ['😀','😂','❤️','👍','🎉','🔥','😢','😡','🤔','👏','💯','🙏','😍','🤩','🥳','😎','🤗','💪','✨','🌟'];

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'Chat Detail');
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> messages;
      if (widget.isGroup) {
        messages = await ChatService.getGroupMessages(widget.department ?? '');
      } else {
        messages = await ChatService.getMessages(widget.user['email'] ?? '', widget.chatPartner?['email'] ?? '');
      }
      setState(() { _messages = messages; _loading = false; });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _subscribeToMessages() {
    _supabase.from('chat_messages').stream(primaryKey: ['id']).listen((data) {
      _loadMessages();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    _messageController.clear();

    try {
      if (widget.isGroup) {
        await ChatService.sendGroupMessage(senderEmail: widget.user['email'] ?? '', senderName: widget.user['name'] ?? '', department: widget.department ?? '', message: message);
      } else {
        await ChatService.sendMessage(senderEmail: widget.user['email'] ?? '', senderName: widget.user['name'] ?? '', receiverEmail: widget.chatPartner?['email'] ?? '', receiverName: widget.chatPartner?['name'] ?? '', message: message);
      }
      _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isGroup ? '${widget.department} Group' : widget.chatPartner?['name'] ?? 'Chat';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: const Color(0xFFCC0000), child: Text(title[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            const Text('Online', style: TextStyle(fontSize: 10, color: Colors.green)),
          ]),
        ]),
        actions: [IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}), IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {})],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_email'] == widget.user['email'];
                      final showAvatar = index == 0 || _messages[index - 1]['sender_email'] != msg['sender_email'];
                      return _buildMessageBubble(msg, isMe, showAvatar);
                    },
                  ),
          ),
          if (_showEmojiPicker) _buildEmojiPicker(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, bool showAvatar) {
    return Padding(
      padding: EdgeInsets.only(top: showAvatar ? 12 : 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) ...[
            CircleAvatar(radius: 14, backgroundColor: const Color(0xFFCC0000), child: Text((msg['sender_name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10))),
            const SizedBox(width: 8),
          ],
          if (!isMe && !showAvatar) const SizedBox(width: 36),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFCC0000) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Text(msg['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
            ),
          ),
          if (isMe && showAvatar) ...[
            const SizedBox(width: 8),
            CircleAvatar(radius: 14, backgroundColor: const Color(0xFFCC0000), child: Text((widget.user['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10))),
          ],
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 200,
      color: Colors.white,
      child: GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.all(8),
        children: _emojis.map((emoji) => GestureDetector(
          onTap: () {
            _messageController.text += emoji;
            setState(() => _showEmojiPicker = false);
          },
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        )).toList(),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.emoji_emotions_outlined, color: _showEmojiPicker ? const Color(0xFFCC0000) : Colors.grey), onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker)),
            IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: () {}),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1, maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true, fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(backgroundColor: const Color(0xFFCC0000), child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: _sendMessage)),
          ],
        ),
      ),
    );
  }
}