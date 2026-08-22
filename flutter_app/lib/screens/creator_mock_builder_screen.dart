import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_explainer_service.dart';
import '../services/ai_rate_limiter_service.dart';

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

  Future<void> _openAiStudioModal() async {
    final rawCtrl = TextEditingController();
    bool isAiProcessing = false;
    String? validationMessage;
    int charCount = 0;

    final eligibility = await AiRateLimiterService.checkEligibility();
    if (eligibility['allowed'] == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eligibility['message']),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

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
                        Text('AI Bulk Question Generator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Paste raw test/notes (Max 15 Qs):', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                    Text(
                      '$charCount / ${AiRateLimiterService.maxInputChars}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: charCount > AiRateLimiterService.maxInputChars ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rawCtrl,
                  maxLines: 8,
                  maxLength: AiRateLimiterService.maxInputChars,
                  onChanged: (val) {
                    setModalState(() {
                      charCount = val.length;
                      validationMessage = null;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Paste questions text in English or Hindi...',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                if (validationMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(validationMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
                const SizedBox(height: 12),
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
                      isAiProcessing ? 'AI Structuring Multi-Cards...' : 'Generate Multi-Cards 🚀',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: isAiProcessing
                        ? null
                        : () async {
                            final text = rawCtrl.text.trim();
                            if (text.isEmpty) {
                              setModalState(() => validationMessage = 'Please paste some text first.');
                              return;
                            }

                            setModalState(() => isAiProcessing = true);

                            try {
                              // Use configured key from your service
                              final apiKey = AiExplainerService.geminiApiKey;
                              final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

                              final prompt = '''
Convert the following exam questions into a JSON array. Follow this exact format strictly:
[
  {
    "question": "Question text in Hindi or English",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 0,
    "explanation": "Short solution"
  }
]
Raw Text:
"""
$text
"""
''';

                              final res = await http.post(
                                url,
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  "contents": [
                                    {
                                      "parts": [{"text": prompt}]
                                    }
                                  ],
                                  "generationConfig": {
                                    "responseMimeType": "application/json",
                                    "temperature": 0.1
                                  }
                                }),
                              );

                              if (res.statusCode == 200) {
                                final body = jsonDecode(res.body);
                                String rawJson = body['candidates'][0]['content']['parts'][0]['text'];
                                rawJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
                                final parsed = jsonDecode(rawJson);

                                if (parsed is List && parsed.isNotEmpty) {
                                  await AiRateLimiterService.recordSuccess();

                                  setState(() {
                                    if (_questions.length == 1 && (_questions[0]['question'] as String).isEmpty) {
                                      _questions.clear();
                                    }
                                    _questions.addAll(List<Map<String, dynamic>>.from(parsed));
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✨ Added ${parsed.length} Questions successfully!'),
                                        backgroundColor: const Color(0xFF16A34A),
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {
                                    isAiProcessing = false;
                                    validationMessage = 'Could not parse JSON. Check input text format.';
                                  });
                                }
                              } else {
                                setModalState(() {
                                  isAiProcessing = false;
                                  validationMessage = 'API Error: ${res.statusCode} (${res.body})';
                                });
                              }
                            } catch (err) {
                              setModalState(() {
                                isAiProcessing = false;
                                validationMessage = 'Error: $err';
                              });
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

      await Supabase.instance.client.from('community_posts').insert({
        'creator_id': widget.creatorHandle,
        'content': '⚡ New CBT Mock Test Published: "$title". Tap below to attempt now!',
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
                        const Text('Options & Correct Answer (Tap letter to select):', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
