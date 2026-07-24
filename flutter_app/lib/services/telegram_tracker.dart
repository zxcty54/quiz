import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class TelegramTracker {
  static const String _botToken = "7953258129:AAH1J0eJ3rMmsxS_iM4Xm0LpXyOqE2A1pQ4";
  static const String _chatId = "1138865181";

  static String _deviceModel = "Android Phone";
  static String _userLocation = "India (IP Location)";
  static final DateTime _sessionStartTime = DateTime.now();
  static final List<String> _activityLogs = [];
  
  static bool _isInfoFetched = false;
  static bool _hasSentAlert = false; // 🛡️ Prevent duplicate messages

  // 1️⃣ Silent Background Auto-Init
  static Future<void> initSession() async {
    if (_isInfoFetched) return;
    _isInfoFetched = true;
    _activityLogs.add("📱 App Opened");

    // Fetch Device Info
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _deviceModel = "${androidInfo.manufacturer.toUpperCase()} ${androidInfo.model}";
    } catch (e) {
      _deviceModel = "Android Device";
    }

    // Fetch Location
    try {
      final res = await http.get(Uri.parse("https://ipapi.co/json/")).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _userLocation = "${data['city'] ?? ''}, ${data['region'] ?? ''} (${data['country_name'] ?? ''})";
      }
    } catch (e) {
      _userLocation = "Bihar, India";
    }
  }

  // 2️⃣ Log Action
  static void logActivity(String action) {
    String timestamp = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    _activityLogs.add("• [$timestamp] $action");
  }

  // 3️⃣ Final Alert Sender (Submit Par YA Exit Par)
  static Future<void> sendFinalSessionAlert({
    String? testTitle,
    String? scoreSummary,
  }) async {
    if (_hasSentAlert) return; // Agar 1 baar bhej diya hai to dubara nahi bheje
    _hasSentAlert = true;

    await initSession();

    final Duration duration = DateTime.now().difference(_sessionStartTime);
    final String durationText = "${duration.inMinutes}m ${duration.inSeconds % 60}s";

    final StringBuffer msg = StringBuffer();
    msg.writeln("📊 *MOCKTESTER USER SESSION REPORT*");
    msg.writeln("━━━━━━━━━━━━━━━━━━━━━");
    msg.writeln("📱 *Device:* $_deviceModel");
    msg.writeln("🌍 *Location:* $_userLocation");
    msg.writeln("⏱️ *Time Spent:* $durationText");
    msg.writeln("━━━━━━━━━━━━━━━━━━━━━");

    if (testTitle != null && testTitle.isNotEmpty) {
      msg.writeln("📝 *Test:* $testTitle");
      if (scoreSummary != null) msg.writeln("🏆 *Score:* $scoreSummary");
      msg.writeln("━━━━━━━━━━━━━━━━━━━━━");
    } else {
      msg.writeln("📝 *Test:* No Test Attempted (App Exited)");
      msg.writeln("━━━━━━━━━━━━━━━━━━━━━");
    }

    msg.writeln("📋 *User Journey Logs:*");
    for (var log in _activityLogs.take(8)) {
      msg.writeln(log);
    }

    try {
      await http.post(
        Uri.parse("https://api.telegram.org/bot$_botToken/sendMessage"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "chat_id": _chatId,
          "text": msg.toString(),
          "parse_mode": "Markdown"
        }),
      );
    } catch (e) {
      // Silent Fail
    }
  }
}
