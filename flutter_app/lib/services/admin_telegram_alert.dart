import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminTelegramAlert {
  static const String _botToken = '1809778528:AAFlwdQMKgiezltaJYyAU5u6vNjblBiIPmo';
  static const String _adminChatId = '785009742';

  /// HTML Special Character Sanitizer (Prevents Telegram parse errors)
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Real-time alert dispatch on every new post
  static Future<bool> notifyNewPost({
    required int postId,
    required String authorName,
    required String authorHandle,
    required String tag,
    required String content,
    String? imageUrl,
    bool hasPoll = false,
  }) async {
    try {
      final safeContent = _escapeHtml(content.length > 350 ? '${content.substring(0, 350)}...' : content);
      final safeAuthor = _escapeHtml(authorName);
      final safeHandle = _escapeHtml(authorHandle);
      final safeTag = _escapeHtml(tag);

      final String pollNotice = hasPoll ? '\n📊 <b>Attachment:</b> Interactive Daily Quiz Included' : '';
      final String imgNotice = (imageUrl != null && imageUrl.isNotEmpty) ? '\n🖼️ <b>Attachment:</b> Screenshot Image Attached' : '';

      final String message = '''
🛡️ <b>NEW COMMUNITY POST SUBMITTED</b>

🆔 <b>Post ID:</b> <code>#$postId</code>
👤 <b>Author:</b> $safeAuthor (@$safeHandle)
🏷️ <b>Category:</b> $safeTag$pollNotice$imgNotice

📝 <b>Content Preview:</b>
<i>$safeContent</i>

⚡ <b>Action:</b>
Manage or purge instantly from Admin Control Suite in App.
''';

      final uri = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _adminChatId,
          'text': message,
          'parse_mode': 'HTML',
        }),
      ).timeout(const Duration(seconds: 8));

      debugPrint("Telegram Alert Response: ${res.statusCode} | ${res.body}");
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Telegram Alert Error: $e");
      return false;
    }
  }
}
