import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;

  // Get all chat conversations for user
  static Future<List<Map<String, dynamic>>> getConversations(String userEmail) async {
    final response = await _supabase
        .from('chat_messages')
        .select('*')
        .or('sender_email.eq.$userEmail,receiver_email.eq.$userEmail')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Get messages between two users
  static Future<List<Map<String, dynamic>>> getMessages(String user1, String user2) async {
    final response = await _supabase
        .from('chat_messages')
        .select('*')
        .or('and(sender_email.eq.$user1,receiver_email.eq.$user2),and(sender_email.eq.$user2,receiver_email.eq.$user1)')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Send a message
  static Future<void> sendMessage({
    required String senderEmail,
    required String senderName,
    required String receiverEmail,
    required String receiverName,
    required String message,
    String? fileUrl,
    String? fileType,
  }) async {
    await _supabase.from('chat_messages').insert({
      'sender_email': senderEmail,
      'sender_name': senderName,
      'receiver_email': receiverEmail,
      'receiver_name': receiverName,
      'message': message,
      'file_url': fileUrl,
      'file_type': fileType,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get department group messages
  static Future<List<Map<String, dynamic>>> getGroupMessages(String department) async {
    final response = await _supabase
        .from('chat_messages')
        .select('*')
        .eq('group_department', department)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Send group message
  static Future<void> sendGroupMessage({
    required String senderEmail,
    required String senderName,
    required String department,
    required String message,
  }) async {
    await _supabase.from('chat_messages').insert({
      'sender_email': senderEmail,
      'sender_name': senderName,
      'group_department': department,
      'message': message,
      'is_group': true,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Mark messages as read
  static Future<void> markAsRead(String senderEmail, String receiverEmail) async {
    await _supabase
        .from('chat_messages')
        .update({'is_read': true})
        .eq('sender_email', senderEmail)
        .eq('receiver_email', receiverEmail);
  }

  // Get unread count
  static Future<int> getUnreadCount(String userEmail) async {
    final response = await _supabase
        .from('chat_messages')
        .select('*')
        .eq('receiver_email', userEmail)
        .eq('is_read', false);
    return response.length;
  }
}