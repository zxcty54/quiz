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

  // 📝 Save last test data in memory (Don't send alert on submit)
  static String? _lastTestTitle;
  static String? _lastTestScore;

  static bool _isInfoFetched = false;
  static bool _hasSentExitAlert = false; // 🛡️ Single Exit Alert Lock

  // 1️⃣ Silent Background Auto-Init
  static Future<void> initSession() async {
    if (_isInfoFetched) return;
    _isInfoFetched = true;
    _activityLogs.add("📱 App Opened");

    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _deviceModel = "${androidInfo.manufacturer.toUpperCase()} ${androidInfo.model}";
    } catch (e) {
      _deviceModel = "Android Device";
    }

    try {
      final res = await http.get(Uri.parse("https://ipapi.co/json/")).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _userLocation = "${data['city'] ?? ''}, ${data['region'] ?? ''} (${data['country_name'] ?? ''})";
      }
    } catch (e) {
      _userLocation = "Bihar, India";
    }
  }

  // 2️⃣ Record user journey activity
  static void logActivity(String action) {
    String timestamp = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    _activityLogs.add("• [$timestamp] $action");
  }

  // 3️⃣ Record test result quietly (DOES NOT SEND TELEGRAM MSG)
  static void recordTestCompletion(String testTitle, String scoreSummary) {
    _lastTestTitle = testTitle;
    _lastTestScore = scoreSummary;
    logActivity("Submitted Test: $testTitle ($scoreSummary)");
  }

  // 🚀 4️⃣ GUARANTEED FAST TRIGGER ON APP EXIT / MINIMIZE
  static void sendOnAppExitAlert() {
    if (_hasSentExitAlert) return; // Only 1 alert per session
    _hasSentExitAlert = true;

    final Duration duration = DateTime.now().difference(_sessionStartTime);
    final String durationText = "${duration.inMinutes}m ${duration.inSeconds % 60}s";

    final StringBuffer msg = StringBuffer();
    msg.writeln("🔴 *MOCKTESTER USER APP EXIT ALERT*");
    msg.writeln("━━━━━━━━━━━━━━━━━━━━━");
    msg.writeln("📱 *Device:* $_deviceModel");
    msg.writeln("🌍 *Location:* $_userLocation");
    msg.writeln("⏱️ *Total Time Spent:* $durationText");
    msg.writeln("━━━━━━━━━━━━━━━━━━━━━");

    if (_lastTestTitle != null) {
      msg.writeln("📝 *Test Attempted:* $_lastTestTitle");
      msg.writeln("🏆 *Test Score:* $_lastTestScore");
      msg.writeln("━━━━━━━━━━━━━━━━━━━━━");
    } else {
      msg.writeln("📝 *Test Status:* No Test Attempted");
      msg.writeln("━━━━━━━━━━━━━━━━━━━━━");
    }

    msg.writeln("📋 *User Session Activity Logs:*");
    for (var log in _activityLogs.take(8)) {
      msg.writeln(log);
    }

    // ⚡ Fast Unawaited Sync Post Transmission
    try {
      http.post(
        Uri.parse("https://api.telegram.org/bot$_botToken/sendMessage"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "chat_id": _chatId,
          "text": msg.toString(),
          "parse_mode": "Markdown"
        }),
      );
    } catch (_) {
      // Silent Fail
    }
  }
}
