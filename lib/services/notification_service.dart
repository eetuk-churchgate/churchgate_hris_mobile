import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Setup local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      showLocalNotification(
        title: message.notification?.title ?? 'New Message',
        body: message.notification?.body ?? '',
      );
    });

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // Navigate to chat when tapped
    });
  }

  static Future<void> updateTokenForUser(String employeeId) async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _supabase.from('fcm_tokens').upsert({
          'employee_id': employeeId,
          'token': token,
          'platform': 'mobile',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // Ignore token errors
    }
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hris_channel',
          'HRIS Notifications',
          channelDescription: 'Churchgate HRIS Chat Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}