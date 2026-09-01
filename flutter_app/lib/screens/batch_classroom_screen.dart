import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/question_model.dart';
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

class _BatchClassroomScreenState extends State<BatchClassroomScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _cbtTests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBatchTests();
  }

  Future<void> _loadBatchTests() async {
    try {
      final res = await Supabase.instance.client
          .from('batch_tests')
          .select()
          .eq('batch_id', widget.batchData['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _cbtTests = res ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startBatchTest(Map<String, dynamic> test) {
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
        ),
      ),
    );
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
                // 1. CBT Mocks List
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
                          final int totalQs = t['total_questions'] ?? ((t['questions_json'] as List?)?.length ?? 0);
                          final int duration = t['duration_mins'] ?? 15;

                          return Card(
                            color: cardBg,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
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
                                        child: Text(
                                          t['subject'] ?? 'General',
                                          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text('$duration Mins Duration', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t['test_title'] ?? 'Mock Drill',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('$totalQs Multi-Statement Concepts • Instant Result', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                                      label: const Text('Start Timed CBT Test 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
