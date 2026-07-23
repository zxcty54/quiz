import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';

class ApiService {
  static const String baseUrl = "https://raw.githubusercontent.com/zxcty54/quiz/main/";

  static Future<List<Question>> fetchQuestions(String jsonFileName) async {
    final response = await http.get(Uri.parse("$baseUrl$jsonFileName"));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Question.fromJson(item)).toList();
    } else {
      throw Exception("Failed to load questions from GitHub");
    }
  }
}
