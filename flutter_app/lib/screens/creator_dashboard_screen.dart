import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_telegram_alert.dart';
import '../utils/bihar_location_data.dart';
import 'creator_mock_builder_screen.dart';
import 'creator_profile_screen.dart';
import 'student_cbt_report_screen.dart';

class CreatorDashboardScreen extends StatefulWidget {
  final String creatorHandle;
  final bool isDarkMode;

  const CreatorDashboardScreen({
    super.key,
    required this.creatorHandle,
    required this.isDarkMode,
  });

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _coachingData;
  List<dynamic> _batches = [];
  bool _isLoading = true;

  int _totalViews = 0;
  int _totalMockAttempts = 0;
  int _totalBatchStudents = 0;

  // 📊 Test-Wise Submissions Storage
  List<dynamic> _allRawSubmissions = [];
  List<dynamic> _allBatchTests = [];

  @override
  void initState() {
    super.initState();
    _loadCompleteAnalytics();
  }

  Future<void> _loadCompleteAnalytics() async {
    try {
      final client = Supabase.instance.client;
      final handle = widget.creatorHandle.trim();

      // 1. Fetch Creator Profile
      final profileRes = await client
          .from('creator_profiles')
          .select()
          .eq('handle_id', handle)
          .maybeSingle();

      // 2. Fetch Coaching Data
      dynamic coachingRes = await client
          .from('coachings')
          .select()
          .ilike('owner_name', handle)
          .maybeSingle();

      coachingRes ??= await client
          .from('coachings')
          .select()
          .ilike('creator_handle', handle)
          .maybeSingle();

      List<dynamic> batchesRes = [];
      List<dynamic> batchTestsRes = [];
      List<dynamic> submissionsRes = [];
      int batchTestAttempts = 0;
      final Set<String> uniqueStudentKeys = {};

      if (coachingRes != null) {
        final coachingId = coachingRes['id'];

        batchesRes = await client
            .from('batches')
            .select('*')
            .eq('coaching_id', coachingId)
            .order('created_at', ascending: false);

        if (batchesRes.isNotEmpty) {
          final List<String> batchIds =
              batchesRes.map((b) => b['id'].toString()).toList();

          // Fetch all tests created in these batches
          try {
            batchTestsRes = await client
                .from('batch_tests')
                .select('*')
                .inFilter('batch_id', batchIds)
                .order('created_at', ascending: false);

            for (var t in batchTestsRes) {
              batchTestAttempts += (t['attempts_count'] as int? ?? 0);
            }
          } catch (e) {
            debugPrint("Batch tests fetch error: $e");
          }

          // Fetch all student submissions
          try {
            submissionsRes = await client
                .from('batch_submissions')
                .select('*')
                .inFilter('batch_id', batchIds)
                .order('created_at', ascending: false);

            for (var s in submissionsRes) {
              final rawId = (s['student_identifier'] ?? s['student_name'] ?? 'student').toString();
              uniqueStudentKeys.add(rawId);
            }
          } catch (e) {
            debugPrint("Batch submissions fetch error: $e");
          }
        }
      }

      // 3. Fetch Community Views
      final postsRes = await client
          .from('community_posts')
          .select('views_count')
          .eq('creator_id', handle);

      int views = 0;
      for (var p in (postsRes as List? ?? [])) {
        views += (p['views_count'] as int? ?? 0);
      }

      // 4. Fetch Public Mock Attempts
      final mocksRes = await client
          .from('creator_mocks')
          .select('id, attempts_count')
          .eq('creator_id', handle);

      int publicAttempts = 0;
      for (var m in (mocksRes as List? ?? [])) {
        publicAttempts += (m['attempts_count'] as int? ?? 0);
      }

      int totalCombinedAttempts = publicAttempts + batchTestAttempts;

      if (mounted) {
        setState(() {
          _profile = profileRes;
          _coachingData = coachingRes;
          _batches = batchesRes;
          _allBatchTests = batchTestsRes;
          _allRawSubmissions = submissionsRes;
          _totalViews = views;
          _totalMockAttempts = totalCombinedAttempts;
          _totalBatchStudents = uniqueStudentKeys.length;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint("❌ [CREATOR_DASHBOARD] Analytics error: $e\n$stack");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _callOrMessageStudent(String contact) async {
    final clean = contact.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // 🎯 Test-Wise Intelligence Hub with Overall Analytics
  void _openStudentIntelligenceSheet() {
    if (_batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aapke coaching ke paas abhi koi active batch nahi hai.')),
      );
      return;
    }

    String selectedBatchId = _batches.first['id'].toString();
    String selectedTestId = 'ALL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final currentBatch = _batches.firstWhere(
            (b) => b['id'].toString() == selectedBatchId,
            orElse: () => _batches.first,
          );
          final String currentBatchName = currentBatch['batch_name'] ?? 'Classroom Batch';

          // All submissions for selected batch
          final batchSubmissions = _allRawSubmissions
              .where((s) => s['batch_id'].toString() == selectedBatchId)
              .toList();

          // All tests belonging to this batch
          final batchTests = _allBatchTests
              .where((t) => t['batch_id'].toString() == selectedBatchId)
              .toList();

          // Overall Batch Analysis Calculation
          double totalScoreSum = 0.0;
          final Map<String, int> weakFrequency = {};
          final Map<String, int> strongFrequency = {};

          for (var s in batchSubmissions) {
            totalScoreSum += (s['score'] as num?)?.toDouble() ?? 0.0;
            final weak = s['weak_subject']?.toString();
            final strong = s['strong_subject']?.toString();
            if (weak != null && weak.isNotEmpty && weak != 'All Clear') {
              weakFrequency[weak] = (weakFrequency[weak] ?? 0) + 1;
            }
            if (strong != null && strong.isNotEmpty) {
              strongFrequency[strong] = (strongFrequency[strong] ?? 0) + 1;
            }
          }

          final double avgBatchScore = batchSubmissions.isNotEmpty
              ? totalScoreSum / batchSubmissions.length
              : 0.0;
          final String topWeakArea = weakFrequency.isNotEmpty
              ? weakFrequency.entries.reduce((a, b) => a.value > b.value ? a : b).key
              : 'All Concepts Stable';
          final String topStrongArea = strongFrequency.isNotEmpty
              ? strongFrequency.entries.reduce((a, b) => a.value > b.value ? a : b).key
              : 'General Revision';

          // Filter student submissions for selected test
          final filteredSubmissions = batchSubmissions.where((s) {
            if (selectedTestId == 'ALL') return true;
            return s['test_id']?.toString() == selectedTestId;
          }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📊 Batch Intelligence & CBT Hub',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        Text('Granular CBT Breakdown for Classroom Mocks',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                      ],
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),

                // 1️⃣ BATCH SELECTOR DROPDOWN
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedBatchId,
                      isExpanded: true,
                      dropdownColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                      items: _batches.map<DropdownMenuItem<String>>((b) {
                        return DropdownMenuItem<String>(
                          value: b['id'].toString(),
                          child: Text(
                            '🏫 ${b['batch_name']} (Code: ${b['batch_code']})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            selectedBatchId = val;
                            selectedTestId = 'ALL';
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2️⃣ OVERALL BATCH SCORE & PERFORMANCE CARD
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('OVERALL BATCH PERFORMANCE',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[500])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${batchSubmissions.length} Total Submissions',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Avg Batch Score',
                                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(avgBatchScore.toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF2563EB))),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Most Common Trap',
                                    style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                Text(topWeakArea,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3️⃣ TEST/MOCK SELECTOR CHIPS
                const Text('Filter by Specific CBT Mock Drill:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('All Mocks (${batchSubmissions.length})'),
                          selected: selectedTestId == 'ALL',
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: selectedTestId == 'ALL' ? Colors.white : Colors.black87,
                          ),
                          onSelected: (_) => setSheetState(() => selectedTestId = 'ALL'),
                        ),
                      ),
                      ...batchTests.map((t) {
                        final String tId = t['id'].toString();
                        final bool isSelected = selectedTestId == tId;
                        final count = batchSubmissions
                            .where((s) => s['test_id']?.toString() == tId)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('🎯 ${t['title']} ($count)'),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2563EB),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                            onSelected: (_) => setSheetState(() => selectedTestId = tId),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const Divider(height: 16),

                // 4️⃣ STUDENT SUBMISSIONS LIST FOR SELECTED TEST
                Expanded(
                  child: filteredSubmissions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined,
                                  size: 44, color: Colors.grey.withOpacity(0.4)),
                              const SizedBox(height: 10),
                              Text(
                                selectedTestId == 'ALL'
                                    ? 'Is batch me abhi tak koi test attempt nahi hua hai.'
                                    : 'Is mock drill me koi submission record nahi hai.',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredSubmissions.length,
                          itemBuilder: (ctx, idx) {
                            final s = filteredSubmissions[idx];
                            final rawIdentifier =
                                (s['student_identifier'] ?? s['student_name'] ?? 'Aspirant').toString();

                            String nameOnly = rawIdentifier;
                            String contactInfo = '';
                            if (rawIdentifier.contains('(') && rawIdentifier.contains(')')) {
                              final parts = rawIdentifier.split('(');
                              nameOnly = parts[0].trim();
                              contactInfo = parts[1]
                                  .replaceAll(')', '')
                                  .replaceAll('Roll/Ph:', '')
                                  .trim();
                            }

                            final double score = (s['score'] as num?)?.toDouble() ?? 0.0;
                            final int acc = (s['accuracy'] as num?)?.toInt() ?? 0;
                            final int correct = s['correct_count'] ?? 0;
                            final int wrong = s['wrong_count'] ?? 0;
                            final List responses =
                                (s['detailed_responses'] is List) ? s['detailed_responses'] : [];

                            // Find test name
                            String matchedTestTitle = 'Classroom CBT Test';
                            try {
                              final tMatch = batchTests.firstWhere(
                                (t) => t['id'].toString() == s['test_id']?.toString(),
                                orElse: () => null,
                              );
                              if (tMatch != null) {
                                matchedTestTitle = tMatch['title'] ?? 'CBT Mock';
                              }
                            } catch (_) {}

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
                                          child: Text(
                                            nameOnly.isNotEmpty ? nameOnly[0].toUpperCase() : 'S',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2563EB),
                                                fontSize: 14),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(nameOnly,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold, fontSize: 14)),
                                              Text(
                                                '$matchedTestTitle ${contactInfo.isNotEmpty ? "• $contactInfo" : ""}',
                                                style: const TextStyle(
                                                    fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Score: ${score.toStringAsFixed(1)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2563EB),
                                                fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text('✅ $correct Sahi',
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 12),
                                        Text('❌ $wrong Galat',
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 12),
                                        Text('🎯 $acc% Acc',
                                            style: const TextStyle(
                                                color: Colors.purple,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    if (s['weak_subject'] != null && s['weak_subject'] != 'All Clear') ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '⚠️ Weak Topic: ${s['weak_subject']}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                    const Divider(height: 14),

                                    // View Specific CBT Question Paper Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 34,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.assignment_outlined, size: 14),
                                        label: const Text('View Test Breakdown (Q-by-Q)',
                                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF2563EB),
                                          side: const BorderSide(color: Color(0xFF2563EB), width: 0.8),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          if (responses.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Is attempt ka question-by-question data record nahi hai.')),
                                            );
                                            return;
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => StudentCbtReportScreen(
                                                studentName: nameOnly,
                                                testTitle: matchedTestTitle,
                                                score: score,
                                                responseBreakdown: responses,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openContentPublishSheet(String type) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    final opCtrl1 = TextEditingController();
    final opCtrl2 = TextEditingController();
    final opCtrl3 = TextEditingController();
    final opCtrl4 = TextEditingController();
    final expCtrl = TextEditingController();
    int correctIdx = 0;

    bool isSubmitting = false;

    String sheetTitle = '📢 Share Notice & Update';
    String tag = 'Announcement 📢';
    if (type == 'pdf') {
      sheetTitle = '📚 Share PDF Notes & Handouts';
      tag = 'Study Material 📚';
    } else if (type == 'quiz') {
      sheetTitle = '🎯 Publish Daily Rapid Quiz';
      tag = 'Daily Quiz ⚡';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sheetTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),

                if (type == 'pdf') ...[
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'PDF Title / Chapter Name',
                      hintText: 'e.g. Modern History Top 100 Notes',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Google Drive / Telegram PDF Link',
                      hintText: 'https://drive.google.com/... or t.me/...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon:
                          Icon(Icons.link_rounded, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                TextField(
                  controller: contentCtrl,
                  maxLines: type == 'quiz' ? 2 : 4,
                  decoration: InputDecoration(
                    labelText: type == 'quiz'
                        ? 'Question Statement'
                        : 'Description / Message for Students',
                    hintText: type == 'quiz'
                        ? 'Type quiz question here...'
                        : 'Explain key highlights...',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                if (type == 'quiz') ...[
                  const Text(
                      'Options & Correct Answer (Tap letter to set correct):',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ...List.generate(4, (idx) {
                    final controllers = [opCtrl1, opCtrl2, opCtrl3, opCtrl4];
                    final isCorrect = correctIdx == idx;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setModalState(() => correctIdx = idx),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: isCorrect
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey.withOpacity(0.3),
                              child: Text(
                                String.fromCharCode(65 + idx),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isCorrect
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controllers[idx],
                              decoration: InputDecoration(
                                hintText:
                                    'Option ${String.fromCharCode(65 + idx)}',
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
                  TextField(
                    controller: expCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Explanation (Optional)',
                        isDense: true,
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final rawContent = contentCtrl.text.trim();
                            if (rawContent.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Content likhna zaroori hai!')));
                              return;
                            }

                            setModalState(() => isSubmitting = true);

                            String finalContent = rawContent;
                            if (type == 'pdf') {
                              final pTitle = titleCtrl.text.trim();
                              final pLink = linkCtrl.text.trim();
                              finalContent =
                                  '${pTitle.isNotEmpty ? "📑 **$pTitle**\n\n" : ""}$rawContent${pLink.isNotEmpty ? "\n\n🔗 Download Link: $pLink" : ""}';
                            }

                            Map<String, dynamic>? pollJson;
                            if (type == 'quiz') {
                              final rawOptions = [
                                opCtrl1.text.trim(),
                                opCtrl2.text.trim(),
                                opCtrl3.text.trim(),
                                opCtrl4.text.trim()
                              ].where((o) => o.isNotEmpty).toList();
                              if (rawOptions.length >= 2) {
                                pollJson = {
                                  'options': rawOptions,
                                  'correct_idx': correctIdx < rawOptions.length
                                      ? correctIdx
                                      : 0,
                                  'votes': List.filled(rawOptions.length, 0),
                                  'exp': expCtrl.text.trim().isNotEmpty
                                      ? expCtrl.text.trim()
                                      : 'Provided by @${widget.creatorHandle}',
                                };
                              }
                            }

                            try {
                              final authorName = _coachingData?['name'] ??
                                  _profile?['name'] ??
                                  widget.creatorHandle;

                              final inserted = await Supabase.instance.client
                                  .from('community_posts')
                                  .insert({
                                'creator_id': widget.creatorHandle,
                                'author_name': authorName,
                                'content': finalContent,
                                'tag': tag,
                                'poll_data': pollJson,
                                'views_count': 1,
                                'is_approved': true,
                                'upvotes': 0,
                                'downvotes': 0,
                                'shares_count': 0,
                                'bookmarks_count': 0,
                              }).select().single();

                              AdminTelegramAlert.sendForInteractiveApproval(
                                postId: inserted['id'] ?? 0,
                                authorName: authorName,
                                authorHandle: widget.creatorHandle,
                                tag: tag,
                                content: finalContent,
                                hasPoll: type == 'quiz',
                              ).catchError((_) => false);

                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadCompleteAnalytics();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '✅ $tag successfully published to Feed & Profile!'),
                                      backgroundColor:
                                          const Color(0xFF16A34A)),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Publish error: $e')));
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Publish to Community & Profile 🚀',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _openBannerModifierSheet() {
    File? newImage;
    bool isSaving = false;
    final picker = ImagePicker();
    final currentUrl = _coachingData?['banner_url'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🖼️ Modify Institute Poster',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                  'Recommended: 1200 x 675 px (16:9 Ratio). High quality photo of billboard/toppers.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: () async {
                  final picked = await picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 85);
                  if (picked != null) {
                    setModalState(() => newImage = File(picked.path));
                  }
                },
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF2563EB).withOpacity(0.3)),
                  ),
                  child: newImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(newImage!, fit: BoxFit.cover))
                      : (currentUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(currentUrl,
                                  fit: BoxFit.cover))
                          : const Center(
                              child: Text(
                                  'Tap to pick image from gallery 📷',
                                  style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold)))),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white),
                  onPressed: (isSaving || newImage == null)
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          try {
                            final bytes = await newImage!.readAsBytes();
                            final fileExt = newImage!.path.split('.').last;
                            final fileName =
                                'banner_${widget.creatorHandle}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                            await Supabase.instance.client.storage
                                .from('coaching_assets')
                                .uploadBinary(fileName, bytes,
                                    fileOptions: FileOptions(
                                        contentType: 'image/$fileExt',
                                        upsert: true));

                            final updatedUrl = Supabase.instance.client.storage
                                .from('coaching_assets')
                                .getPublicUrl(fileName);

                            await Supabase.instance.client
                                .from('coachings')
                                .update({'banner_url': updatedUrl}).eq(
                                    'id', _coachingData?['id']);

                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadCompleteAnalytics();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('✅ Banner Updated!'),
                                      backgroundColor: Color(0xFF16A34A)));
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save New Poster 🚀',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetailsModifierSheet() {
    final nameCtrl = TextEditingController(
        text: _coachingData?['name'] ?? _profile?['name'] ?? '');
    final landmarkCtrl =
        TextEditingController(text: _coachingData?['landmark_address'] ?? '');
    final contactCtrl =
        TextEditingController(text: _coachingData?['contact_number'] ?? '');

    String selectedDistrict = _coachingData?['district'] ?? 'Patna';
    if (!kBiharDistrictCityMap.containsKey(selectedDistrict)) {
      selectedDistrict = 'Patna';
    }
    List<String> availableCities =
        kBiharDistrictCityMap[selectedDistrict] ?? ['Other / Rural Area'];
    String selectedCity = _coachingData?['city'] ?? availableCities.first;
    if (!availableCities.contains(selectedCity)) {
      selectedCity = availableCities.first;
    }

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('📍 Modify Coaching Details',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Coaching Title',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  decoration: const InputDecoration(
                      labelText: 'District (38 Districts)',
                      border: OutlineInputBorder(),
                      isDense: true),
                  items: kBiharDistrictCityMap.keys
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedDistrict = val;
                        availableCities = kBiharDistrictCityMap[val] ??
                            ['Other / Rural Area'];
                        selectedCity = availableCities.first;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedCity,
                  decoration: const InputDecoration(
                      labelText: 'Town / Education Hub',
                      border: OutlineInputBorder(),
                      isDense: true),
                  items: availableCities
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedCity = val!),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: landmarkCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Landmark / Area',
                            border: OutlineInputBorder(),
                            isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: contactCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Helpline No.',
                            border: OutlineInputBorder(),
                            isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              final updatedName = nameCtrl.text.trim().isNotEmpty
                                  ? nameCtrl.text.trim()
                                  : (_coachingData?['name'] ??
                                      widget.creatorHandle);

                              await Supabase.instance.client
                                  .from('coachings')
                                  .update({
                                'name': updatedName,
                                'district': selectedDistrict,
                                'city': selectedCity,
                                'landmark_address': landmarkCtrl.text.trim(),
                                'contact_number': contactCtrl.text.trim(),
                              }).eq('id', _coachingData?['id']);

                              await Supabase.instance.client
                                  .from('creator_profiles')
                                  .update({'name': updatedName}).eq(
                                      'handle_id', widget.creatorHandle);

                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadCompleteAnalytics();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('✅ Details Saved!'),
                                        backgroundColor: Color(0xFF16A34A)));
                              }
                            } catch (_) {
                              setModalState(() => isSaving = false);
                            }
                          },
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Details 🚀',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _openBatchManagerModal() {
    final batchNameCtrl = TextEditingController();
    final batchCodeCtrl = TextEditingController();
    String newBatchStatus = 'LIVE';
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🏫 Manage Classroom Batches',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),

                if (_batches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text('Koi purana batch nahi mila.',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12)),
                    ),
                  ),

                ...List.generate(_batches.length, (idx) {
                  final b = _batches[idx];
                  final String bStatus = b['status'] ?? 'LIVE';
                  final bool isHidden = bStatus == 'HIDDEN';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isHidden
                          ? Colors.grey.withOpacity(0.1)
                          : (widget.isDarkMode
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b['batch_name'] ?? 'Batch',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                  'CODE: ${b['batch_code']} • Status: $bStatus',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 18, color: Color(0xFF16A34A)),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: b['batch_code'] ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text('Copied Code: ${b['batch_code']}')));
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (val) async {
                            await Supabase.instance.client
                                .from('batches')
                                .update({'status': val}).eq('id', b['id']);
                            _loadCompleteAnalytics();
                            Navigator.pop(ctx);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'LIVE', child: Text('🟢 Set LIVE')),
                            const PopupMenuItem(
                                value: 'UPCOMING',
                                child: Text('⏳ Set UPCOMING')),
                            const PopupMenuItem(
                                value: 'HIDDEN', child: Text('⚪ HIDE Batch')),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const Divider(height: 20),
                const Text('+ Add New Batch',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),

                TextField(
                    controller: batchNameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Batch Name',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: batchCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Join Code (Password)',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white),
                    onPressed: isCreating
                        ? null
                        : () async {
                            final bName = batchNameCtrl.text.trim();
                            final bCode =
                                batchCodeCtrl.text.trim().toUpperCase();
                            if (bName.isEmpty || bCode.isEmpty) return;

                            setModalState(() => isCreating = true);
                            try {
                              await Supabase.instance.client
                                  .from('batches')
                                  .insert({
                                'coaching_id': _coachingData?['id'],
                                'batch_name': bName,
                                'batch_code': bCode,
                                'status': newBatchStatus,
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadCompleteAnalytics();
                            } catch (_) {
                              setModalState(() => isCreating = false);
                            }
                          },
                    child: const Text('Create Batch Code 🚀',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Scaffold(
          backgroundColor: bgSurface,
          body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Institute Studio & Hub',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Analytics',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadCompleteAnalytics();
            },
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'View Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CreatorProfileScreen(
                      creatorHandle: widget.creatorHandle, isDarkMode: isDark)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF2563EB).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_coachingData?['name'] ?? 'Coaching Hub',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                      '@${widget.creatorHandle} • ${_coachingData?['city'] ?? "Bihar"}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Students', '$_totalBatchStudents',
                          Icons.groups_outlined),
                      _buildMetricItem('Batches', '${_batches.length}',
                          Icons.class_outlined),
                      _buildMetricItem('Attempts', '$_totalMockAttempts',
                          Icons.bolt_rounded),
                      _buildMetricItem('Views', '$_totalViews',
                          Icons.remove_red_eye_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildActionCard(
              title: 'Student Performance Intelligence 📊',
              subtitle:
                  'Filter by specific mock drill, view student score and exact question breakdown.',
              icon: Icons.insights_rounded,
              color: const Color(0xFF2563EB),
              onTap: _openStudentIntelligenceSheet,
            ),
            const SizedBox(height: 14),

            const Text('Modify Institute & Batches',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Modify Banner / Poster 🖼️',
              subtitle:
                  'Change 16:9 billboard photo without affecting address or details.',
              icon: Icons.photo_library_outlined,
              color: const Color(0xFF2563EB),
              onTap: _openBannerModifierSheet,
            ),

            _buildActionCard(
              title: 'Edit Location & Details 📍',
              subtitle:
                  'Update district, education hub, landmark address or helpline number.',
              icon: Icons.edit_location_alt_outlined,
              color: const Color(0xFF16A34A),
              onTap: _openDetailsModifierSheet,
            ),

            _buildActionCard(
              title: 'Manage Batches & Codes 🏫',
              subtitle:
                  'Add new batch, toggle LIVE / UPCOMING / HIDE, copy secret code.',
              icon: Icons.vpn_key_outlined,
              color: const Color(0xFFEA580C),
              onTap: _openBatchManagerModal,
            ),
            const SizedBox(height: 16),

            const Text('Publish Content & Tests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Create CBT Mock Test ⚡',
              subtitle:
                  'Build timed CBT tests for public feed or private classroom batches.',
              icon: Icons.assignment_add,
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CreatorMockBuilderScreen(
                        creatorHandle: widget.creatorHandle,
                        isDarkMode: isDark)),
              ).then((_) => _loadCompleteAnalytics()),
            ),

            _buildActionCard(
              title: 'Share PDF Notes & Handouts 📚',
              subtitle:
                  'Post Google Drive, Telegram or download links for student notes.',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFF059669),
              onTap: () => _openContentPublishSheet('pdf'),
            ),

            _buildActionCard(
              title: 'Publish Daily Rapid Quiz 🎯',
              subtitle:
                  'Create 4-option instant polls with solution on community feed.',
              icon: Icons.poll_outlined,
              color: const Color(0xFF2563EB),
              onTap: () => _openContentPublishSheet('quiz'),
            ),

            _buildActionCard(
              title: 'Post Notice & Announcement 📢',
              subtitle:
                  'Share batch timing, examination updates, or results celebrations.',
              icon: Icons.campaign_outlined,
              color: const Color(0xFFD97706),
              onTap: () => _openContentPublishSheet('notice'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
