import 'package:flutter/material.dart';
import '../services/telegram_tracker.dart';
import 'quiz_screen.dart';

class ChapterSelectScreen extends StatelessWidget {
  final String categoryTitle;
  final Map<String, String> chapterMapping;

  const ChapterSelectScreen({
    super.key,
    required this.categoryTitle,
    required this.chapterMapping,
  });

  @override
  Widget build(BuildContext context) {
    TelegramTracker.logActivity("Opened Category Chapters: $categoryTitle");

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle),
      ),
      body: chapterMapping.isEmpty
          ? const Center(child: Text("No chapters available."))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: chapterMapping.length,
              itemBuilder: (context, index) {
                String chapterName = chapterMapping.keys.elementAt(index);
                String jsonPath = chapterMapping.values.elementAt(index);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(chapterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      TelegramTracker.logActivity("Started Chapter Test: $chapterName");
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => QuizScreen(
                            title: chapterName, // 🟢 FIXED: 'chapterTitle' changed to 'title'
                            jsonPath: jsonPath,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
