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

  /// 🏛️ Send New Coaching / Creator Onboarding Request with PIN
  static Future<bool> sendCreatorApprovalRequest({
    required String name,
    required String handle,
    required String specialty,
    required String generatedPin,
  }) async {
    try {
      final safeName = _escapeHtml(name);
      final safeHandle = _escapeHtml(handle);
      final safeSpecialty = _escapeHtml(specialty);

      final String message = '''
🏛️ <b>NEW COACHING / CREATOR ONBOARDING REQUEST</b>
━━━━━━━━━━━━━━━━━━━━
👤 <b>Institute / Director:</b> $safeName
🆔 <b>Handle:</b> @$safeHandle
📚 <b>Specialty:</b> $safeSpecialty
🔑 <b>Generated PIN:</b> <code>$generatedPin</code>
🕒 <b>Time:</b> ${DateTime.now().toLocal().toString().split('.')[0]}
━━━━━━━━━━━━━━━━━━━━
<i>Status: Pending Admin approval & verification...</i>
''';

      // 🔘 Interactive Buttons for Admin Approval
      final inlineKeyboard = {
        'inline_keyboard': [
          [
            {'text': '✅ Approve @$safeHandle', 'callback_data': 'approve_creator_$safeHandle'},
            {'text': '❌ Reject', 'callback_data': 'reject_creator_$safeHandle'},
          ]
        ]
      };

      final uri = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _adminChatId,
          'text': message,
          'parse_mode': 'HTML',
          'reply_markup': inlineKeyboard,
        }),
      ).timeout(const Duration(seconds: 8));

      debugPrint("Telegram Creator Alert Response: ${res.statusCode} | ${res.body}");
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Telegram Creator Alert Error: $e");
      return false;
    }
  }

  /// 🚀 Send Interactive Post Approval Card to Telegram with Action Buttons
  static Future<bool> sendForInteractiveApproval({
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
🛡️ <b>NEW POST SUBMITTED FOR MODERATION</b>

🆔 <b>Post ID:</b> <code>#$postId</code>
👤 <b>Author:</b> $safeAuthor (@$safeHandle)
🏷️ <b>Category:</b> $safeTag$pollNotice$imgNotice

📝 <b>Content Preview:</b>
<i>$safeContent</i>

⏳ <i>Status: Awaiting Moderator decision...</i>
''';

      // 🔘 Interactive Inline Buttons for 1-Tap Control
      final inlineKeyboard = {
        'inline_keyboard': [
          [
            {'text': '✅ Approve & Go Live', 'callback_data': 'approve_$postId'},
            {'text': '🗑️ Reject & Delete', 'callback_data': 'reject_$postId'},
          ]
        ]
      };

      final uri = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _adminChatId,
          'text': message,
          'parse_mode': 'HTML',
          'reply_markup': inlineKeyboard,
        }),
      ).timeout(const Duration(seconds: 8));

      debugPrint("Telegram Interactive Alert Response: ${res.statusCode} | ${res.body}");
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Telegram Alert Error: $e");
      return false;
    }
  }

  /// Backward compatible alias
  static Future<bool> notifyNewPost({
    required int postId,
    required String authorName,
    required String authorHandle,
    required String tag,
    required String content,
    String? imageUrl,
    bool hasPoll = false,
  }) {
    return sendForInteractiveApproval(
      postId: postId,
      authorName: authorName,
      authorHandle: authorHandle,
      tag: tag,
      content: content,
      imageUrl: imageUrl,
      hasPoll: hasPoll,
    );
  }
}
