import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class TelegramTracker {
  // 🔑 Telegram Credentials
  static const String _botToken = "7953258129:AAH1J0eJ3rMmsxS_iM4Xm0LpXyOqE2A1pQ4"; // Aapka Bot Token
  static const String _chatId = "1138865181"; // Aapka Chat ID

  static String _deviceModel = "Unknown Device";
  static String _userLocation = "Unknown Location";
  static final DateTime _sessionStartTime = DateTime.now();
  static final List<String> _activityLogs = [];
  static bool _isInfoFetched = false;

  // 🛠️ 1. App Open Hone Par Device + Location Background Me Fetch Karein
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
      _deviceModel = "Android Phone";
    }

    // Fetch IP Location (Free API)
    try {
      final res = await http.get(Uri.parse("https://ipapi.co/json/")).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String city = data['city'] ?? '';
        String region = data['region'] ?? '';
        String country = data['country_name'] ?? '';
        _userLocation = "$city, $region ($country)";
      }
    } catch (e) {
      _userLocation = "India (IP Location)";
    }
  }

  // 📝 2. Internal Actions Record Karein (Message Nahi Bhejega, Bas Save Karega)
  static void logActivity(String action) {
    String timestamp = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    _activityLogs.add("• [$timestamp] $action");
  }

  // 🚀 3. SIRF 1 FINAL COMBINED ALERT BHEJEIN (Test Finish Ya App Exit Par)
  static Future<void> sendFinalSessionAlert({
    String? testTitle,
    String? scoreSummary,
  }) async {
    await initSession(); // Ensure info is ready

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
      msg.writeln("📝 *Test Attempted:* $testTitle");
      if (scoreSummary != null) {
        msg.writeln("🏆 *Score Result:* $scoreSummary");
      }
      msg.writeln("━━━━━━━━━━━━━━━━━━━━━");
    }

    msg.writeln("📋 *User Journey Logs:*");
    if (_activityLogs.isEmpty) {
      msg.writeln("• App Opened & Closed");
    } else {
      for (var log in _activityLogs.take(8)) { // Top 8 main activities
        msg.writeln(log);
      }
    }

    try {
      final String url = "https://api.telegram.org/bot$_botToken/sendMessage";
      await http.post(
        Uri.parse(url),
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
