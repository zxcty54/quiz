import 'package:flutter/material.dart';
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => QuizScreen(
                            title: chapterName, // 🟢 MATCHED: title parameter
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
