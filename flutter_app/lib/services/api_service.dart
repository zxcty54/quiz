import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';

class ApiService {
  // 🚀 FIXED: GitHub raw ki jagah jsDelivr CDN Base URL use kiya hai
  // Isse Mobile Data par 'Failed host lookup' ya 'SocketException' error kabhi nahi aayega!
  static const String baseUrl = "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/";

  static Future<List<Question>> fetchQuestions(String jsonFileName) async {
    // 🔗 Handles spaces/special chars in filenames like "Modern History/set1.json"
    final String fullUrl = Uri.encodeFull("$baseUrl$jsonFileName");

    try {
      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((dynamic item) => Question.fromJson(item)).toList();
      } else {
        throw Exception("Failed to load questions (Status Code: ${response.statusCode})");
      }
    } catch (e) {
      throw Exception("Network Error: Please check internet connection. ($e)");
    }
  }
}
