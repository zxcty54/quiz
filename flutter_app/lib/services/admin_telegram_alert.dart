import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminTelegramAlert {
  static const String _botToken = "1809778528:AAFlwdQMKgiezltaJYyAU5u6vNjblBiIPmo";
  static const String _adminChatId = "785009742";

  static Future<void> sendAbuseAlert({
    required int postId,
    required String postContent,
    required String authorHandle,
    required int totalReports,
    required String lastReason,
  }) async {
    try {
      final String messageText = """
🚨 <b>URGENT: Post Reported 4+ Times!</b>

🆔 <b>Post ID:</b> <code>$postId</code>
👤 <b>Author:</b> @$authorHandle
⚠️ <b>Total Reports:</b> $totalReports
📝 <b>Reason:</b> $lastReason

📄 <b>Content:</b>
<i>"${postContent.length > 250 ? '${postContent.substring(0, 250)}...' : postContent}"</i>

👇 Action lene ke liye niche click karein:
""";

      final String deleteUrl = "https://mocktester.online/api/delete-post?post_id=$postId&key=SECRET_ADMIN_KEY";
      final url = Uri.parse("https://api.telegram.org/bot$_botToken/sendMessage");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _adminChatId,
          'text': messageText,
          'parse_mode': 'HTML',
          'reply_markup': {
            'inline_keyboard': [
              [
                {'text': '🗑️ Delete Post Immediately', 'url': deleteUrl},
              ]
            ]
          }
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Telegram Alert Failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Telegram Bot Error: $e");
    }
  }
}
