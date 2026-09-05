import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import '../widgets/latex_text.dart';
import '../widgets/cbt_widgets.dart';
import '../services/telegram_tracker.dart';
import '../services/user_stats_service.dart';
import '../services/cbt_progress_service.dart';
import '../utils/subtopic_engine.dart'; // 👈 Subtopic Engine Integration
import 'creator_profile_screen.dart';

class SectionalCbtScreen extends StatefulWidget {
  final String testTitle;
  final List<Question> questions;
  final String subFolder;
  final String? creatorHandle;
  final bool isBatchTest;
  final String? batchId;
  final dynamic mockId;

  const SectionalCbtScreen({
    super.key,
    required this.testTitle,
    required this.questions,
    required this.subFolder,
    this.creatorHandle,
    this.isBatchTest = false,
    this.batchId,
    this.mockId,
  });

  @override
  State<SectionalCbtScreen> createState() => _SectionalCbtScreenState();
}

class _SectionalCbtScreenState extends State<SectionalCbtScreen> {
  int _currentIndex = 0;
  int _totalTimeSeconds = 25 * 60;
  Timer? _examTimer;

  bool _isHindi = false;
  final Map<int, int> _userAnswers = {};
  final Set<int> _markedForReview = {};
  final Map<int, int> _questionTimers = {};
  int _currentQTime = 0;
  Timer? _qTimer;

  bool _isExamSubmitted = false;
  bool _isBookmarked = false;

  Map<String, dynamic>? _coachingInfo;

  @override
  void initState() {
    super.initState();
    _isHindi = widget.subFolder.contains('bssc') ||
        widget.subFolder.contains('bpsc') ||
        widget.subFolder.contains('bihar_si');

    _loadSavedProgressAndStart();
    _checkBookmarkStatus();
    _fetchCoachingDetails();
  }

  Future<void> _loadSavedProgressAndStart() async {
    final saved = await CbtProgressService.getTestStatus(widget.testTitle);
    if (saved != null && saved['status'] == 'IN_PROGRESS') {
      setState(() {
        _currentIndex = saved['currentIndex'] ?? 0;
        _totalTimeSeconds = saved['remainingSeconds'] ?? _totalTimeSeconds;
        if (saved['parsedUserAnswers'] != null) {
          _userAnswers.addAll(saved['parsedUserAnswers'] as Map<int, int>);
        }
      });
    }
    _startTimers();
  }

  Future<void> _fetchCoachingDetails() async {
    if (widget.isBatchTest || widget.creatorHandle == null || widget.creatorHandle == 'user') {
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('coachings')
          .select('*, batches(id, batch_name, batch_code)')
          .eq('owner_name', widget.creatorHandle!)
          .maybeSingle();

      if (mounted) {
        setState(() => _coachingInfo = res);
      }
    } catch (_) {}
  }

