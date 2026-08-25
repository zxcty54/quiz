import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background payload handling
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mocktester_channel',
    'Exam & PDF Alerts',
    description: 'BPSC, BSSC & Test Updates',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    // 1️⃣ Permission for Android 13+
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2️⃣ Local Notification Setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3️⃣ Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4️⃣ Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 5️⃣ Topic Subscription (Broadcast notifications ke liye)
    await _messaging.subscribeToTopic('all_users');
  }
}
