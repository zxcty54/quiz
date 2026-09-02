import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import '../services/cbt_progress_service.dart';
import 'sectional_cbt_screen.dart';

class BatchClassroomScreen extends StatefulWidget {
  final Map<String, dynamic> batchData;
  final bool isDarkMode;

  const BatchClassroomScreen({
    super.key,
    required this.batchData,
    required this.isDarkMode,
  });

  @override
  State<BatchClassroomScreen> createState() => _BatchClassroomScreenState();
}

class _BatchClassroomScreenState extends State<BatchClassroomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _cbtTests = [];
  bool _isLoading = true;

  // 🔄 Progress tracking cache per test
  final Map<String, Map<String, dynamic>> _progressCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBatchTests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBatchTests() async {
    try {
      final res = await Supabase.instance.client
          .from('batch_tests')
          .select()
          .eq('batch_id', widget.batchData['id'])
          .order('created_at', ascending: false);

      final tests = res ?? [];

      // Load local progress for each test
      for (var test in tests) {
        final testId = (test['id'] ?? test['test_title']).toString();
        final progress = await CbtProgressService.getTestStatus(testId);
        if (progress != null) {
          _progressCache[testId] = progress;
        }
      }

      if (mounted) {
        setState(() {
          _cbtTests = tests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startBatchTest(Map<String, dynamic> test) {
    HapticFeedback.lightImpact();
    final dynamic rawQuestions = test['questions_json'];
    List<Question> parsedQuestions = [];

    if (rawQuestions is List) {
      for (var item in rawQuestions) {
        if (item is Map) {
          parsedQuestions.add(Question.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    if (parsedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Is test me koi questions uplabdh nahi hain.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: test['test_title'] ?? 'Batch CBT Test',
          questions: parsedQuestions,
          subFolder: (test['subject'] ?? 'General').toString().toLowerCase(),
          isBatchTest: true, // 👈 Classroom test: promotion card hide rahega
          batchId: widget.batchData['id']?.toString(), // 👈 Teacher dashboard sync
          mockId: test['id'], // 👈 Attempts count update karne ke liye ZAROORI hai
        ),
      ),
    ).then((_) {
      // Test submit ya exit hone par status aur progress bar refresh karein
      _loadBatchTests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final batchName = widget.batchData['batch_name'] ?? 'Classroom Batch';
    final batchCode = widget.batchData['batch_code'] ?? '';

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(batchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('CODE: $batchCode • Private Classroom', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          indicatorColor: const Color(0xFF2563EB),
          tabs: [
            Tab(text: 'CBT Mocks (${_cbtTests.length})'),
            const Tab(text: 'Class Handouts & PDFs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. CBT Mocks List with Smart Progress Lifecycle
                _cbtTests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text('No CBT mock tests added to this batch yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _cbtTests.length,
                        itemBuilder: (ctx, idx) {
                          final t = _cbtTests[idx];
                          final testId = (t['id'] ?? t['test_title']).toString();
                          final progress = _progressCache[testId];

                          final String status = progress?['status'] ?? 'NOT_STARTED';
                          final bool isCompleted = status == 'COMPLETED';
                          final bool isInProgress = status == 'IN_PROGRESS';

                          final int totalQs = t['total_questions'] ?? ((t['questions_json'] as List?)?.length ?? 15);
                          final int duration = t['duration_mins'] ?? 15;
                          final int answered = (progress?['userAnswers'] as Map? ?? {}).length;
                          final double progressFraction = totalQs > 0 ? (answered / totalQs) : 0.0;

                          return Card(
                            color: cardBg,
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isCompleted
                                    ? const Color(0xFF16A34A).withOpacity(0.3)
                                    : (isInProgress ? Colors.amber.withOpacity(0.4) : Colors.grey.withOpacity(0.15)),
                                width: isInProgress || isCompleted ? 1.2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status Header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? const Color(0xFF16A34A).withOpacity(0.12)
                                              : (isInProgress ? Colors.amber.withOpacity(0.15) : const Color(0xFF2563EB).withOpacity(0.12)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isCompleted
                                              ? '✓ COMPLETED'
                                              : (isInProgress ? '⏳ IN PROGRESS' : (t['subject'] ?? 'GENERAL')),
                                          style: TextStyle(
                                            color: isCompleted
                                                ? const Color(0xFF16A34A)
                                                : (isInProgress ? Colors.amber.shade900 : const Color(0xFF2563EB)),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isInProgress)
                                        Text(
                                          '$answered / $totalQs Answered',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                                        )
                                      else if (isCompleted)
                                        Text(
                                          'Score: ${progress?['score'] ?? 0} Marks',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                        )
                                      else
                                        Text('$duration Mins Duration', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Test Title
                                  Text(
                                    t['test_title'] ?? 'Mock Drill',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalQs Multi-Statement Concepts • Instant Result',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),

                                  // Progress Bar for In-Progress State
                                  if (isInProgress) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progressFraction,
                                        minHeight: 5,
                                        backgroundColor: Colors.grey.withOpacity(0.15),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),

                                  // Dynamic Action CTA Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: ElevatedButton.icon(
                                      icon: Icon(
                                        isCompleted
                                            ? Icons.bar_chart_rounded
                                            : (isInProgress ? Icons.replay_rounded : Icons.play_circle_fill_rounded),
                                        size: 17,
                                      ),
                                      label: Text(
                                        isCompleted
                                            ? 'Review Performance Card 📊'
                                            : (isInProgress ? 'Resume Test ($answered/$totalQs) 🔄' : 'Start Timed CBT Test 🚀'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isCompleted
                                            ? const Color(0xFF16A34A).withOpacity(0.12)
                                            : (isInProgress ? Colors.amber.shade700 : const Color(0xFF2563EB)),
                                        foregroundColor: isCompleted ? const Color(0xFF16A34A) : Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: isCompleted ? const BorderSide(color: Color(0xFF16A34A)) : BorderSide.none,
                                        ),
                                      ),
                                      onPressed: () => _startBatchTest(t),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // 2. Class Handouts & PDFs Tab
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      const Text('PDF Notes & Mnemonics', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Teacher will link classroom handouts here.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
