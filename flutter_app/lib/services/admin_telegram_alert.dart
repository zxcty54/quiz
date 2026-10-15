import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'telegram_worker.dart';

class AdminTelegramAlert {
  // Token/chat id yahan nahi hain — sandesh Cloudflare Worker se jata hai.

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// 🏛️ Send Coaching Registration Request With Image, Title, Address & PIN
  static Future<bool> sendCreatorApprovalRequest({
    required String name,
    required String handle,
    required String address,
    required String specialty,
    required String generatedPin,
    String? imageUrl,
  }) async {
    try {
      final safeName = _escapeHtml(name);
      final safeHandle = _escapeHtml(handle);
      final safeAddress = _escapeHtml(address);
      final safeSpecialty = _escapeHtml(specialty);

      final String caption = '''
🏛️ <b>NEW COACHING ONBOARDING REQUEST</b>
━━━━━━━━━━━━━━━━━━━━
🏢 <b>Coaching Title:</b> $safeName
📍 <b>Address:</b> $safeAddress
🆔 <b>Handle:</b> @$safeHandle
📚 <b>Target Domain:</b> $safeSpecialty
🔑 <b>Generated PIN:</b> <code>$generatedPin</code>
🕒 <b>Time:</b> ${DateTime.now().toLocal().toString().split('.')[0]}
━━━━━━━━━━━━━━━━━━━━
<i>Status: Awaiting Verification & Approval...</i>
''';

      final inlineKeyboard = {
        'inline_keyboard': [
          [
            {'text': '✅ Approve @$safeHandle', 'callback_data': 'approve_creator_$safeHandle'},
            {'text': '❌ Reject', 'callback_data': 'reject_creator_$safeHandle'},
          ]
        ]
      };

      // Photo ho to Worker photo ke saath caption bhejega.
      final ok = await TelegramWorker.send(
        text: caption,
        parseMode: 'HTML',
        replyMarkup: inlineKeyboard,
        photoUrl: imageUrl,
      );
      debugPrint("Telegram Alert bheja: $ok");
      return ok;
    } catch (e) {
      debugPrint("❌ Telegram Alert Error: $e");
      return false;
    }
  }

  /// Interactive Post Approval Card
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

      final inlineKeyboard = {
        'inline_keyboard': [
          [
            {'text': '✅ Approve & Go Live', 'callback_data': 'approve_$postId'},
            {'text': '🗑️ Reject & Delete', 'callback_data': 'reject_$postId'},
          ]
        ]
      };

      return TelegramWorker.send(
        text: message,
        parseMode: 'HTML',
        replyMarkup: inlineKeyboard,
      );
    } catch (e) {
      debugPrint("❌ Telegram Alert Error: $e");
      return false;
    }
  }
}
