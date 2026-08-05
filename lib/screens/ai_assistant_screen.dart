import 'package:flutter/material.dart';
import '../services/groq_ai_service.dart';
import '../services/engagement_service.dart';

class AIAssistantScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AIAssistantScreen({super.key, required this.user});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    EngagementService.trackPageView(module: 'AI Assistant');
    _messages.add({
      'role': 'assistant',
      'content': 'Hi ${widget.user['name']?.toString().split(' ')[0] ?? 'there'}! 👋 I\'m your Churchgate HRIS AI Assistant. I can help with leave, KPIs, training, birthdays, benefits, and more. What would you like to know?',
    });
  }

  Future<void> _sendMessage() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _isThinking) return;

    setState(() {
      _messages.add({'role': 'user', 'content': query});
      _controller.clear();
      _isThinking = true;
    });
    _scrollToBottom();

    final response = await GroqAIService.getResponse(query, widget.user);

    setState(() {
      _messages.add({'role': 'assistant', 'content': response});
      _isThinking = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🤖 AI Assistant'),
            SizedBox(width: 8),
            Text('Groq', style: TextStyle(fontSize: 10, color: Colors.green)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: () {
              GroqAIService.clearConversation();
              setState(() {
                _messages.clear();
                _messages.add({
                  'role': 'assistant',
                  'content': 'Chat cleared! How can I help you?',
                });
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Suggestions
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: GroqAIService.getSuggestions(widget.user).map((suggestion) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        _controller.text = suggestion;
                        _sendMessage();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFCC0000), Color(0xFFe53e3e)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(suggestion, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isThinking && index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🤔', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Text('Thinking...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  );
                }
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFFCC0000) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isThinking,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _isThinking ? 'AI is thinking...' : 'Ask me anything...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFCC0000),
                    child: IconButton(
                      icon: Icon(_isThinking ? Icons.hourglass_empty : Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _isThinking ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}