import 'package:http/http.dart' as http;

class TelegramService {
  static const String _botToken = "1809778528:AAFlwdQMKgiezltaJYyAU5u6vNjblBiIPmo";
  static const String _chatId = "785009742";

  static Future<bool> reportError({
    required String fileName,
    required int questionIndex,
    required String issueType,
    required String questionSnippet,
  }) async {
    final String message = '''
🚩 ERROR REPORTED!
📁 File: $fileName
❓ Q#: Q${questionIndex + 1}
📌 Issue: $issueType
📝 Snippet: $questionSnippet
''';

    final Uri url = Uri.parse("https://api.telegram.org/bot$_botToken/sendMessage");

    try {
      final response = await http.post(
        url,
        body: {
          'chat_id': _chatId,
          'text': message,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
