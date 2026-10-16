import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'user_stats_service.dart';

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

  // Smart personal reminder ids (fixed, taaki purana schedule hamesha replace ho)
  static const List<int> _smartIds = [9201, 9202, 9203];
  static DateTime? _lastSmartSchedule;
  static bool _resumeObserverAdded = false;

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

    // 6️⃣ Smart Personal Reminders (activity ke hisaab se)
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {}

    if (!_resumeObserverAdded) {
      _resumeObserverAdded = true;
      WidgetsBinding.instance.addObserver(_SmartReminderObserver());
    }

    await scheduleSmartReminders(force: true);
  }

  // ============================================================
  // SMART PERSONAL REMINDERS
  // Student ki apni activity dekh kar bante hain:
  // adhoora mock, aaj ka goal, streak, due revision, last chapter.
  // Din me zyada se zyada 3 — shaam (aaj), subah (kal), shaam (kal).
  // App khulne/par wapas aane par fresh activity se dobara bante hain.
  // ============================================================
  static Future<void> scheduleSmartReminders({bool force = false}) async {
    try {
      final DateTime nowCheck = DateTime.now();
      if (!force &&
          _lastSmartSchedule != null &&
          nowCheck.difference(_lastSmartSchedule!).inMinutes < 20) {
        return; // 20 min ke andar dobara mat banao
      }
      _lastSmartSchedule = nowCheck;

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Purane smart reminders hatao, fresh banege
      for (final int id in _smartIds) {
        await _localNotifications.cancel(id);
      }

      final Map<String, dynamic> stats = await UserStatsService.getStats();
      final Map<String, int> dueStats =
          await UserStatsService.getDueWrongStats();

      final int streak = (stats['streak'] as num?)?.toInt() ?? 1;
      final int mocks = (stats['mocks'] as num?)?.toInt() ?? 0;
      final List<int> weekly =
          List<int>.from(stats['weekly_progress'] ?? <int>[]);
      final int todayQs = weekly.isNotEmpty ? weekly.last : 0;
      final int due = dueStats['due'] ?? 0;
      final int repeat = dueStats['repeat'] ?? 0;
      final String lastChapter =
          (stats['last_chapter_name'] ?? 'General Studies').toString();
      const int goal = 30;

      // Adhoora chhoda hua mock hai kya?
      int inProgress = 0;
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final String key in prefs.getKeys()) {
          if (!key.startsWith('cbt_progress_')) continue;
          final String? raw = prefs.getString(key);
          if (raw == null) continue;
          try {
            final dynamic decoded = jsonDecode(raw);
            if (decoded is Map && decoded['status'] == 'IN_PROGRESS') {
              inProgress++;
            }
          } catch (_) {}
        }
      } catch (_) {}

      final DateTime now = DateTime.now();
      final DateTime todayEvening =
          DateTime(now.year, now.month, now.day, 19, 30);
      final DateTime tomorrow = now.add(const Duration(days: 1));
      final DateTime tomorrowMorning =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 30);
      final DateTime tomorrowEvening =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30);

      // --- Slot 1: Aaj shaam 7:30 (agar waqt bacha hai) ---
      if (todayEvening.isAfter(now)) {
        String? title;
        String? body;
        String? payload;
        if (inProgress > 0) {
          title = '⏸️ Adhoora Mock Bacha Hai!';
          body =
              'Ek mock aadha chhod rakha hai — resume karke pura karo, mehnat bekar mat jane do 💪';
          payload = 'smart_resume';
        } else if (todayQs == 0) {
          title = '🔥 Streak Khatre Me Hai!';
          body =
              'Aaj abhi tak ek bhi sawal nahi hua. $streak din ki streak bachane ke liye bas kuch sawal kar lo!';
          payload = 'smart_streak';
        } else if (todayQs < goal) {
          title = '🎯 Bas ${goal - todayQs} Sawal Aur!';
          body =
              'Aaj ka goal pura hone me thoda hi bacha hai — goal pura karo aur streak bhi bacha lo 🔥';
          payload = 'smart_goal';
        } else if (due > 0) {
          title = '🔁 $due Sawal Due Hain!';
          body =
              'Goal pura, badhai ho 👏 Ab due revision karke galat hue sawal pakke kar lo.';
          payload = 'smart_due';
        }
        if (title != null && body != null) {
          await _scheduleSmart(
              _smartIds[0], title, body, todayEvening, payload ?? 'smart');
        }
      }

      // --- Slot 2: Kal subah 8:30 (roz ka mission) ---
      {
        String title;
        String body;
        String payload;
        if (due > 0) {
          title = '☀️ Aaj Ke $due Due Sawal Wait Kar Rahe Hain';
          body = repeat > 0
              ? 'Unme $repeat sawal baar-baar galat ho rahe hain — subah ka revision sabse pakka yaad rehta hai 🧠'
              : 'Subah ka revision sabse pakka yaad rehta hai — din ki shuruaat due sawalon se karo 🧠';
          payload = 'smart_due';
        } else if (inProgress > 0) {
          title = '☀️ Adhoora Mock Pura Karo!';
          body =
              'Kal ka aadha mock aaj pura karo — aadhi mehnat ka pura fayda tabhi milega jab test khatam hoga 💪';
          payload = 'smart_resume';
        } else {
          title = '☀️ Aaj Ka Mission: $goal Sawal';
          body =
              'Last time tum $lastChapter padh rahe the — aaj wahi se aage badho, speed barkarar rakho 📚';
          payload = 'smart_mission';
        }
        await _scheduleSmart(
            _smartIds[1], title, body, tomorrowMorning, payload);
      }

      // --- Slot 3: Kal shaam 7:30 (streak bachao / pehla mock) ---
      {
        String title;
        String body;
        String payload;
        if (mocks == 0) {
          title = '🎯 Pehla Mock Abhi Baki Hai!';
          body =
              'Sawal karna achha hai, par asli exam ka mahaul mock se hi aayega — aaj pehla mock dekar dekho!';
          payload = 'smart_first_mock';
        } else {
          title = '🔥 $streak Din Ki Streak Bachani Hai!';
          body =
              'Din khatam hone se pehle aaj ka goal check kar lo — ek din ki chook, streak phir zero se shuru.';
          payload = 'smart_streak';
        }
        await _scheduleSmart(
            _smartIds[2], title, body, tomorrowEvening, payload);
      }
    } catch (_) {
      // Reminder kabhi app ko rokna nahi chahiye
    }
  }

  static Future<void> _scheduleSmart(int id, String title, String body,
      DateTime when, String payload) async {
    final tz.TZDateTime tzWhen = tz.TZDateTime.from(when, tz.local);
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }
}

// App wapas khulne par reminder fresh activity se dobara banta hai
class _SmartReminderObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.scheduleSmartReminders();
    }
  }
}
