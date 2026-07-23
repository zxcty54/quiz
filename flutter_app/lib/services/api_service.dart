import 'dart0:convert';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';

class ApiService {
  static const String baseUrl = "https://raw.githubusercontent.com/zxcty54/quiz/main/";

  static Future<List<Question>> fetchQuestions(String jsonFileName) async {
    // 🔗 URL encode to handle spaces in filenames like "Modern History/set1.json"
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
      throw Exception("Network Error: Make sure Mobile Data/Wi-Fi is active. ($e)");
    }
  }
}
