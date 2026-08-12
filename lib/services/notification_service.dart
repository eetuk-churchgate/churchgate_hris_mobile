import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
      );
    } catch (e) {
      // Notifications not available
    }
  }

  static Future<void> updateTokenForUser(String employeeId) async {
    // Will implement when Firebase is fixed
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hris_channel',
            'HRIS Notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      // Notification failed
    }
  }
}