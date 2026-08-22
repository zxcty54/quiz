import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminTelegramAlert {
  static const String _botToken = 'YOUR_TELEGRAM_BOT_TOKEN';
  static const String _adminChatId = 'YOUR_ADMIN_CHAT_ID';

  static Future<void> sendAbuseAlert({
    required int postId,
    required String postContent,
    required String authorHandle,
    required int totalReports,
    required String lastReason,
  }) async {
    if (_botToken == 'YOUR_TELEGRAM_BOT_TOKEN' || _adminChatId == 'YOUR_ADMIN_CHAT_ID') {
      debugPrint("Telegram Alert: Bot credentials not configured. Alert skipped.");
      return;
    }

    try {
      final message = '''
🚨 <b>URGENT: Community Post Abuse Alert</b>

📌 <b>Post ID:</b> $postId
👤 <b>Author Handle:</b> @$authorHandle
📊 <b>Total Reports:</b> $totalReports
⚠️ <b>Last Reported Reason:</b> $lastReason

📝 <b>Content Preview:</b>
<i>${postContent.length > 250 ? '${postContent.substring(0, 250)}...' : postContent}</i>
''';

      final uri = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _adminChatId,
          'text': message,
          'parse_mode': 'HTML',
        }),
      );
    } catch (e) {
      debugPrint("Failed to send Telegram alert: $e");
    }
  }
}
