import 'package:supabase_flutter/supabase_flutter.dart';

class EngagementService {
  static final _supabase = Supabase.instance.client;
  static String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  static Future<void> trackPageView({
    required String module,
    String action = 'page_view',
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final email = user.email ?? 'unknown@churchgate.com';

      final userData = await _supabase
          .from('users')
          .select('name, email, department')
          .eq('email', email)
          .maybeSingle();

      await _supabase.from('user_engagement').insert({
        'user_name': userData?['name'] ?? email,
        'user_email': email,
        'department': userData?['department'] ?? 'Unknown',
        'module': module,
        'action': action,
        'device': 'mobile',
        'session_id': _sessionId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silent fail
    }
  }

  static void resetSession() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  }
}