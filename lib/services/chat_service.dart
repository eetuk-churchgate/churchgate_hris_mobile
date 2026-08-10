import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ChatService {
  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getConversations(String employeeId) async {
    final data = await _supabase
        .from('chat_participants')
        .select('conversation_id, chat_conversations(*)')
        .eq('employee_id', employeeId)
        .order('joined_at', ascending: false);

    List<Map<String, dynamic>> conversations = [];
    for (var row in data) {
      if (row['chat_conversations'] != null) {
        conversations.add(Map<String, dynamic>.from(row['chat_conversations']));
      }
    }
    return conversations;
  }

  static Future<List<Map<String, dynamic>>> getMessages(int conversationId, {int limit = 50}) async {
    final data = await _supabase
        .from('chat_messages_new')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data).reversed.toList();
  }

  static Future<Map<String, dynamic>?> sendMessage({
    required int conversationId,
    required String senderId,
    required String senderName,
    required String message,
    String messageType = 'text',
    String? attachmentUrl,
    List<String>? mentionedUsers,
    int? replyToId,
  }) async {
    final result = await _supabase
        .from('chat_messages_new')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'sender_name': senderName,
          'message': message,
          'message_type': messageType,
          'attachment_url': attachmentUrl,
          'mentioned_users': mentionedUsers != null ? jsonEncode(mentionedUsers) : null,
          'reply_to_id': replyToId,
          'is_read': false,
          'sent_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    await _supabase
        .from('chat_conversations')
        .update({
          'last_message': message,
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .eq('id', conversationId);

    return Map<String, dynamic>.from(result);
  }

  static Future<int?> createDMConversation(String empId1, String name1, String empId2, String name2) async {
    final existing = await _supabase
        .from('chat_participants')
        .select('conversation_id')
        .eq('employee_id', empId1);

    final existingIds = existing.map((e) => e['conversation_id']).toList();

    if (existingIds.isNotEmpty) {
      final participants = await _supabase
          .from('chat_participants')
          .select('conversation_id')
          .inFilter('conversation_id', existingIds)
          .eq('employee_id', empId2);

      if (participants.isNotEmpty) {
        final conv = await _supabase
            .from('chat_conversations')
            .select('id, type')
            .eq('id', participants.first['conversation_id'])
            .eq('type', 'direct')
            .maybeSingle();

        if (conv != null) return conv['id'];
      }
    }

    final convResult = await _supabase
        .from('chat_conversations')
        .insert({'type': 'direct', 'created_by': empId1})
        .select()
        .single();

    final convId = convResult['id'];

    await _supabase.from('chat_participants').insert([
      {'conversation_id': convId, 'employee_id': empId1, 'employee_name': name1},
      {'conversation_id': convId, 'employee_id': empId2, 'employee_name': name2},
    ]);

    return convId;
  }

  static Future<int?> createGroupConversation(String name, String createdBy, String creatorName, List<Map<String, dynamic>> members) async {
    final convResult = await _supabase
        .from('chat_conversations')
        .insert({'name': name, 'type': 'group', 'created_by': createdBy})
        .select()
        .single();

    final convId = convResult['id'];

    List<Map<String, dynamic>> participants = [
      {'conversation_id': convId, 'employee_id': createdBy, 'employee_name': creatorName},
    ];

    for (var member in members) {
      participants.add({
        'conversation_id': convId,
        'employee_id': member['id'],
        'employee_name': member['name'],
      });
    }

    await _supabase.from('chat_participants').insert(participants);

    return convId;
  }

  static Future<List<Map<String, dynamic>>> getParticipants(int conversationId) async {
    final data = await _supabase
        .from('chat_participants')
        .select('*')
        .eq('conversation_id', conversationId);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> markAsRead(int conversationId, String employeeId) async {
    await _supabase
        .from('chat_messages_new')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', employeeId)
        .eq('is_read', false);

    await _supabase
        .from('chat_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('employee_id', employeeId);
  }

  static Future<int> getUnreadCount(String employeeId) async {
    final conversations = await getConversations(employeeId);
    int count = 0;

    for (var conv in conversations) {
      final unread = await _supabase
          .from('chat_messages_new')
          .select('id')
          .eq('conversation_id', conv['id'])
          .neq('sender_id', employeeId)
          .eq('is_read', false);

      count += unread.length;
    }

    return count;
  }

  static Future<void> setPresence(String employeeId, String employeeName, bool isOnline, {String? device}) async {
    await _supabase.from('chat_presence').upsert({
      'employee_id': employeeId,
      'employee_name': employeeName,
      'is_online': isOnline,
      'last_seen': DateTime.now().toIso8601String(),
      'device': device,
    });
  }

  static Future<List<Map<String, dynamic>>> getOnlineUsers() async {
    final data = await _supabase
        .from('chat_presence')
        .select('*')
        .eq('is_online', true);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> setTyping(int conversationId, String employeeId, String employeeName, bool isTyping) async {
    try {
      await _supabase.from('chat_typing').upsert({
        'conversation_id': conversationId,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'conversation_id, employee_id');
    } catch (e) {
      // Ignore typing errors
    }
  }

  static RealtimeChannel subscribeToMessages(int conversationId, Function(Map<String, dynamic>) onMessage) {
    return _supabase
        .channel('chat_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages_new',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onMessage(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();
  }

  static RealtimeChannel subscribeToTyping(int conversationId, Function(Map<String, dynamic>) onTyping) {
    return _supabase
        .channel('typing_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_typing',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onTyping(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();
  }

  static void unsubscribe(RealtimeChannel channel) {
    channel.unsubscribe();
  }

  static Future<void> addReaction(int messageId, String employeeName, String emoji) async {
    final message = await _supabase
        .from('chat_messages_new')
        .select('reactions')
        .eq('id', messageId)
        .single();

    List reactions = [];
    if (message['reactions'] != null) {
      reactions = message['reactions'] is String 
          ? jsonDecode(message['reactions']) 
          : List.from(message['reactions']);
    }

    reactions.removeWhere((r) => r['user'] == employeeName);
    reactions.add({'user': employeeName, 'emoji': emoji});

    await _supabase
        .from('chat_messages_new')
        .update({'reactions': jsonEncode(reactions)})
        .eq('id', messageId);
  }

  static String getWhatsAppShareUrl(String message) {
    return 'https://wa.me/?text=${Uri.encodeComponent(message)}';
  }
}