import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

class TelegramTracker {
  // 🔑 Apne Telegram Bot Ka Token aur Chat ID Daalein
  static const String botToken = "1809778528:AAFlwdQMKgiezltaJYyAU5u6vNjblBiIPmo";
  static const String chatId = "785009742";

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

  // 2. IP-based Location Fetch Engine
  static Future<void> fetchIPLocation() async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String city = data['city'] ?? 'Unknown City';
        String region = data['regionName'] ?? 'Bihar';
        String country = data['country'] ?? 'India';
        _userLocation = "$city, $region ($country)";
      }
    } catch (e) {
      _userLocation = "Bihar, India";
    }
  }

  // 🚀 3. Telegram Alert Sender
  static Future<void> sendActivityAlert({
    required String screenName,
    String? extraDetails,
  }) async {
    try {
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

      final Uri telegramUri = Uri.parse(
        "https://api.telegram.org/bot$botToken/sendMessage",
      );

      await http.post(
        telegramUri,
        body: {
          "chat_id": chatId,
          "text": message,
          "parse_mode": "Markdown",
        },
      );
    } catch (e) {
      // Silent fail
    }
  }
}
