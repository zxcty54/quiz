import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';
import '../services/telegram_tracker.dart';
import 'sectional_cbt_screen.dart';

class ChapterSelectScreen extends StatelessWidget {
  final String categoryTitle;
  final Map<String, String> chapterMapping;

  const ChapterSelectScreen({
    super.key,
    required this.categoryTitle,
    required this.chapterMapping,
  });

  void _launchChapterTest(BuildContext context, String chapterName, String jsonFile) async {
    // 📲 Telegram Alert
    TelegramTracker.sendActivityAlert(
      screenName: "Started Chapter Test",
      extraDetails: "$categoryTitle - $chapterName",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await http.get(
        Uri.parse("https://raw.githubusercontent.com/zxcty54/quiz/main/$jsonFile"),
      );
      
      if (context.mounted) Navigator.pop(context);

      if (res.statusCode == 200) {
        List body = jsonDecode(res.body);
        List<Question> qList = body.map((i) => Question.fromJson(i)).toList();

        if (context.mounted && qList.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => SectionalCbtScreen(
                testTitle: chapterName,
                questions: qList,
                subFolder: jsonFile,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Questions load nahi ho paye. Connection check karein!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = chapterMapping.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final chapterName = entries[index].key;
          final jsonFile = entries[index].value;

          return Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Text('📝', style: TextStyle(fontSize: 18)),
              ),
              title: Text(
                chapterName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              // 🚀 FIX: .json file name HATA DIYA GAYA HAI! Ab Clean Subtitle Dikhega
              subtitle: const Text(
                'Practice Set • CBT Mode',
                style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2563EB)),
              onTap: () => _launchChapterTest(context, chapterName, jsonFile),
            ),
          );
        },
      ),
    );
  }
}