  void _startTimers() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalTimeSeconds > 0) {
        setState(() => _totalTimeSeconds--);
      } else {
        _submitExam();
      }
    });

    _qTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentQTime++;
      _questionTimers[_currentIndex] = (_questionTimers[_currentIndex] ?? 0) + 1;
    });
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _qTimer?.cancel();
    super.dispose();
  }

  void _selectOption(int optionIndex) {
    setState(() => _userAnswers[_currentIndex] = optionIndex);

    CbtProgressService.saveProgress(
      testId: widget.testTitle,
      currentIndex: _currentIndex,
      userAnswers: _userAnswers,
      remainingSeconds: _totalTimeSeconds,
      totalQuestions: widget.questions.length,
    );
  }

  void _toggleReview() {
    setState(() {
      if (_markedForReview.contains(_currentIndex)) {
        _markedForReview.remove(_currentIndex);
      } else {
        _markedForReview.add(_currentIndex);
      }
    });
  }

  void _checkBookmarkStatus() async {
    final savedList = await UserStatsService.getSavedQuestions();
    final currentQ = widget.questions[_currentIndex];
    String currentText = currentQ.getText(_isHindi);

    bool exists = savedList.any((item) {
      String qText = item['qe'] ?? item['qh'] ?? '';
      return qText == currentText || qText == currentQ.qe;
    });

    if (mounted) {
      setState(() => _isBookmarked = exists);
    }
  }

  void _toggleBookmarkQuestion() async {
    final currentQ = widget.questions[_currentIndex];
    Map<String, dynamic> qJson = {
      'qe': currentQ.qe,
      'qh': currentQ.qh,
      'se': currentQ.se,
      'sh': currentQ.sh,
      'oe': currentQ.oe,
      'oh': currentQ.oh,
      'options': currentQ.getOptions(_isHindi),
      'answerIndex': currentQ.answerIndex,
      'explanation': currentQ.explanation,
    };

    bool saved = await UserStatsService.toggleBookmark(qJson);

    if (mounted) {
      setState(() => _isBookmarked = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? '📌 Question Bookmarked!' : '🗑️ Bookmark Removed'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _submitExam() async {
    _examTimer?.cancel();
    _qTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _isExamSubmitted = true);

    int correctCount = 0;
    int wrongCount = 0;

    List<Map<String, dynamic>> detailedResponses = [];

    // 🔍 Subtopic Performance Tracking Engine Maps
    final Map<String, int> topicAttempted = {};
    final Map<String, int> topicCorrect = {};
    final Map<String, int> topicWrong = {};

    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final userAns = _userAnswers[i];
      final currentOptions = q.getOptions(_isHindi);
      final bool isCorrect = (userAns != null && userAns == q.answerIndex);

      final String selectedText = userAns != null ? currentOptions[userAns] : 'Skipped';
      final String correctText = currentOptions[q.answerIndex];

      // 🎯 Subtopic Extraction via Multi-Statement Engine
      final String detectedConcept = SubtopicEngine.extractSubtopic(
        chapterName: (q.chapter != null && q.chapter!.isNotEmpty)
            ? q.chapter!
            : widget.testTitle,
        qe: q.qe,
        qh: q.qh,
        se: q.se,
        sh: q.sh,
      );

      detailedResponses.add({
        'q_no': i + 1,
        'question': q.getText(_isHindi),
        'options': currentOptions,
        'selected_idx': userAns,
        'selected_option': selectedText,
        'correct_idx': q.answerIndex,
        'correct_option': correctText,
        'is_correct': isCorrect,
        'time_spent': _questionTimers[i] ?? 0,
        'explanation': q.explanation,
        'subtopic': detectedConcept,
      });

      if (userAns != null) {
        topicAttempted[detectedConcept] = (topicAttempted[detectedConcept] ?? 0) + 1;

        if (isCorrect) {
          correctCount++;
          topicCorrect[detectedConcept] = (topicCorrect[detectedConcept] ?? 0) + 1;
          await UserStatsService.recordQuestionAttempt(
            isCorrect: true,
            chapterName: widget.testTitle,
            chapterPath: widget.subFolder,
          );
        } else {
          wrongCount++;
          topicWrong[detectedConcept] = (topicWrong[detectedConcept] ?? 0) + 1;
          await UserStatsService.recordQuestionAttempt(
            isCorrect: false,
            chapterName: widget.testTitle,
            chapterPath: widget.subFolder,
            wrongQuestionJson: {
              'qe': q.qe,
              'qh': q.qh,
              'se': q.se,
              'sh': q.sh,
              'oe': q.oe,
              'oh': q.oh,
              'options': currentOptions,
              'answerIndex': q.answerIndex,
              'explanation': q.explanation,
            },
            userSelectedOption: currentOptions[userAns],
          );
        }
      }
    }

    // 📊 Granular Intelligence Resolution for Weak and Strong Areas
    String determinedStrong = 'Core Concepts Strong';
    String determinedWeak = 'All Clear (No Critical Traps)';

    int maxWrongs = 0;
    int maxCorrect = 0;

    topicAttempted.forEach((concept, total) {
      final wrong = topicWrong[concept] ?? 0;
      final correct = topicCorrect[concept] ?? 0;

      if (wrong > maxWrongs) {
        maxWrongs = wrong;
        final int acc = (total > 0) ? ((correct / total) * 100).round() : 0;
        determinedWeak = '$concept ($wrong Wrong, $acc% Acc)';
      }

      if (correct > maxCorrect && wrong == 0) {
        maxCorrect = correct;
        determinedStrong = '$concept (100% Acc)';
      }
    });

    await UserStatsService.recordMockTest(questionsAttempted: _userAnswers.length);

    double score = 0.0;
    if (widget.subFolder.contains('bssc')) {
      score = (correctCount * 4) - (wrongCount * 1.0);
    } else if (widget.subFolder.contains('bpsc')) {
      score = (correctCount * 1.0) - (wrongCount * 0.33);
    } else if (widget.subFolder.contains('bihar_si')) {
      score = (correctCount * 2.0) - (wrongCount * 0.40);
    } else {
      score = (correctCount * 1.0) - (wrongCount * 0.25);
    }

    await CbtProgressService.markCompleted(
      testId: widget.testTitle,
      score: score,
      correct: correctCount,
      wrong: wrongCount,
      total: widget.questions.length,
    );

    final client = Supabase.instance.client;

    // 1️⃣ UPDATE ATTEMPTS COUNT
    if (widget.mockId != null) {
      try {
        final String targetTable = widget.isBatchTest ? 'batch_tests' : 'creator_mocks';
        final targetId = widget.mockId.toString();

        final current = await client
            .from(targetTable)
            .select('attempts_count')
            .eq('id', targetId)
            .maybeSingle();

        int currentCount = 0;
        if (current != null && current['attempts_count'] != null) {
          currentCount = int.tryParse(current['attempts_count'].toString()) ?? 0;
        }

        await client
            .from(targetTable)
            .update({'attempts_count': currentCount + 1})
            .eq('id', targetId);

        debugPrint("✅ [CBT_DEBUG] Attempts updated in $targetTable for ID: $targetId");
      } catch (e) {
        debugPrint("❌ [CBT_DEBUG] Error updating attempts_count: $e");
      }
    }

    // 2️⃣ SYNC BATCH SUBMISSIONS WITH SUBTOPIC INTELLIGENCE
    debugPrint("==================================================");
    debugPrint("🔍 [CBT_DEBUG] SUBMIT TRIGGERED");
    debugPrint("🔍 [CBT_DEBUG] isBatchTest: ${widget.isBatchTest}");
    debugPrint("🔍 [CBT_DEBUG] batchId: '${widget.batchId}'");
    debugPrint("🔍 [CBT_DEBUG] mockId: '${widget.mockId}'");

    if (widget.isBatchTest && widget.batchId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawName = prefs.getString('custom_aspirant_name') ?? 'Enrolled Student';
        final rawContact = prefs.getString('student_contact_id') ?? '';

        final studentIdentifier = (rawContact.isNotEmpty && rawContact != 'N/A')
            ? '$rawName (Roll/Ph: $rawContact)'
            : rawName;

        final double accuracyPct = _userAnswers.isNotEmpty
            ? (correctCount / _userAnswers.length) * 100
            : 0.0;

        final Map<String, dynamic> submissionData = {
          'batch_id': widget.batchId.toString().trim(),
          'test_id': widget.mockId?.toString().trim(),
          'student_name': rawName,
          'student_identifier': studentIdentifier,
          'score': score,
          'accuracy': accuracyPct.round(),
          'accuracy_percent': accuracyPct.round(),
          'attempted_count': _userAnswers.length,
          'correct_count': correctCount,
          'wrong_count': wrongCount,
          'total_questions': widget.questions.length,
          'weak_subject': determinedWeak,     // 👈 Subtopic Intelligence Output
          'strong_subject': determinedStrong, // 👈 Subtopic Intelligence Output
          'detailed_responses': detailedResponses,
        };

        debugPrint("🚀 [CBT_DEBUG] Sending Payload to 'batch_submissions':");
        debugPrint("    weak_subject: $determinedWeak");
        debugPrint("    strong_subject: $determinedStrong");

        final insertRes = await client
            .from('batch_submissions')
            .insert(submissionData)
            .select();

        debugPrint("🎉 [CBT_DEBUG] SUPABASE INSERT SUCCESSFUL! Response: $insertRes");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Mock Result Synced to Classroom Dashboard!'),
              backgroundColor: Color(0xFF16A34A),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e, stack) {
        debugPrint("❌ [CBT_DEBUG] CRITICAL SUPABASE INSERT FAILED: $e");
        debugPrint("❌ [CBT_DEBUG] StackTrace: $stack");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ DB Submission Failed: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      debugPrint("⚠️ [CBT_DEBUG] SKIPPED: isBatchTest is false OR batchId is null!");
    }
    debugPrint("==================================================");

    TelegramTracker.recordTestCompletion(
      widget.testTitle,
      "Sahi: $correctCount, Galat: $wrongCount / Total: ${widget.questions.length}",
    );
  }

  String _formatTime(int totalSec) {
    int m = totalSec ~/ 60;
    int s = totalSec % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _openBatchCodeDialog(String coachingName) async {
    final prefs = await SharedPreferences.getInstance();
    final existingName = prefs.getString('custom_aspirant_name') ?? '';
    final existingContact = prefs.getString('student_contact_id') ?? '';

    final nameCtrl = TextEditingController(text: existingName);
    final contactCtrl = TextEditingController(text: existingContact != 'N/A' ? existingContact : '');
    final codeCtrl = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Join Classroom Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter details shared by $coachingName:',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Student Full Name (e.g. Suresh Kumar)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(
                  labelText: 'Roll No. / Mobile No.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'e.g. 111',
                  labelText: 'Secret Batch Code',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () async {
              final enteredName = nameCtrl.text.trim();
              final enteredContact = contactCtrl.text.trim();
              final enteredCode = codeCtrl.text.trim().toUpperCase();

              if (enteredName.isEmpty || enteredCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Batch Code are required!')),
                );
                return;
              }

              await prefs.setString('custom_aspirant_name', enteredName);
              await prefs.setString('student_contact_id', enteredContact.isNotEmpty ? enteredContact : 'N/A');
              await prefs.setString('user_enrolled_batch_code', enteredCode);

              if (ctx.mounted) Navigator.pop(ctx);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🎉 Verified! Enrolled $enteredName with code $enteredCode'), backgroundColor: const Color(0xFF16A34A)),
                );
              }
            },
            child: const Text('Join Batch 🚀'),
          ),
        ],
      ),
    );
  }

  void _callOrWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (_isExamSubmitted) return _buildResultReportScreen();

    final currentQ = widget.questions[_currentIndex];
    final String qText = currentQ.getText(_isHindi);
    final List<String> currentOptions = currentQ.getOptions(_isHindi);
    final List<String>? statements = _isHindi ? currentQ.sh : currentQ.se;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(widget.testTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(6)),
            child: Text(_formatTime(_totalTimeSeconds), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _isHindi = !_isHindi),
            child: Text(_isHindi ? "EN 🇬🇧" : "HI 🇮🇳", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => CbtPaletteDrawer(
                totalQuestions: widget.questions.length,
                currentIndex: _currentIndex,
                userAnswers: _userAnswers,
                markedForReview: _markedForReview,
                onSelectQuestion: (idx) {
                  setState(() => _currentIndex = idx);
                  _checkBookmarkStatus();
                },
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("QUESTION ${_currentIndex + 1} OF ${widget.questions.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                        color: _isBookmarked ? const Color(0xFF2563EB) : Colors.grey,
                      ),
                      onPressed: _toggleBookmarkQuestion,
                      tooltip: "Bookmark Question",
                    ),
                    IconButton(
                      icon: Icon(_markedForReview.contains(_currentIndex) ? Icons.rate_review : Icons.rate_review_outlined, color: _markedForReview.contains(_currentIndex) ? const Color(0xFF8E44AD) : Colors.grey),
                      onPressed: _toggleReview,
                      tooltip: "Mark for Review",
                    ),
                  ],
                )
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LatexText("Q${_currentIndex + 1}. $qText", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.4)),
                  const SizedBox(height: 12),

                  if (statements != null && statements.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: statements.asMap().entries.map((entry) {
                        int index = entry.key + 1;
                        String stmtText = entry.value.trim().replaceFirst(RegExp(r'^(\(\d+\)|\d+\.)\s*'), '');

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Color(0xFF2575FC), width: 4))),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF2575FC), borderRadius: BorderRadius.circular(4)), child: Text("($index)", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 8),
                              Expanded(child: LatexText(stmtText, style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), height: 1.4))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  ...List.generate(currentOptions.length, (optIdx) {
                    final isSelected = _userAnswers[_currentIndex] == optIdx;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        onTap: () => _selectOption(optIdx),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            border: Border.all(color: isSelected ? const Color(0xFF2575FC) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: isSelected ? const Color(0xFF2575FC) : Colors.grey.shade200,
                                child: Text(String.fromCharCode(65 + optIdx), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: LatexText(currentOptions[optIdx], style: TextStyle(fontSize: 13.5, color: Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
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

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentIndex > 0
                      ? () {
                          setState(() => _currentIndex--);
                          _checkBookmarkStatus();
                        }
                      : null,
                  child: const Text("← PREV"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573), foregroundColor: Colors.white),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Submit Mock Test?"),
                      content: Text("Attempted: ${_userAnswers.length} / ${widget.questions.length}"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                        ElevatedButton(onPressed: () { Navigator.pop(ctx); _submitExam(); }, child: const Text("Submit 🚀"))
                      ],
                    ),
                  ),
                  child: const Text("SUBMIT TEST"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2575FC), foregroundColor: Colors.white),
                  onPressed: () {
                    if (_currentIndex < widget.questions.length - 1) {
                      setState(() => _currentIndex++);
                      _checkBookmarkStatus();
                    } else {
                      _submitExam();
                    }
                  },
                  child: Text(_currentIndex < widget.questions.length - 1 ? "SAVE & NEXT →" : "FINISH"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultReportScreen() {
    int total = widget.questions.length;
    int correct = 0;
    int wrong = 0;

    _userAnswers.forEach((qIdx, userAns) {
      if (userAns == widget.questions[qIdx].answerIndex) { correct++; } else { wrong++; }
    });

    int attempted = _userAnswers.length;
    int skipped = total - attempted;

    double score = 0.0;
    double cutoffTarget = 22.00;
    String examName = "SSC / Central Exams";

    if (widget.subFolder.contains('bssc')) {
      score = (correct * 4) - (wrong * 1.0);
      cutoffTarget = 88.00;
      examName = "BSSC Graduate Level";
    } else if (widget.subFolder.contains('bpsc')) {
      score = (correct * 1.0) - (wrong * 0.33);
      cutoffTarget = 21.00;
      examName = "BPSC Prelims";
    } else if (widget.subFolder.contains('bihar_si')) {
      score = (correct * 2.0) - (wrong * 0.40);
      cutoffTarget = 130.00;
      examName = "Bihar SI Prelims";
    } else {
      score = (correct * 1.0) - (wrong * 0.25);
      cutoffTarget = 22.00;
    }

    bool isCleared = score >= cutoffTarget;

    final coachingName = _coachingInfo?['name'] ?? 'Classroom Academy';
    final district = _coachingInfo?['district'] ?? _coachingInfo?['city'] ?? 'Bihar';
    final helpline = _coachingInfo?['contact_number'];
    final ownerHandle = _coachingInfo?['owner_name'] ?? widget.creatorHandle;

    return Scaffold(
      appBar: AppBar(title: const Text("Performance Summary")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(isCleared ? "CUTOFF CLEARED!" : "FAILED TO CLEAR CUTOFF", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCleared ? Colors.green : Colors.red)),
            const SizedBox(height: 16),

            CbtPieChartCard(correct: correct, wrong: wrong, skipped: skipped),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _scoreRow("Total Questions", "$total"),
                    _scoreRow("Attempted", "$attempted"),
                    _scoreRow("Correct Answers", "$correct", color: Colors.green),
                    _scoreRow("Wrong Answers", "$wrong", color: Colors.red),
                    _scoreRow("Skipped", "$skipped"),

                    if (wrong > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Text("🎯", style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Galat questions Vault me save ho gaye hain! Deep AI Trap Analysis ke liye Profile ➔ Wrong Question Vault dekhein.",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.bold,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 20),
                    _scoreRow("Exam Cutoff", "$cutoffTarget Marks ($examName)"),
                    _scoreRow("Your Final Score", score.toStringAsFixed(2), color: const Color(0xFF2575FC), isBold: true),
                  ],
                ),
              ),
            ),

            if (!widget.isBatchTest && _coachingInfo != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'OFFICIAL CLASSROOM BATCH',
                            style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Spacer(),
                        if (ownerHandle != null)
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreatorProfileScreen(
                                    creatorHandle: ownerHandle,
                                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                  ),
                                ),
                              );
                            },
                            child: const Text('View Center →', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Liked this Mock Drill? 🚀',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Enroll in $coachingName ($district) classroom batch for 20+ Full CBT Tests, Rank Analysis & Complete Handouts.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.vpn_key_rounded, size: 14),
                            label: const Text('Have Code? Unlock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _openBatchCodeDialog(coachingName),
                          ),
                        ),
                        if (helpline != null && helpline.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                              label: const Text('Contact Helpline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _callOrWhatsApp(helpline),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text("Detailed Review & Explanations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),

            ...List.generate(widget.questions.length, (i) {
              final q = widget.questions[i];
              final userAns = _userAnswers[i];
              final isCorrect = userAns == q.answerIndex;
              final timeSpent = _questionTimers[i] ?? 0;
              final options = q.getOptions(_isHindi);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Q${i + 1}. ${q.getText(_isHindi)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text("Your Answer: ${userAns != null ? options[userAns] : 'Skipped'}", style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("Correct Answer: ${options[q.answerIndex]}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text("⏱️ Time Spent: ${timeSpent}s", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LatexText("Explanation: ${q.explanation.isNotEmpty ? q.explanation : 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 10),

                            if (!isCorrect && userAns != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Row(
                                  children: [
                                    Text("💡", style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "AI Analysis ke liye apne Profile ke 'Wrong Question Vault' par jayein.",
                                        style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            WikiContributionBox(
                              subFolder: widget.subFolder,
                              qIndex: i,
                              questionSnippet: q.getText(_isHindi),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _scoreRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
