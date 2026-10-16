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
  static const String _recentLinesKey = 'smart_reminder_recent_lines_v1';
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
  //
  // LINE KA NIYAM: koi tukde-jod wala jumla nahi banta. Har line ek
  // poori, pehle se jaanchi hui template hai — sirf sankhya, naam aur
  // chapter bhara jata hai, isliye matlab kabhi bigadta nahi.
  // App pichli 14 lines yaad rakhta hai, wahi line dobara nahi aati.
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
      final int remaining = goal - todayQs;

      final String rawName =
          (stats['student_name'] ?? '').toString().trim();
      final String dost =
          (rawName.isEmpty || rawName == 'Aspirant')
              ? 'Dost'
              : rawName.split(' ').first;

      // Adhoora chhoda hua mock hai kya? + pichli lines ki memory
      final prefs = await SharedPreferences.getInstance();
      int inProgress = 0;
      try {
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

      List<String> recent =
          prefs.getStringList(_recentLinesKey) ?? <String>[];
      final Set<String> recentSet = recent.toSet();
      final List<String> pickedNow = <String>[];

      final DateTime now = DateTime.now();

      // Poori template line chuno — jo pichle dino me aayi ho, use chhodo
      List<String> pick(List<List<String>> options, int salt) {
        for (int offset = 0; offset < options.length; offset++) {
          final List<String> candidate =
              options[(now.day + salt + offset) % options.length];
          if (!recentSet.contains(candidate[1])) {
            recentSet.add(candidate[1]);
            pickedNow.add(candidate[1]);
            return candidate;
          }
        }
        final List<String> fallback =
            options[(now.day + salt) % options.length];
        pickedNow.add(fallback[1]);
        return fallback;
      }

      final DateTime todayEvening =
          DateTime(now.year, now.month, now.day, 19, 30);
      final DateTime tomorrow = now.add(const Duration(days: 1));
      final DateTime tomorrowMorning =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 30);
      final DateTime tomorrowEvening =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30);

      // --- Slot 1: Aaj shaam 7:30 (agar waqt bacha hai) ---
      if (todayEvening.isAfter(now)) {
        List<List<String>>? variants;
        String? payload;
        if (inProgress > 0) {
          variants = [
            [
              '⏸️ Mock beech me hi chhod diya?',
              'Aadha mock wahi atka pada hai jahan chhoda tha 😅 Resume karo — warna sawalon ko lagega tum darr ke bhaag gaye!',
            ],
            [
              '🎬 Picture abhi baki hai dost!',
              'Adhoora mock intezaar kar raha hai — resume dabao aur kahani khatam karo 💪',
            ],
            [
              '😅 Break to kuch zyada hi lamba ho gaya!',
              '$dost, mock abhi bhi wahi ruka hai jahan chhoda tha. Ek baithak me nipta do, phir chill marna!',
            ],
            [
              '🕐 Mock wali ghadi wahi ruki hai...',
              'Test beech me pada hai, samay bhi wahi atka hai. Resume karo aur momentum wapas lao 🔥',
            ],
          ];
          payload = 'smart_resume';
        } else if (todayQs == 0) {
          variants = [
            [
              '🔥 Streak ICU me hai 🚑',
              '$streak din ki streak saanse gin rahi hai... Bas kuch sawal, aur doctor sahab (tum) use bacha sakte ho!',
            ],
            [
              '😴 Aaj sawalon ko chhutti de di?',
              'Kitabein almari se jhaank rahi hain 👀 $streak din ki streak bhi wait kar rahi hai — 5 sawal hi kar lo!',
            ],
            [
              '😔 Streak ne message bheja hai',
              '"$streak din se roz saath padh rahe the, aaj aaye hi nahi?" Use mayus mat karo — 5 sawal kar lo 😅',
            ],
            [
              '🌙 Din khatam, sawal zero?',
              'Sone se pehle bas 5 sawal — $streak din ki streak bhi bach jayegi, neend bhi achhi aayegi 😄',
            ],
          ];
          payload = 'smart_streak';
        } else if (todayQs < goal) {
          variants = [
            [
              '🎯 Bas $remaining sawal aur!',
              'Itne paas aakar kaun rukta hai bhai 😄 Goal pura karo — streak bhi khush, tum bhi khush!',
            ],
            [
              '🏃 Goal se bas $remaining kadam door!',
              'Scroll karne me 10 minute nikal hi jayenge... unhi 10 minute me goal pura kar lo 😏',
            ],
            [
              '📱 Scroll break khatam, $dost!',
              'Bas $remaining sawal bache hain — 10 minute ka kaam hai. Phone side me rakho, goal khatam karo!',
            ],
            [
              '🏁 Finish line dikh rahi hai!',
              '$remaining sawal aur, phir aaj ka din tumhara. Itne paas aakar toppers haar nahi mante 🔥',
            ],
          ];
          payload = 'smart_goal';
        } else if (due > 0) {
          variants = [
            [
              '😤 Badla lene ka time hai!',
              'Jo $due sawal tumhe ek din Dhaka de chuke hain, aaj unka hisaab chukta karo — due revision kholo!',
            ],
            [
              '👏 Goal pura! Ab extra kamaai',
              '$due due sawal bhi nipta diye to kal ka din aur halka lagega. Ek chhota sa revision round ho jaye?',
            ],
            [
              '🔁 Purane dushman wait kar rahe hain',
              '$due galat sawal abhi bhi wahi khade hain. Aaj inhe sahi karke inki himaakat hi khatam karo 😤',
            ],
            [
              '🎯 Aaj double fayda hoga',
              'Goal to pura hai hi — $due due sawal nipta diye to kal sabse aage nikal jaoge 💪',
            ],
          ];
          payload = 'smart_due';
        }
        if (variants != null) {
          final List<String> line = pick(variants, 0);
          await _scheduleSmart(_smartIds[0], line[0], line[1], todayEvening,
              payload ?? 'smart');
        }
      }

      // --- Slot 2: Kal subah 8:30 (roz ka mission) ---
      {
        List<List<String>> variants;
        String payload;
        if (due > 0 && repeat > 0) {
          variants = [
            [
              '😤 Wahi sawal phir satane aaye hain',
              '$repeat sawal baar-baar galat ho rahe hain — aaj inka ilaaj pakka karo, phir ye dobara pareshan nahi karenge 💪',
            ],
            [
              '😤 In sawalon ki dadagiri khatam karo',
              '$repeat sawal baar-baar Dhaka de rahe hain — matlab concept me gadbad hai. Aaj aaram se samajhkar hamesha ke liye nipta do!',
            ],
            [
              '☀️ Aaj badle ka din hai, $dost!',
              '$repeat sawal tumhe baar-baar pareshan kar rahe hain. Subah-subah inka hisaab barabar kar do 😤',
            ],
          ];
          payload = 'smart_due';
        } else if (due > 0) {
          variants = [
            [
              '☀️ Uth gaye, Topper Sahab?',
              'Chai baad me, pehle $due due sawal ☕ subah wala revision seedha dimaag me chhap jata hai!',
            ],
            [
              '📚 Kitabein Good Morning bol rahi hain',
              '$due due sawal subah nipta diye to din bhar selection wala feel aayega 😄 Chalo shuru karte hain!',
            ],
            [
              '☀️ Subah ka pehla kaam, $dost',
              '$due due sawal chai se pehle nipta do — din ki sabse achhi shuruaat revision se hoti hai 📚',
            ],
            [
              '🧠 Subah wala dimaag sabse taaza hota hai',
              '$due due sawal abhi kar lo — subah ki revision lambe samay tak yaad rehti hai!',
            ],
          ];
          payload = 'smart_due';
        } else if (inProgress > 0) {
          variants = [
            [
              '☀️ Subah ho gayi, mock bula raha hai',
              'Aadha mock wahi pada wait kar raha hai 😅 Ek baithak me nipta do, phir din tumhara!',
            ],
            [
              '🌤️ Chai aur adhoora mock — dono ready!',
              'Mock resume karo aur subah ki shuruaat ek poori jeet se karo 💪',
            ],
            [
              '⏸️ Kal wala mock abhi baki hai',
              'Use adhoora chhodna matlab aadhi taiyaari. Aaj resume karke apna score dekh hi lo!',
            ],
          ];
          payload = 'smart_resume';
        } else {
          variants = [
            [
              '☀️ Naya din, $goal sawal, ek mission',
              'Sapna bada hai, target chhota hai 🚀 Kal $lastChapter padh rahe the, aaj wahi se aage badho!',
            ],
            [
              '👀 Aankhein khul gayi, $dost?',
              'To $goal sawal bhi khol lo 😄 Chai ke saath pehla sawal — din ban jayega!',
            ],
            [
              '📖 Kal jahan ruke the, wahi se...',
              '$lastChapter se hi agli kahani shuru hogi. Aaj ka $goal sawalon ka mission wahi se start karo 🚀',
            ],
            [
              '🚀 Selection wale din aise hi bante hain',
              'Roz ke $goal sawal — bas yahi formula hai. Aaj ka mission: $lastChapter aur thodi si speed 📚',
            ],
          ];
          payload = 'smart_mission';
        }
        final List<String> line = pick(variants, 1);
        await _scheduleSmart(
            _smartIds[1], line[0], line[1], tomorrowMorning, payload);
      }

      // --- Slot 3: Kal shaam 7:30 (streak bachao / pehla mock) ---
      {
        List<List<String>> variants;
        String payload;
        if (mocks == 0) {
          variants = [
            [
              '🎯 Kitabi sher, asli mahaul kab?',
              'Sawal to bahut kar liye — ek baar asli exam wala mahaul bhi try karo. Pehla mock galtiyon ke liye hi hota hai 😄',
            ],
            [
              '😅 Mock se darr lagta hai?',
              'Sabko lagta hai pehli baar! Ek dekar dekho — darr bhi bhagega, apna level bhi pata chalega.',
            ],
            [
              '📝 Bina mock ke race adhuri hai',
              'Practice bahut ho gayi — ab ek baar ghadi ke saath mahaul check kar lo. Galti hogi to wahi sikha degi 😄',
            ],
          ];
          payload = 'smart_first_mock';
        } else {
          variants = [
            [
              '🥺 Streak bol raha hai... bacha lo!',
              '"$streak din se saath hoon, aaj akela chhod doge?" Din khatam hone se pehle goal check kar lo 🔥',
            ],
            [
              '🔥 $streak din ki aag bujhne mat do',
              'Ek din ki chook aur streak phir zero se shuru 😬 Bas 5-10 sawal is aag ko zinda rakhenge!',
            ],
            [
              '😴 Sone se pehle bas ek kaam',
              '$streak din ki streak ko bistar par jane se pehle bacha lo — 5 sawal, phir chain ki neend 🔥',
            ],
            [
              '📵 Reel baad me, streak pehle!',
              'Din khatam hone wala hai — $streak din ki mehnat ek din ki chook se mat ganwao, goal check kar lo!',
            ],
          ];
          payload = 'smart_streak';
        }
        final List<String> line = pick(variants, 2);
        await _scheduleSmart(
            _smartIds[2], line[0], line[1], tomorrowEvening, payload);
      }

      // Pichli lines yaad rakho — agle ~5 din wahi line dobara nahi aayegi
      recent = <String>[...recent, ...pickedNow];
      if (recent.length > 14) {
        recent = recent.sublist(recent.length - 14);
      }
      await prefs.setStringList(_recentLinesKey, recent);
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
