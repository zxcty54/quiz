import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import 'telegram_worker.dart';

class TelegramTracker {
  // Token/chat id yahan nahi hain — sandesh Cloudflare Worker se jata hai.

  static String _deviceModel = "Unknown Device";
  static String _userLocation = "Unknown Location";

  // 1. Device Info Read Engine
  static Future<void> initDeviceInfo() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _deviceModel = "${androidInfo.manufacturer.toUpperCase()} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _deviceModel = iosInfo.name;
      }
    } catch (e) {
      _deviceModel = "Android Device";
    }
  }

  // 2. IP-based Location Fetch Engine (No GPS Permission Needed)
  static Future<void> fetchIPLocation() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String city = data['city'] ?? 'Unknown City';
        String region = data['region'] ?? 'Bihar';
        String country = data['country_name'] ?? 'India';
        _userLocation = "$city, $region ($country)";
      }
    } catch (e) {
      _userLocation = "Bihar, India";
    }
  }

  // 🚀 3. Telegram Par Realtime Activity + Location Alert Bhejne Ka Method
  static Future<void> sendActivityAlert({
    required String screenName,
    String? extraDetails,
  }) async {
    try {
      // Lazy Load Device & Location Info
      if (_deviceModel == "Unknown Device") {
        await initDeviceInfo();
      }
      if (_userLocation == "Unknown Location") {
        await fetchIPLocation();
      }

      final String timeStr = DateTime.now().toString().substring(11, 16);

      final String message = """
📱 *MockTester App User Activity*
📲 *Device:* $_deviceModel
📍 *Location:* $_userLocation
🎯 *Screen:* $screenName
${extraDetails != null ? "📝 *Details:* $extraDetails\n" : ""}⏰ *Time:* $timeStr
""";

      await TelegramWorker.send(text: message, parseMode: 'Markdown');
    } catch (e) {
      // Silent fail taaki user ka app slow/lag na ho
    }
  }
}
