// v1 source: flutter_app/lib/services/telegram_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mocktester_v2/core/config/app_secrets.dart';

class TelegramTracker {
  // 🔑 Apne Telegram Bot Ka Token aur Chat ID Daalein
  static final String botToken = AppSecrets.telegramAdminBotToken;
  static final String chatId = AppSecrets.telegramAdminChatId;

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
      // Silent fail taaki user ka app slow/lag na ho
    }
  }

  // 🚩 4. Question / explanation error report (used by ReportErrorDialog).
  // v1 declared `TelegramService.reportError` at the call site but never
  // committed the implementation, so the dialog could not compile. It lives
  // here now, on the same bot the rest of the app already uses.
  static Future<bool> reportError({
    required String fileName,
    required int questionIndex,
    required String issueType,
    required String questionSnippet,
  }) async {
    try {
      final String message = """
🚩 *QUESTION ERROR REPORT*
📄 *File:* `$fileName`
🔢 *Question:* Q${questionIndex + 1}
⚠️ *Issue:* $issueType

📝 *Snippet:*
${questionSnippet.length > 400 ? "${questionSnippet.substring(0, 400)}…" : questionSnippet}

📲 *Device:* $_deviceModel
📍 *Location:* $_userLocation
⏰ *Time:* ${DateTime.now().toLocal().toString().split('.').first}
""";

      final http.Response res = await http.post(
        Uri.parse("https://api.telegram.org/bot$botToken/sendMessage"),
        body: {
          "chat_id": chatId,
          "text": message,
          "parse_mode": "Markdown",
        },
      ).timeout(const Duration(seconds: 12));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('reportError failed: $e');
      return false;
    }
  }
}

/// Compatibility name for v1's report dialog.
///
/// v1's `report_error_dialog.dart` calls `TelegramService.reportError(...)`
/// while `telegram_service.dart` only ever declared [TelegramTracker] - the v1
/// call site could not compile. The class is kept here (instead of rewriting
/// the dialog) so the ported widget stays byte-for-byte v1 behaviour.
class TelegramService {
  TelegramService._();

  static Future<bool> reportError({
    required String fileName,
    required int questionIndex,
    required String issueType,
    required String questionSnippet,
  }) =>
      TelegramTracker.reportError(
        fileName: fileName,
        questionIndex: questionIndex,
        issueType: issueType,
        questionSnippet: questionSnippet,
      );
}
