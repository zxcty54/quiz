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

  /// 💰 Naya Premium Payment Request — screenshot ke saath admin ko khabar
  static Future<bool> sendPremiumPaymentRequest({
    required String userName,
    required String userId,
    required int amount,
    String? upiRef,
    String? screenshotUrl,
  }) async {
    try {
      final String caption = '''
💰 <b>NAYA PREMIUM REQUEST</b>
━━━━━━━━━━━━━━━━━━━━
👤 <b>Student:</b> ${_escapeHtml(userName)}
🆔 <b>User ID:</b> <code>${_escapeHtml(userId)}</code>
💵 <b>Amount:</b> ₹$amount
🔢 <b>UPI Ref:</b> <code>${_escapeHtml(upiRef ?? 'photo se nahi mila')}</code>
🕒 <b>Time:</b> ${DateTime.now().toLocal().toString().split('.')[0]}
━━━━━━━━━━━━━━━━━━━━
<i>PhonePe Business me paisa mila lo, phir Admin Hub → Premium tab se Approve karo.</i>
''';

      final ok = await TelegramWorker.send(
        text: caption,
        parseMode: 'HTML',
        photoUrl: screenshotUrl,
      );
      debugPrint("Premium Telegram Alert bheja: $ok");
      return ok;
    } catch (e) {
      debugPrint("❌ Premium Telegram Alert Error: $e");
      return false;
    }
  }

}