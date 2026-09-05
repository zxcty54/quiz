import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_explainer_service.dart';
import '../services/ai_rate_limiter_service.dart';
import 'math_text.dart';

// 🎯 Safe Question Data Structure with dedicated controllers
class QuestionCardData {
  final TextEditingController questionCtrl;
  final List<TextEditingController> optionCtrls;
  final TextEditingController explanationCtrl;
  int answerIndex;

  QuestionCardData({
    String question = '',
    List<String>? options,
    this.answerIndex = 0,
    String explanation = '',
  })  : questionCtrl = TextEditingController(text: question),
        optionCtrls = List.generate(
          4,
          (i) => TextEditingController(text: (options != null && options.length > i) ? options[i] : ''),
        ),
        explanationCtrl = TextEditingController(text: explanation);

  Map<String, dynamic> toJson() => {
        'question': questionCtrl.text.trim(),
        'options': optionCtrls.map((c) => c.text.trim()).toList(),
        'answer': answerIndex,
        'explanation': explanationCtrl.text.trim(),
      };

  void dispose() {
    questionCtrl.dispose();
    for (var c in optionCtrls) {
      c.dispose();
    }
    explanationCtrl.dispose();
  }
}

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

  String _publishTarget = 'PUBLIC';
  String? _selectedBatchId;
  List<Map<String, dynamic>> _myBatches = [];
  bool _isLoadingBatches = true;
  String _authorDisplayName = '';

  final List<QuestionCardData> _questionCards = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _addNewBlankQuestion();
    _fetchCreatorBatches();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (var q in _questionCards) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchCreatorBatches() async {
    try {
      final coachingRes = await Supabase.instance.client
          .from('coachings')
          .select('id, name')
          .ilike('owner_name', widget.creatorHandle)
          .maybeSingle();

      if (coachingRes != null) {
        _authorDisplayName = coachingRes['name'] ?? widget.creatorHandle;
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
        _authorDisplayName = widget.creatorHandle;
        if (mounted) setState(() => _isLoadingBatches = false);
      }
    } catch (_) {
      _authorDisplayName = widget.creatorHandle;
      if (mounted) setState(() => _isLoadingBatches = false);
    }
  }

  void _addNewBlankQuestion() {
    setState(() {
      _questionCards.add(QuestionCardData());
    });
  }

  void _removeQuestion(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _questionCards[index].dispose();
      _questionCards.removeAt(index);
      if (_questionCards.isEmpty) _addNewBlankQuestion();
    });
  }

  String? _validateQuestions() {
    if (_questionCards.isEmpty) return 'Kam se kam 1 question hona zaroori hai.';

    for (int i = 0; i < _questionCards.length; i++) {
      final q = _questionCards[i];
      if (q.questionCtrl.text.trim().isEmpty) {
        return '⚠️ Question #${i + 1} empty hai.';
      }
      for (int o = 0; o < 4; o++) {
        if (q.optionCtrls[o].text.trim().isEmpty) {
          final letter = String.fromCharCode(65 + o);
          return '⚠️ Question #${i + 1} ka Option $letter bharna zaroori hai.';
        }
      }
    }
    return null;
  }

  // 📷 ML Kit OCR Scanner Engine
  Future<String?> _scanTextFromCameraOrGallery(ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: source, imageQuality: 90);
      if (photo == null) return null;

      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.devanagari); // Hindi + English support
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      return recognizedText.text;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OCR Error: $e')));
      }
      return null;
    }
  }

  // ⚡ Smart Offline Heuristic Parser
  List<QuestionCardData> _parseRawCoachingInput(String text) {
    final List<QuestionCardData> result = [];
    final lines = text.replaceAll('\r\n', '\n').split('\n');

    StringBuffer qBuf = StringBuffer();
    List<String> opts = [];
    int ansIdx = 0;
    StringBuffer expBuf = StringBuffer();

    final qStartRegex = RegExp(r'^(Q\s*\.?\s*\d+|^\d+[\.\)])\s+', caseSensitive: false);
    final optRegex = RegExp(r'^(\([A-Da-d1-4]\)|[A-Da-d1-4][\.\)])\s*');
    final ansRegex = RegExp(r'^(Ans|Answer|उत्तर|सही उत्तर)[\s\.:\-_]+([A-Da-d1-4])', caseSensitive: false);
    final expRegex = RegExp(r'^(Exp|Explanation|व्याख्या|हल)[\s\.:\-_]*', caseSensitive: false);

    void pushQuestion() {
      if (qBuf.isNotEmpty && opts.isNotEmpty) {
        while (opts.length < 4) {
          opts.add('Option ${String.fromCharCode(65 + opts.length)}');
        }
        result.add(QuestionCardData(
          question: qBuf.toString().trim(),
          options: opts.sublist(0, 4),
          answerIndex: ansIdx < 4 ? ansIdx : 0,
          explanation: expBuf.toString().trim(),
        ));
      }
      qBuf.clear();
      opts = [];
      ansIdx = 0;
      expBuf.clear();
    }

    String mode = 'Q';

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (qStartRegex.hasMatch(line)) {
        pushQuestion();
        mode = 'Q';
        qBuf.writeln(line.replaceFirst(qStartRegex, '').trim());
      } else if (ansRegex.hasMatch(line)) {
        mode = 'ANS';
        final m = ansRegex.firstMatch(line);
        if (m != null) {
          final key = m.group(2)!.toUpperCase();
          if (key == 'A' || key == '1') ansIdx = 0;
          if (key == 'B' || key == '2') ansIdx = 1;
          if (key == 'C' || key == '3') ansIdx = 2;
          if (key == 'D' || key == '4') ansIdx = 3;
        }
      } else if (expRegex.hasMatch(line)) {
        mode = 'EXP';
        expBuf.writeln(line.replaceFirst(expRegex, '').trim());
      } else if (optRegex.hasMatch(line)) {
        mode = 'OPT';
        opts.add(line.replaceFirst(optRegex, '').trim());
      } else {
        if (mode == 'OPT' && opts.isNotEmpty) {
          opts[opts.length - 1] = "${opts.last} $line";
        } else if (mode == 'EXP') {
          expBuf.writeln(line);
        } else {
          qBuf.writeln(line);
        }
      }
    }
    pushQuestion();
    return result;
  }

  // 🌟 Smart Studio Modal: OCR + Text Paste + AI Fallback
  void _openSmartPaperModal() {
    final rawTextCtrl = TextEditingController();
    bool isAiLoading = false;

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
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                        SizedBox(width: 6),
                        Text('Smart Mock Importer ⚡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 4),

                // OCR Image Trigger Action Chips
                Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF2563EB)),
                      label: const Text('Photo Kheecho (OCR)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final scanned = await _scanTextFromCameraOrGallery(ImageSource.camera);
                        if (scanned != null && scanned.isNotEmpty) {
                          setModalState(() => rawTextCtrl.text = scanned);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF16A34A)),
                      label: const Text('Gallery se Lo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final scanned = await _scanTextFromCameraOrGallery(ImageSource.gallery);
                        if (scanned != null && scanned.isNotEmpty) {
                          setModalState(() => rawTextCtrl.text = scanned);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: rawTextCtrl,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    hintText: 'Notes, WhatsApp text ya photo OCR text yahan paste karein...\n\nQ1. Example question\nA) Opt 1\nB) Opt 2\nAns: B',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. FAST LOCAL CONVERT (Primary - Free)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('Instant Auto Convert (Free & Fast)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: isAiLoading
                        ? null
                        : () {
                            final text = rawTextCtrl.text.trim();
                            if (text.isEmpty) return;

                            final localParsed = _parseRawCoachingInput(text);
                            if (localParsed.isNotEmpty) {
                              setState(() {
                                if (_questionCards.length == 1 && _questionCards[0].questionCtrl.text.isEmpty) {
                                  _questionCards.clear();
                                }
                                _questionCards.addAll(localParsed);
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ ${localParsed.length} Questions added!'), backgroundColor: const Color(0xFF16A34A)),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ Local format match nahi hua. Neeche diye AI Auto-Fix ka use karein.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                  ),
                ),
                const SizedBox(height: 8),

                // 2. AI FALLBACK (Single Call - Safe Quota Deduction)
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                    ),
                    icon: isAiLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)))
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(isAiLoading ? 'AI Processing Single Batch...' : 'AI Auto-Clean & Fix (Messy Notes/OCR) 🪄'),
                    onPressed: isAiLoading
                        ? null
                        : () async {
                            final text = rawTextCtrl.text.trim();
                            if (text.isEmpty) return;

                            setModalState(() => isAiLoading = true);

                            try {
                              final List<Map<String, dynamic>> aiResult =
                                  await AiExplainerService.parseBulkQuestionsWithAi(text);

                              if (aiResult.isNotEmpty) {
                                await AiRateLimiterService.recordSuccess(); // Only deducts on success

                                final converted = aiResult.map((m) {
                                  final opts = (m['options'] as List? ?? []).map((e) => e.toString()).toList();
                                  return QuestionCardData(
                                    question: m['question']?.toString() ?? '',
                                    options: opts,
                                    answerIndex: m['answer'] is int ? m['answer'] : 0,
                                    explanation: m['explanation']?.toString() ?? '',
                                  );
                                }).toList();

                                setState(() {
                                  if (_questionCards.length == 1 && _questionCards[0].questionCtrl.text.isEmpty) {
                                    _questionCards.clear();
                                  }
                                  _questionCards.addAll(converted);
                                });

                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('✨ AI added ${converted.length} Questions successfully!'), backgroundColor: const Color(0xFF16A34A)),
                                  );
                                }
                              } else {
                                throw Exception('Invalid response structure');
                              }
                            } catch (err) {
                              setModalState(() => isAiLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('AI Format parse nahi kar saka. Quota deduct nahi hua hai.'), backgroundColor: Colors.redAccent),
                              );
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

  // 👁️ Live Student Preview with LaTeX Math
  void _openStudentPreview() {
    final validationError = _validateQuestions();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError), backgroundColor: Colors.red.shade800));
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
          final q = _questionCards[previewCurrentIndex];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.84,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          Text('STUDENT CBT PREVIEW', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 14),
                Text(_titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Mock Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${_questionCards.length} Questions • ⏱ $_durationMins Mins', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 14),

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
                          child: MathFormattedText(
                            text: q.questionCtrl.text,
                            textStyle: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 14),

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
                                  color: isSelected ? const Color(0xFF2563EB).withOpacity(0.1) : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSelected ? const Color(0xFF2563EB) : Colors.grey.withOpacity(0.25)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: isSelected ? const Color(0xFF2563EB) : Colors.grey.withOpacity(0.2),
                                      child: Text(letter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: MathFormattedText(
                                        text: q.optionCtrls[oIdx].text,
                                        textStyle: const TextStyle(fontSize: 13.5),
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

                Row(
                  children: [
                    if (previewCurrentIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setPreviewState(() {
                            previewCurrentIndex--;
                            selectedOption = null;
                          }),
                          child: const Text('← Previous'),
                        ),
                      ),
                    if (previewCurrentIndex > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                        onPressed: () {
                          if (previewCurrentIndex < _questionCards.length - 1) {
                            setPreviewState(() {
                              previewCurrentIndex++;
                              selectedOption = null;
                            });
                          } else {
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text(previewCurrentIndex < _questionCards.length - 1 ? 'Next Question →' : 'Done Previewing ✓'),
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

  // 🚀 Publish Mock Test to Supabase
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

    final validationError = _validateQuestions();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError), backgroundColor: Colors.red.shade800));
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final client = Supabase.instance.client;
      final authorName = _authorDisplayName.isNotEmpty ? _authorDisplayName : widget.creatorHandle;
      final formattedQuestions = _questionCards.map((q) => q.toJson()).toList();

      if (_publishTarget == 'PUBLIC') {
        final res = await client.from('creator_mocks').insert({
          'creator_id': widget.creatorHandle,
          'title': title,
          'subject': _selectedSubject,
          'duration_mins': _durationMins,
          'total_questions': formattedQuestions.length,
          'questions_json': formattedQuestions,
          'attempts_count': 0,
        }).select().single();

        await client.from('community_posts').insert({
          'creator_id': widget.creatorHandle,
          'author_name': authorName,
          'content': '⚡ New CBT Mock Test Published: "$title". Total ${formattedQuestions.length} Questions.',
          'tag': 'Mock Tests ⚡',
          'mock_id': res['id'],
          'is_approved': true,
          'views_count': 1,
          'upvotes': 0,
          'downvotes': 0,
          'shares_count': 0,
          'bookmarks_count': 0,
        });
      } else {
        await client.from('batch_tests').insert({
          'batch_id': _selectedBatchId,
          'test_title': title,
          'subject': _selectedSubject,
          'duration_mins': _durationMins,
          'total_questions': formattedQuestions.length,
          'questions_json': formattedQuestions,
          'attempts_count': 0,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_publishTarget == 'PUBLIC' ? '🚀 Test Published to Feed!' : '🔒 Test added to Batch!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      setState(() => _isPublishing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publish error: $e')));
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
          // ⚡ Fast Smart Paper Button
          TextButton.icon(
            icon: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
            label: const Text('Smart Paste / OCR', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            onPressed: _openSmartPaperModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // Target Selector and Settings
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
                        onSelected: (_) => setState(() => _publishTarget = 'PUBLIC'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.lock_rounded, size: 16),
                        label: const Text('🔒 Private Batch', style: TextStyle(fontSize: 12)),
                        selected: _publishTarget == 'BATCH',
                        selectedColor: const Color(0xFF16A34A).withOpacity(0.18),
                        onSelected: (_) => setState(() => _publishTarget = 'BATCH'),
                      ),
                    ),
                  ],
                ),
                if (_publishTarget == 'BATCH') ...[
                  const SizedBox(height: 8),
                  if (_isLoadingBatches)
                    const LinearProgressIndicator()
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedBatchId,
                      decoration: const InputDecoration(labelText: 'Select Target Batch', border: OutlineInputBorder(), isDense: true),
                      items: _myBatches.map((b) => DropdownMenuItem<String>(value: b['id'].toString(), child: Text('${b['batch_name']} (${b['status']})'))).toList(),
                      onChanged: (val) => setState(() => _selectedBatchId = val),
                    ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Test Title / Name', isDense: true, border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Cards Review List with dedicated TextEditingControllers
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _questionCards.length,
              itemBuilder: (context, idx) {
                final q = _questionCards[idx];

                return Card(
                  key: ObjectKey(q),
                  margin: const EdgeInsets.only(bottom: 12),
                  color: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Question #${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB))),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _removeQuestion(idx)),
                          ],
                        ),
                        TextField(
                          controller: q.questionCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(hintText: 'Type question statement...', border: OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 10),
                        const Text('Options (Tap letter to set correct answer):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        ...List.generate(4, (oIdx) {
                          final isCorrect = q.answerIndex == oIdx;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => q.answerIndex = oIdx),
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isCorrect ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.3),
                                    child: Text(
                                      String.fromCharCode(65 + oIdx),
                                      style: TextStyle(fontSize: 12, color: isCorrect ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: q.optionCtrls[oIdx],
                                    decoration: InputDecoration(hintText: 'Option ${String.fromCharCode(65 + oIdx)}', isDense: true, border: const OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        TextField(
                          controller: q.explanationCtrl,
                          decoration: const InputDecoration(labelText: 'Explanation (Optional)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Bar Actions
          Container(
            padding: const EdgeInsets.all(12),
            color: cardBg,
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add 1 Card'),
                  onPressed: _addNewBlankQuestion,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 17, color: Color(0xFF2563EB)),
                  label: const Text('Preview 👁️'),
                  onPressed: _openStudentPreview,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _publishTarget == 'PUBLIC' ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isPublishing ? null : _publishMockTest,
                    child: _isPublishing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Publish ${_questionCards.length} Qs 🚀', style: const TextStyle(fontWeight: FontWeight.bold)),
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
