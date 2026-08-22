import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatorMockBuilderScreen extends StatefulWidget {
  final String creatorHandle;
  final bool isDarkMode;

  const CreatorMockBuilderScreen({
    super.key,
    required this.creatorHandle,
    required this.isDarkMode,
  });

  @override
  State<CreatorMockBuilderScreen> createState() => _CreatorMockBuilderScreenState();
}

class _CreatorMockBuilderScreenState extends State<CreatorMockBuilderScreen> {
  final _titleCtrl = TextEditingController(text: 'Special Mock Drill');
  String _selectedSubject = 'general';
  int _durationMins = 15;
  bool _isPublishing = false;

  // List holding all dynamic question cards
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _addNewBlankQuestion();
  }

  void _addNewBlankQuestion() {
    setState(() {
      _questions.add({
        'question': '',
        'options': ['', '', '', ''],
        'answer': 0,
        'explanation': '',
      });
    });
  }

  void _removeQuestion(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _questions.removeAt(index);
      if (_questions.isEmpty) _addNewBlankQuestion();
    });
  }

  // ⚡ One-Shot AI Bulk Generator
  Future<void> _openAiStudioModal() async {
    final rawCtrl = TextEditingController();
    bool isAiProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                        SizedBox(width: 8),
                        Text('AI Bulk Question Generator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Text(
                  'Paste your whole 10, 20 or 50 questions document here. AI will structure all questions into editable cards instantly.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.35),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rawCtrl,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    hintText: 'Paste rough notes, Hindi/English test series or scanned text...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: isAiProcessing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded, color: Colors.amber),
                    label: Text(
                      isAiProcessing ? 'AI Structuring Multi-Cards...' : 'Auto-Generate Cards with AI 🚀',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    onPressed: isAiProcessing
                        ? null
                        : () async {
                            final text = rawCtrl.text.trim();
                            if (text.isEmpty) return;

                            setModalState(() => isAiProcessing = true);
                            try {
                              final model = GenerativeModel(
                                model: 'gemini-1.5-flash',
                                apiKey: 'YOUR_GEMINI_API_KEY', // Bind with your key
                                generationConfig: GenerationConfig(responseMimeType: 'application/json', temperature: 0.1),
                              );

                              final prompt = '''
Parse the following test material into a JSON array of multiple choice questions:
[
  {
    "question": "Question text in Hindi or English",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 0, // Integer 0 for A, 1 for B, 2 for C, 3 for D
    "explanation": "Concise explanation"
  }
]
Raw Data:
"""
$text
"""
''';

                              final response = await model.generateContent([Content.text(prompt)]);
                              final parsed = jsonDecode(response.text ?? '[]');

                              if (parsed is List && parsed.isNotEmpty) {
                                setState(() {
                                  // Clean empty placeholder and populate generated cards
                                  if (_questions.length == 1 && (_questions[0]['question'] as String).isEmpty) {
                                    _questions.clear();
                                  }
                                  _questions.addAll(List<Map<String, dynamic>>.from(parsed));
                                });

                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✨ AI generated ${_questions.length} Question Cards!'),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              }
                            } catch (err) {
                              setModalState(() => isAiProcessing = false);
                            }
                          },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publishMockTest() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Test Title')));
      return;
    }

    final validQuestions = _questions.where((q) => (q['question'] as String).trim().isNotEmpty).toList();
    if (validQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least 1 complete question!')));
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final res = await Supabase.instance.client.from('creator_mocks').insert({
        'creator_id': widget.creatorHandle,
        'title': title,
        'subject': _selectedSubject,
        'duration_mins': _durationMins,
        'questions_json': validQuestions,
        'attempts_count': 0,
      }).select().single();

      // Also publish directly to Community Feed
      await Supabase.instance.client.from('community_posts').insert({
        'creator_id': widget.creatorHandle,
        'content': '⚡ New Mock Drill Published: "$title". Click below to practice now!',
        'tag': 'Mock Tests ⚡',
        'mock_id': res['id'],
        'views_count': 1,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Test Published to Profile & Community Feed!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      setState(() => _isPublishing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publish error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Creator Studio Builder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
            label: const Text('AI Import', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            onPressed: _openAiStudioModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // ⚙️ Header Config Row (Title, Subject, Duration)
          Container(
            padding: const EdgeInsets.all(12),
            color: cardBg,
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Test Title / Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        decoration: const InputDecoration(labelText: 'Subject', isDense: true, border: OutlineInputBorder()),
                        items: ['general', 'history', 'polity', 'geography', 'science', 'maths', 'reasoning']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSubject = v ?? _selectedSubject),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _durationMins,
                        decoration: const InputDecoration(labelText: 'Duration', isDense: true, border: OutlineInputBorder()),
                        items: [5, 10, 15, 30, 60, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m Mins'))).toList(),
                        onChanged: (v) => setState(() => _durationMins = v ?? _durationMins),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 📜 Question Cards View
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _questions.length,
              itemBuilder: (context, idx) {
                final q = _questions[idx];
                final List options = q['options'] ?? ['', '', '', ''];
                final int currentAns = q['answer'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Question #${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB))),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              onPressed: () => _removeQuestion(idx),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        TextFormField(
                          initialValue: q['question'],
                          maxLines: 2,
                          decoration: const InputDecoration(hintText: 'Type question here...', isDense: true, border: OutlineInputBorder()),
                          onChanged: (val) => q['question'] = val,
                        ),
                        const SizedBox(height: 10),
                        const Text('Options & Correct Answer (Tap letter to select correct):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        ...List.generate(4, (oIdx) {
                          final isCorrect = currentAns == oIdx;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => q['answer'] = oIdx),
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isCorrect ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.3),
                                    child: Text(
                                      String.fromCharCode(65 + oIdx),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isCorrect ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: options[oIdx],
                                    decoration: InputDecoration(
                                      hintText: 'Option ${String.fromCharCode(65 + oIdx)}',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (val) => options[oIdx] = val,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        TextFormField(
                          initialValue: q['explanation'],
                          decoration: const InputDecoration(labelText: 'Explanation (Optional)', isDense: true, border: OutlineInputBorder()),
                          onChanged: (val) => q['explanation'] = val,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 🚀 Bottom Action Row (Add Manual + Publish)
          Container(
            padding: const EdgeInsets.all(12),
            color: cardBg,
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add 1 Card'),
                  onPressed: _addNewBlankQuestion,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isPublishing ? null : _publishMockTest,
                    child: _isPublishing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Publish ${_questions.length} Qs Test 🚀', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
