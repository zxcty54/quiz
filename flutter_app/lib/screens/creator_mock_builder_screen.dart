import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_explainer_service.dart';
import '../services/ai_rate_limiter_service.dart';
import '../widgets/math_text.dart';

class QuestionCardData {
  final TextEditingController questionCtrl;
  final List<TextEditingController> optionCtrls;
  final TextEditingController explanationCtrl;
  int answerIndex;
  String? questionImageUrl;
  String? explanationImageUrl;

  QuestionCardData({
    String question = '',
    List<String>? options,
    this.answerIndex = 0,
    String explanation = '',
    this.questionImageUrl,
    this.explanationImageUrl,
  })  : questionCtrl = TextEditingController(text: question),
        optionCtrls = List.generate(
          4,
          (i) => TextEditingController(
              text: (options != null && options.length > i) ? options[i] : ''),
        ),
        explanationCtrl = TextEditingController(text: explanation);

  Map<String, dynamic> toJson() => {
        'question': questionCtrl.text.trim(),
        'options': optionCtrls.map((c) => c.text.trim()).toList(),
        'answer': answerIndex,
        'explanation': explanationCtrl.text.trim(),
        'question_image_url': questionImageUrl,
        'explanation_image_url': explanationImageUrl,
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
  final ScrollController _cardScrollController = ScrollController();
  int _activeJumpIndex = 0;

  @override
  void initState() {
    super.initState();
    _addNewBlankQuestion();
    _fetchCreatorBatches();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _cardScrollController.dispose();
    for (var q in _questionCards) {
      q.dispose();
    }
    super.dispose();
  }

  void _jumpToCard(int index) {
    setState(() => _activeJumpIndex = index);
    HapticFeedback.selectionClick();
    if (_cardScrollController.hasClients) {
      // Estimated card height + margins
      final targetOffset = (index * 420.0).clamp(
        0.0,
        _cardScrollController.position.maxScrollExtent,
      );
      _cardScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
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
    } catch (e) {
      debugPrint('[DEBUG] Batch fetch error: $e');
      _authorDisplayName = widget.creatorHandle;
      if (mounted) setState(() => _isLoadingBatches = false);
    }
  }

  void _addNewBlankQuestion() {
    setState(() {
      _questionCards.add(QuestionCardData());
      _activeJumpIndex = _questionCards.length - 1;
    });
  }

  void _removeQuestion(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _questionCards[index].dispose();
      _questionCards.removeAt(index);
      if (_questionCards.isEmpty) {
        _addNewBlankQuestion();
      } else if (_activeJumpIndex >= _questionCards.length) {
        _activeJumpIndex = _questionCards.length - 1;
      }
    });
  }

  String? _validateQuestions() {
    if (_questionCards.isEmpty) return 'Kam se kam 1 question hona zaroori hai.';

    for (int i = 0; i < _questionCards.length; i++) {
      final q = _questionCards[i];
      if (q.questionCtrl.text.trim().isEmpty && (q.questionImageUrl == null || q.questionImageUrl!.isEmpty)) {
        return '⚠️ Question #${i + 1} empty hai. Text likhein ya image attach karein.';
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

  // 📷 Direct Gallery / Camera Upload to Supabase Storage
  Future<String?> _uploadAttachmentImage(ImageSource source, String folder) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last;
      final fileName = '${folder}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$folder/$fileName';

      await Supabase.instance.client.storage
          .from('mock_attachments')
          .uploadBinary(filePath, bytes);

      final publicUrl = Supabase.instance.client.storage
          .from('mock_attachments')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e (Ensure "mock_attachments" bucket exists)'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _showImagePickerChoice({
    required Function(String url) onUploaded,
    required String folder,
  }) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF16A34A)),
              title: const Text('Gallery se Select Karein (Direct)'),
              onTap: () async {
                Navigator.pop(bCtx);
                final url = await _uploadAttachmentImage(ImageSource.gallery, folder);
                if (url != null) onUploaded(url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB)),
              title: const Text('Camera se Photo Kheechein'),
              onTap: () async {
                Navigator.pop(bCtx);
                final url = await _uploadAttachmentImage(ImageSource.camera, folder);
                if (url != null) onUploaded(url);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDebugPopup(String title, String details) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            details,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<String?> _scanTextFromCameraOrGallery(ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: source, imageQuality: 90);
      if (photo == null) return null;

      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      return recognizedText.text;
    } catch (e) {
      _showDebugPopup('OCR Exception', e.toString());
      return null;
    }
  }

  // ⚡ Block-Slicing Parser
  List<QuestionCardData> _parseRawCoachingInput(String rawText) {
    final List<QuestionCardData> result = [];
    if (rawText.trim().isEmpty) return result;

    final cleanText = rawText
        .replaceAll('\uFEFF', '')
        .replaceAll('\u200B', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    final qBoundaryRegex = RegExp(
      r'(?:^|\n)\s*(?:Q\s*\.?\s*\d+|प्रश्न\s*\d*|\d+[\.\)]|\(\d+\))[\s\.:\-_]*',
      caseSensitive: false,
    );

    final matches = qBoundaryRegex.allMatches(cleanText).toList();
    List<String> rawBlocks = [];

    if (matches.isNotEmpty) {
      for (int i = 0; i < matches.length; i++) {
        final start = matches[i].end;
        final end = (i + 1 < matches.length) ? matches[i + 1].start : cleanText.length;
        rawBlocks.add(cleanText.substring(start, end).trim());
      }
    } else {
      rawBlocks = cleanText
          .split(RegExp(r'\n\s*\n'))
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .toList();
    }

    final optARegex = RegExp(r'(?:^|\n)\s*(?:\([Aa1]\)|[Aa1][\.\)])\s*');
    final optBRegex = RegExp(r'(?:^|\n)\s*(?:\([Bb2]\)|[Bb2][\.\)])\s*');
    final optCRegex = RegExp(r'(?:^|\n)\s*(?:\([Cc3]\)|[Cc3][\.\)])\s*');
    final optDRegex = RegExp(r'(?:^|\n)\s*(?:\([Dd4]\)|[Dd4][\.\)])\s*');
    final ansRegex = RegExp(r'(?:^|\n)\s*(?:Ans|Answer|उत्तर|सही उत्तर)[\s\.:\-_]*([A-Da-d1-4])', caseSensitive: false);
    final expRegex = RegExp(r'(?:^|\n)\s*(?:Exp|Explanation|व्याख्या|हल)[\s\.:\-_]*', caseSensitive: false);

    for (final block in rawBlocks) {
      final mA = optARegex.firstMatch(block);
      final mB = optBRegex.firstMatch(block);
      final mC = optCRegex.firstMatch(block);
      final mD = optDRegex.firstMatch(block);
      final mAns = ansRegex.firstMatch(block);
      final mExp = expRegex.firstMatch(block);

      if (mA == null) continue;

      final qText = block.substring(0, mA.start).replaceAll('\n', ' ').trim();
      final optA = (mB != null) ? block.substring(mA.end, mB.start).replaceAll('\n', ' ').trim() : '';
      final optB = (mC != null) ? block.substring(mB!.end, mC.start).replaceAll('\n', ' ').trim() : '';
      final optC = (mD != null) ? block.substring(mC!.end, mD.start).replaceAll('\n', ' ').trim() : '';

      int dEnd = block.length;
      if (mAns != null && mAns.start > (mD?.end ?? 0)) dEnd = mAns.start;
      else if (mExp != null && mExp.start > (mD?.end ?? 0)) dEnd = mExp.start;

      final optD = (mD != null) ? block.substring(mD.end, dEnd).replaceAll('\n', ' ').trim() : '';

      int ansIdx = 0;
      if (mAns != null) {
        final key = mAns.group(1)!.toUpperCase();
        if (key == 'A' || key == '1') ansIdx = 0;
        if (key == 'B' || key == '2') ansIdx = 1;
        if (key == 'C' || key == '3') ansIdx = 2;
        if (key == 'D' || key == '4') ansIdx = 3;
      }

      String expText = '';
      if (mExp != null) {
        expText = block.substring(mExp.end).trim();
      }

      if (qText.isNotEmpty) {
        result.add(QuestionCardData(
          question: qText,
          options: [
            optA.isNotEmpty ? optA : 'Option A',
            optB.isNotEmpty ? optB : 'Option B',
            optC.isNotEmpty ? optC : 'Option C',
            optD.isNotEmpty ? optD : 'Option D',
          ],
          answerIndex: ansIdx,
          explanation: expText,
        ));
      }
    }

    return result;
  }

  void _openSmartPaperModal() {
    final rawTextCtrl = TextEditingController();
    bool isAiLoading = false;

    Future<void> triggerAiProcessing(BuildContext modalCtx, void Function(void Function()) setModalState) async {
      final text = rawTextCtrl.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pehle text paste karein!')),
        );
        return;
      }

      setModalState(() => isAiLoading = true);

      try {
        final eligibility = await AiRateLimiterService.checkEligibility();
        if (eligibility['allowed'] == false) {
          setModalState(() => isAiLoading = false);
          _showDebugPopup('AI Quota Blocked', eligibility['message'] ?? 'Daily limit reach ho chuki hai.');
          return;
        }

        final List<Map<String, dynamic>> aiResult =
            await AiExplainerService.parseBulkQuestionsWithAi(text);

        if (aiResult.isNotEmpty) {
          await AiRateLimiterService.recordSuccess();

          final converted = aiResult.map((m) {
            final opts = (m['options'] as List? ?? []).map((e) => e.toString()).toList();
            while (opts.length < 4) {
              opts.add('Option ${String.fromCharCode(65 + opts.length)}');
            }
            return QuestionCardData(
              question: m['question']?.toString() ?? '',
              options: opts.sublist(0, 4),
              answerIndex: (m['answer'] is int && m['answer'] >= 0 && m['answer'] < 4)
                  ? m['answer']
                  : 0,
              explanation: m['explanation']?.toString() ?? '',
            );
          }).toList();

          setState(() {
            if (_questionCards.length == 1 && _questionCards[0].questionCtrl.text.isEmpty) {
              _questionCards.clear();
            }
            _questionCards.addAll(converted);
            _activeJumpIndex = _questionCards.length - 1;
          });

          if (context.mounted) {
            Navigator.pop(modalCtx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✨ AI added ${converted.length} Questions successfully!'), backgroundColor: const Color(0xFF16A34A)),
            );
          }
        } else {
          setModalState(() => isAiLoading = false);
          _showDebugPopup('AI Empty Output', 'AI Service ne 0 questions return kiye.');
        }
      } catch (err, stack) {
        setModalState(() => isAiLoading = false);
        _showDebugPopup('AI Execution Error', 'Error: $err\n\nStack:\n$stack');
      }
    }

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

                // 💡 Context helper for Math/Numericals
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.09),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Handwritten notes, Maths formulas (LaTeX) ya diagrams ke liye "AI Auto-Clean & Fix" use karein.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: rawTextCtrl,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    hintText: 'Questions text paste karein...\n\nQ1. Example question\nA) Opt 1\nB) Opt 2\nAns: B',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. FAST LOCAL CONVERT (With Math Warning)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('Instant Auto Convert (Free & Fast)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: isAiLoading
                        ? null
                        : () async {
                            final text = rawTextCtrl.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pehle text paste karein!')),
                              );
                              return;
                            }

                            // Math Symbols Detection Trigger
                            final hasMathSymbols = RegExp(r'[\^√∫πθ±÷×λ∑]|(\b\d+/\d+\b)|[a-zA-Z]\^[0-9]').hasMatch(text);
                            if (hasMathSymbols) {
                              final useAi = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.functions_rounded, color: Color(0xFF8B5CF6)),
                                      SizedBox(width: 8),
                                      Text('Maths Symbols Detected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: const Text(
                                    'Is question text me mathematical equations/symbols detect hue hain.\n\nLocal parser formulas ko tod sakta hai. Kya aap isse "AI Auto-Clean (LaTeX)" se parse karna chahte hain?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, false),
                                      child: const Text('Continue Normal (Regex)'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('Use AI (Recommended)', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );

                              if (useAi == true) {
                                triggerAiProcessing(ctx, setModalState);
                                return;
                              }
                            }

                            final localParsed = _parseRawCoachingInput(text);

                            if (localParsed.isNotEmpty) {
                              setState(() {
                                if (_questionCards.length == 1 && _questionCards[0].questionCtrl.text.isEmpty) {
                                  _questionCards.clear();
                                }
                                _questionCards.addAll(localParsed);
                                _activeJumpIndex = _questionCards.length - 1;
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Added ${localParsed.length} Questions successfully!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            } else {
                              _showDebugPopup(
                                'Local Parser Zero Output',
                                'Text mila: ${text.length} characters.\n\nOption A) B) C) D) detect nahi ho paya. "AI Auto-Clean" try karein.',
                              );
                            }
                          },
                  ),
                ),
                const SizedBox(height: 8),

                // 2. AI FALLBACK
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: isAiLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)))
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(isAiLoading ? 'AI Processing Questions...' : 'AI Auto-Clean & Fix 🪄'),
                    onPressed: isAiLoading ? null : () => triggerAiProcessing(ctx, setModalState),
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

  // 👁️ Fully Fixed Live Student Preview with High-Contrast Text & Step-by-Step Navigation
  void _openStudentPreview() {
    final validationError = _validateQuestions();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red.shade800),
      );
      return;
    }

    int previewCurrentIndex = 0;
    int? selectedOption;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPreviewState) {
          final totalCount = _questionCards.length;
          final q = _questionCards[previewCurrentIndex];
          final isDark = widget.isDarkMode;

          final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final cardFillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
          final borderColor = isDark ? Colors.white24 : Colors.grey.shade300;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.remove_red_eye_outlined, size: 15, color: Color(0xFF2563EB)),
                          SizedBox(width: 5),
                          Text(
                            'CBT PREVIEW MODE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: primaryTextColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Mock Test',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Q ${previewCurrentIndex + 1} of $totalCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardFillColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MathFormattedText(
                                text: q.questionCtrl.text,
                                textStyle: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                ),
                              ),
                              if (q.questionImageUrl != null && q.questionImageUrl!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    q.questionImageUrl!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (c, child, p) => p == null ? child : const LinearProgressIndicator(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        ...List.generate(4, (oIdx) {
                          final isSelected = selectedOption == oIdx;
                          final letter = String.fromCharCode(65 + oIdx);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () => setPreviewState(() => selectedOption = oIdx),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB).withOpacity(0.12)
                                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF2563EB) : borderColor,
                                    width: isSelected ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isSelected
                                          ? const Color(0xFF2563EB)
                                          : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                      child: Text(
                                        letter,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark ? Colors.white : Colors.black87),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: MathFormattedText(
                                        text: q.optionCtrls[oIdx].text,
                                        textStyle: TextStyle(
                                          fontSize: 14,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        if (q.explanationCtrl.text.isNotEmpty || q.explanationImageUrl != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '💡 Solution / Explanation:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF16A34A)),
                                ),
                                const SizedBox(height: 6),
                                if (q.explanationCtrl.text.isNotEmpty)
                                  MathFormattedText(
                                    text: q.explanationCtrl.text,
                                    textStyle: TextStyle(fontSize: 13, color: primaryTextColor),
                                  ),
                                if (q.explanationImageUrl != null && q.explanationImageUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      q.explanationImageUrl!,
                                      height: 140,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    if (previewCurrentIndex > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Previous'),
                          onPressed: () => setPreviewState(() {
                            previewCurrentIndex--;
                            selectedOption = null;
                          }),
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
                          if (previewCurrentIndex < totalCount - 1) {
                            setPreviewState(() {
                              previewCurrentIndex++;
                              selectedOption = null;
                            });
                          } else {
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text(
                          previewCurrentIndex < totalCount - 1
                              ? 'Next (${previewCurrentIndex + 2}/$totalCount) →'
                              : 'Done Previewing ✓',
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
      final formattedQuestions = _questionCards.map((q) {
        final data = q.toJson();
        data['subject'] = _selectedSubject;
        return data;
      }).toList();

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
      _showDebugPopup('Publish Error', e.toString());
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
            icon: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
            label: const Text('Smart Paste / OCR', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            onPressed: _openSmartPaperModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🏷️ Top Config Bar
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

          // ⚡ JUMP TO QUESTION BAR
          Container(
            height: 46,
            color: cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                const Text('Jump:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _questionCards.length,
                    itemBuilder: (ctx, i) {
                      final isActive = _activeJumpIndex == i;
                      final hasImg = _questionCards[i].questionImageUrl != null || _questionCards[i].explanationImageUrl != null;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => _jumpToCard(i),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isActive ? const Color(0xFF2563EB) : (hasImg ? const Color(0xFF16A34A) : Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Q${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                if (hasImg) ...[
                                  const SizedBox(width: 3),
                                  Icon(Icons.image, size: 11, color: isActive ? Colors.white : const Color(0xFF16A34A)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 📝 EDITABLE QUESTION CARDS LIST
          Expanded(
            child: ListView.builder(
              controller: _cardScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _questionCards.length,
              itemBuilder: (context, idx) {
                final q = _questionCards[idx];

                return Card(
                  key: ObjectKey(q),
                  margin: const EdgeInsets.only(bottom: 14),
                  color: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question #${idx + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB)),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Attach Question Diagram',
                                  icon: Icon(
                                    q.questionImageUrl == null ? Icons.add_photo_alternate_outlined : Icons.image_rounded,
                                    color: q.questionImageUrl == null ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                                    size: 20,
                                  ),
                                  onPressed: () => _showImagePickerChoice(
                                    folder: 'questions',
                                    onUploaded: (url) => setState(() => q.questionImageUrl = url),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  onPressed: () => _removeQuestion(idx),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Question Statement
                        TextField(
                          controller: q.questionCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Type question statement...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),

                        // Question Attached Image Display
                        if (q.questionImageUrl != null && q.questionImageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  q.questionImageUrl!,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              IconButton(
                                icon: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.redAccent,
                                  child: Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                                onPressed: () => setState(() => q.questionImageUrl = null),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 10),
                        const Text('Options (Tap letter to set correct answer):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),

                        // Options A, B, C, D
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
                                  child: TextField(
                                    controller: q.optionCtrls[oIdx],
                                    decoration: InputDecoration(
                                      hintText: 'Option ${String.fromCharCode(65 + oIdx)}',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 4),

                        // Explanation input & image trigger
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: q.explanationCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Explanation / Solution (Optional)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Attach Explanation Diagram',
                              icon: Icon(
                                q.explanationImageUrl == null ? Icons.photo_size_select_actual_outlined : Icons.check_circle,
                                color: q.explanationImageUrl == null ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                                size: 21,
                              ),
                              onPressed: () => _showImagePickerChoice(
                                folder: 'explanations',
                                onUploaded: (url) => setState(() => q.explanationImageUrl = url),
                              ),
                            ),
                          ],
                        ),

                        // Explanation Image Display
                        if (q.explanationImageUrl != null && q.explanationImageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  q.explanationImageUrl!,
                                  height: 55,
                                  width: 75,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                label: const Text('Remove Solution Image', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                onPressed: () => setState(() => q.explanationImageUrl = null),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 🛠️ 2-Tier Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add 1 Card'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _addNewBlankQuestion,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 17, color: Color(0xFF2563EB)),
                          label: const Text('Preview 👁️', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _openStudentPreview,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _publishTarget == 'PUBLIC' ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isPublishing ? null : _publishMockTest,
                      child: _isPublishing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_publishTarget == 'PUBLIC' ? Icons.public_rounded : Icons.lock_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _publishTarget == 'PUBLIC'
                                      ? 'Publish Test to Public Feed (${_questionCards.length} Qs) 🚀'
                                      : 'Save & Publish to Batch (${_questionCards.length} Qs) 🔒',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
