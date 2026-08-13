import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static final _supabase = Supabase.instance.client;
  static const int _currentVersionCode = 1;

  static Future<void> checkForUpdate() async {
    try {
      final data = await _supabase
          .from('app_versions')
          .select('*')
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        final latestVersion = data['version_code'] as int? ?? 1;
        if (latestVersion > _currentVersionCode) {
          final url = data['download_url']?.toString();
          final message = data['update_message']?.toString() ?? 'New version available';
          final isForce = data['is_force_update'] == true;

          if (url != null && url.isNotEmpty) {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      // Ignore
    }
  }
}