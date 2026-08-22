import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminTelegramAlert {
  // 🔐 Apne Telegram Bot Token aur Admin Chat ID se replace karein
  static const String _botToken = '1809778528:AAFlwdQMKgiezltaJYyAU5u6vNjblBiIPmo';
  static const String _adminChatId = '785009742';

  /// Har naye community post ka real-time notification with detail
  static Future<void> notifyNewPost({
    required int postId,
    required String authorName,
    required String authorHandle,
    required String tag,
    required String content,
    String? imageUrl,
    bool hasPoll = false,
  }) async {
    if (_botToken == 'YOUR_TELEGRAM_BOT_TOKEN' || _adminChatId == 'YOUR_ADMIN_CHAT_ID') {
      debugPrint("Telegram Bot not configured. Alert skipped.");
      return;
    }

    try {
      final String preview = content.length > 300 ? '${content.substring(0, 300)}...' : content;
      final String pollNotice = hasPoll ? '\n📊 <i>Contains Interactive Daily Quiz / Poll</i>' : '';
      final String imgNotice = (imageUrl != null && imageUrl.isNotEmpty) ? '\n🖼️ <i>Attachment: Image included</i>' : '';

      final String message = '''
🛡️ <b>NEW COMMUNITY POST SUBMITTED</b>

🆔 <b>Post ID:</b> #$postId
👤 <b>Author:</b> $authorName (@$authorHandle)
🏷️ <b>Category:</b> $tag
$pollNotice$imgNotice

📝 <b>Content:</b>
<i>$preview</i>

⚡ <b>Actions:</b>
Purge instantly from App Admin Hub if abusive.
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
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Failed to send Telegram moderation alert: $e");
    }
  }

  /// Community Post Multiple Abuse Reports Alert
  static Future<void> sendAbuseAlert({
    required int postId,
    required String postContent,
    required String authorHandle,
    required int totalReports,
    required String lastReason,
  }) async {
    if (_botToken == 'YOUR_TELEGRAM_BOT_TOKEN' || _adminChatId == 'YOUR_ADMIN_CHAT_ID') return;

    try {
      final message = '''
🚨 <b>URGENT: Community Post Abuse Alert!</b>

📌 <b>Post ID:</b> #$postId
👤 <b>Author:</b> @$authorHandle
📊 <b>Total Reports:</b> $totalReports
⚠️ <b>Reason:</b> $lastReason

📝 <b>Content:</b>
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
      debugPrint("Failed to send Abuse alert: $e");
    }
  }
}
