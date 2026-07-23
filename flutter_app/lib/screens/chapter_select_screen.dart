import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart';

class ChapterSelectScreen extends StatelessWidget {
  final String categoryTitle;
  final Map<String, String> chapterMapping;

  const ChapterSelectScreen({
    super.key,
    required this.categoryTitle,
    required this.chapterMapping,
  });

  void _showInstructionModal(BuildContext context, String chapterName, String jsonFileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          chapterName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('📋 Test Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('⏱️ 30 Seconds / Question'),
            Text('🎯 Latest Exam MCQ Pattern'),
            Text('🌐 Bilingual (Hindi / English) Support'),
            Text('💡 Detailed Explanations Provided'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context); // Close modal
              
              // Show Loading Indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // Fetch JSON Questions from Raw GitHub
                List<Question> questions = await ApiService.fetchQuestions(jsonFileName);
                
                if (context.mounted) {
                  Navigator.pop(context); // Close loading indicator
                  
                  // Navigate to Live Quiz Engine
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        chapterName: chapterName,
                        fileName: jsonFileName,
                        questions: questions,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error loading quiz: $e')),
                  );
                }
              }
            },
            child: const Text('Start Test 🚀'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapters = chapterMapping.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                chapter.key,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                'File: ${chapter.value}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _showInstructionModal(context, chapter.key, chapter.value),
            ),
          );
        },
      ),
    );
  }
}
