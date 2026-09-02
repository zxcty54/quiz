import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String _publishTarget = 'PUBLIC'; // 'PUBLIC' or 'BATCH'
  String? _selectedBatchId;
  List<Map<String, dynamic>> _myBatches = [];
  bool _isLoadingBatches = true;

  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _addNewBlankQuestion();
    _fetchCreatorBatches();
  }

  Future<void> _fetchCreatorBatches() async {
    try {
      final coachingRes = await Supabase.instance.client
          .from('coachings')
          .select('id')
          .eq('owner_name', widget.creatorHandle)
          .maybeSingle();

      if (coachingRes != null) {
        final batchesRes = await Supabase.instance.client
            .from('batches')
            .select('id, batch_name, batch_code, status, batch_tests(id)')
            .eq('coaching_id', coachingRes['id'])
            .neq('status', 'HIDDEN')
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _myBatches = List<Map<String, dynamic>>.from(batchesRes ?? []);
            if (_myBatches.isNotEmpty) {
              _selectedBatchId = _myBatches.first['id'].toString();
            }
            _isLoadingBatches = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingBatches = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBatches = false);
    }
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

  // 🛡️ Strict Question Validator
  String? _validateQuestions() {
    if (_questions.isEmpty) {
      return 'Please add at least 1 question.';
    }

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final qText = (q['question'] as String? ?? '').trim();
      final options = (q['options'] as List? ?? []).map((e) => e.toString().trim()).toList();
      final answer = q['answer'];

      if (qText.isEmpty) {
        return '⚠️ Question ${i + 1} is empty. Please enter question text.';
      }

      if (options.length < 4) {
        return '⚠️ Question ${i + 1} is incomplete. 4 options required.';
      }

      for (int o = 0; o < 4; o++) {
        if (options[o].isEmpty) {
          final letter = String.fromCharCode(65 + o);
          return '⚠️ Question ${i + 1} is incomplete.\nPlease fill Option $letter.';
        }
      }

      if (answer == null || answer is! int || answer < 0 || answer > 3) {
        return '⚠️ Question ${i + 1} has an invalid answer selection.';
      }
    }
    return null; // All valid
  }

  // 👁️ Live Student Preview Bottom Sheet
  void _openStudentPreview() {
    final validationError = _validateQuestions();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    int previewCurrentIndex = 0;
    int? selectedOption;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPreviewState) {
          final q = _questions[previewCurrentIndex];
          final options = (q['options'] as List).map((e) => e.toString()).toList();
          final qText = q['question'] as String;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.82,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'STUDENT PREVIEW MODE',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 14),

                // Header Mock Specs (Title, Question Counter & Timer)
                Text(
                  _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Mock Test Preview',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${_questions.length} Questions',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    const Icon(Icons.timer_outlined, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '⏱ $_durationMins Minutes',
                      style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Question Counter Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${previewCurrentIndex + 1} of ${_questions.length}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    Text(
                      '+1 / -0.25 Mark',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Question Box
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Text(
                            qText,
                            style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Options A, B, C, D
                        ...List.generate(4, (oIdx) {
                          final isSelected = selectedOption == oIdx;
                          final letter = String.fromCharCode(65 + oIdx);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => setPreviewState(() => selectedOption = oIdx),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB).withOpacity(0.1)
                                      : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF2563EB) : Colors.grey.withOpacity(0.25),
                                    width: isSelected ? 1.4 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: isSelected ? const Color(0xFF2563EB) : Colors.grey.withOpacity(0.2),
                                      child: Text(
                                        letter,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : (widget.isDarkMode ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        options[oIdx],
                                        style: const TextStyle(fontSize: 13.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Preview Navigation Buttons
                Row(
                  children: [
                    if (previewCurrentIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            setPreviewState(() {
                              previewCurrentIndex--;
                              selectedOption = null;
                            });
                          },
                          child: const Text('← Previous'),
                        ),
                      ),
                    if (previewCurrentIndex > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          if (previewCurrentIndex < _questions.length - 1) {
                            setPreviewState(() {
                              previewCurrentIndex++;
                              selectedOption = null;
                            });
                          } else {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Preview completed. Ready to publish! 👍')),
                            );
                          }
                        },
                        child: Text(
                          previewCurrentIndex < _questions.length - 1 ? 'Next Question →' : 'Done Previewing ✓',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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
                              final List<Map<String, dynamic>> parsedList =
                                  await AiExplainerService.parseBulkQuestionsWithAi(text);

                              if (parsedList.isNotEmpty) {
                                await AiRateLimiterService.recordSuccess();

                                setState(() {
                                  if (_questions.length == 1 && (_questions[0]['question'] as String).isEmpty) {
                                    _questions.clear();
                                  }
                                  _questions.addAll(parsedList);
                                });

                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✨ Added ${parsedList.length} Questions successfully!'),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isAiProcessing = false;
                                  validationMessage = 'Could not parse questions. Ensure questions have options & answer.';
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

    if (_publishTarget == 'BATCH' && _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya target Batch select karein!')));
      return;
    }

    // 🛑 STRICT VALIDATION CHECK
    final validationError = _validateQuestions();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      if (_publishTarget == 'PUBLIC') {
        final res = await Supabase.instance.client.from('creator_mocks').insert({
          'creator_id': widget.creatorHandle,
          'title': title,
          'subject': _selectedSubject,
          'duration_mins': _durationMins,
          'total_questions': _questions.length,
          'questions_json': _questions,
          'attempts_count': 0,
        }).select().single();

        await Supabase.instance.client.from('community_posts').insert({
          'creator_id': widget.creatorHandle,
          'content': '⚡ New CBT Mock Test Published: "$title". Tap below to attempt now!',
          'tag': 'Mock Tests ⚡',
          'mock_id': res['id'],
          'views_count': 1,
        });
      } else {
        await Supabase.instance.client.from('batch_tests').insert({
          'batch_id': _selectedBatchId,
          'test_title': title,
          'subject': _selectedSubject,
          'duration_mins': _durationMins,
          'total_questions': _questions.length,
          'questions_json': _questions,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _publishTarget == 'PUBLIC'
                  ? '🚀 Test Published to Profile & Community Feed!'
                  : '🔒 Private CBT Mock added to Batch successfully!',
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      setState(() => _isPublishing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publish error: $e')));
      }
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
          // Top Settings & Target Selection Header
          Container(
            padding: const EdgeInsets.all(12),
            color: cardBg,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.public_rounded, size: 16),
                        label: const Text('🌐 Public Feed', style: TextStyle(fontSize: 12)),
                        selected: _publishTarget == 'PUBLIC',
                        selectedColor: const Color(0xFF2563EB).withOpacity(0.18),
                        labelStyle: TextStyle(
                          color: _publishTarget == 'PUBLIC' ? const Color(0xFF2563EB) : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (v) => setState(() => _publishTarget = 'PUBLIC'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.lock_rounded, size: 16),
                        label: const Text('🔒 Private Batch', style: TextStyle(fontSize: 12)),
                        selected: _publishTarget == 'BATCH',
                        selectedColor: const Color(0xFF16A34A).withOpacity(0.18),
                        labelStyle: TextStyle(
                          color: _publishTarget == 'BATCH' ? const Color(0xFF16A34A) : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (v) => setState(() => _publishTarget = 'BATCH'),
                      ),
                    ),
                  ],
                ),

                if (_publishTarget == 'BATCH') ...[
                  const SizedBox(height: 10),
                  if (_isLoadingBatches)
                    const LinearProgressIndicator()
                  else if (_myBatches.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Koi Active/Live batch nahi mila. Pehle Dashboard se Batch create karein.',
                              style: TextStyle(fontSize: 11.5, color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedBatchId,
                      decoration: const InputDecoration(
                        labelText: 'Select Target Batch (Available Batches)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.class_outlined, color: Color(0xFF16A34A), size: 20),
                      ),
                      items: _myBatches.map((b) {
                        final List existingTests = b['batch_tests'] ?? [];
                        final String status = b['status'] ?? 'LIVE';
                        final bool isLive = status == 'LIVE';

                        return DropdownMenuItem<String>(
                          value: b['id'].toString(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${b['batch_name']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLive ? const Color(0xFF16A34A).withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${isLive ? "🟢 LIVE" : "⏳ UPCOMING"} • ${existingTests.length} Tests',
                                  style: TextStyle(
                                    color: isLive ? const Color(0xFF16A34A) : Colors.amber.shade800,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedBatchId = val),
                    ),
                ],

                const SizedBox(height: 10),
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
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSubject = v ?? _selectedSubject),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _durationMins,
                        decoration: const InputDecoration(labelText: 'Duration', isDense: true, border: OutlineInputBorder()),
                        items: [5, 10, 15, 30, 60, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m Mins', style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) => setState(() => _durationMins = v ?? _durationMins),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Question Cards List
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
                          decoration: const InputDecoration(hintText: 'Type question statement...', isDense: true, border: OutlineInputBorder()),
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
                                      hintText: 'Option ${String.fromCharCode(65 + oIdx)} (Required)',
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

          // Bottom Action Bar: [Add 1 Card] [ Preview 👁️ ] [ Publish 🚀 ]
          Container(
            padding: const EdgeInsets.all(12),
            color: cardBg,
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Card'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  onPressed: _addNewBlankQuestion,
                ),
                const SizedBox(width: 8),

                // 👁️ PREVIEW BUTTON
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 17, color: Color(0xFF2563EB)),
                  label: const Text('Preview', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openStudentPreview,
                ),
                const SizedBox(width: 8),

                // 🚀 PUBLISH BUTTON
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _publishTarget == 'PUBLIC' ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isPublishing ? null : _publishMockTest,
                    child: _isPublishing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _publishTarget == 'PUBLIC'
                                ? 'Publish ${_questions.length} Qs 🌐'
                                : 'Publish ${_questions.length} Qs 🔒',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
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
