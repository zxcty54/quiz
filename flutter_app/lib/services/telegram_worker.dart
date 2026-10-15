import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Telegram par sandesh bhejne ka ek-matra raasta — Cloudflare Worker se.
///
/// Bot token aur chat id app me KABHI nahi hain. Woh sirf Cloudflare
/// Worker ke Secrets me hain. App bas Worker ko sandesh deta hai,
/// Worker Telegram ko bhej deta hai. APK kholne par kisi ko token
/// nahi mil sakta.
class TelegramWorker {
  /// Cloudflare Worker ka pata — user se milne par yahan bharna hai.
  static const String _workerUrl = 'https://mocktester-telegram.nitesh-skyhigh.workers.dev';

  /// App ki pehchan key (ye bot token NAHI hai; Worker isse sirf
  /// app ko pehchanta hai. Bot hamesha Worker ke Secret me surakshit hai.)
  static const String _appKey = 'mocktester-nitesh2026';

  /// Saada text/HTML sandesh bhejo. Photo ho to photo ke saath caption.
  static Future<bool> send({
    required String text,
    String parseMode = 'HTML',
    Map<String, dynamic>? replyMarkup,
    String? photoUrl,
  }) async {
    if (_workerUrl.isEmpty) {
      debugPrint('TelegramWorker: Worker URL abhi set nahi hai.');
      return false;
    }
    try {
      final res = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Key': _appKey,
            },
            body: jsonEncode({
              'text': text,
              'parse_mode': parseMode,
              if (replyMarkup != null) 'reply_markup': replyMarkup,
              if (photoUrl != null && photoUrl.isNotEmpty) 'photo': photoUrl,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('TelegramWorker error: $e');
      return false;
    }
  }
}
