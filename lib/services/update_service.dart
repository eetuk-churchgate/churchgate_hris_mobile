import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class UpdateService {
  static final _supabase = Supabase.instance.client;
  static const int _currentVersionCode = 2;

  static Future<void> checkForUpdate(BuildContext? context) async {
    try {
      final data = await _supabase
          .from('app_versions')
          .select('*')
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        final latestVersion = data['version_code'] as int? ?? 1;
        if (latestVersion > _currentVersionCode && context != null) {
          final url = data['download_url']?.toString();
          final message = data['update_message']?.toString() ?? 'New version available';

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('📱 Update Available'),
              content: Text(message),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (url != null && url.isNotEmpty) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
                  child: const Text('Download Update'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Ignore
    }
  }
}