import 'package:flutter/material.dart';
import '../screens/student_cbt_report_screen.dart';

class StudentIntelligenceSheet extends StatefulWidget {
  final List<dynamic> batches;
  final List<dynamic> rawSubmissions;
  final List<dynamic> batchTests;
  final bool isDarkMode;

  const StudentIntelligenceSheet({
    super.key,
    required this.batches,
    required this.rawSubmissions,
    required this.batchTests,
    required this.isDarkMode,
  });

  @override
  State<StudentIntelligenceSheet> createState() => _StudentIntelligenceSheetState();
}

class _StudentIntelligenceSheetState extends State<StudentIntelligenceSheet> {
  String _selectedBatchFilter = 'ALL';
  String _selectedTestId = 'ALL';

  @override
  Widget build(BuildContext context) {
    // 1. Filter submissions based on batch
    final batchSubmissions = widget.rawSubmissions.where((s) {
      if (_selectedBatchFilter == 'ALL') return true;
      return (s['batch_id'] ?? '').toString().trim() == _selectedBatchFilter.trim();
    }).toList();

    // 2. Filter tests based on batch
    final batchTests = widget.batchTests.where((t) {
      if (_selectedBatchFilter == 'ALL') return true;
      return (t['batch_id'] ?? '').toString().trim() == _selectedBatchFilter.trim();
    }).toList();

    // 3. Analytics calculation
    double totalScoreSum = 0.0;
    final Map<String, int> weakFrequency = {};

    for (var s in batchSubmissions) {
      totalScoreSum += (s['score'] as num?)?.toDouble() ?? 0.0;
      final weak = s['weak_subject']?.toString();
      if (weak != null && weak.isNotEmpty && weak != 'All Clear') {
        weakFrequency[weak] = (weakFrequency[weak] ?? 0) + 1;
      }
    }

    final double avgBatchScore = batchSubmissions.isNotEmpty
        ? totalScoreSum / batchSubmissions.length
        : 0.0;
    final String topWeakArea = weakFrequency.isNotEmpty
        ? weakFrequency.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'All Concepts Stable';

    // 4. Test-specific filtered list
    final filteredSubmissions = batchSubmissions.where((s) {
      if (_selectedTestId == 'ALL') return true;
      return (s['test_id'] ?? '').toString().trim() == _selectedTestId.trim();
    }).toList();

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
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
                    const Text('📊 Batch Performance & Intelligence Hub',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Text('View overall or batch-wise student analytics',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                  ],
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 10),

            // 1️⃣ BATCH FILTER CHIPS
            const Text('Select Classroom Batch Filter:',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('🌐 All Batches (Overall)'),
                      selected: _selectedBatchFilter == 'ALL',
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _selectedBatchFilter == 'ALL' ? Colors.white : Colors.black87,
                      ),
                      onSelected: (_) => setState(() {
                        _selectedBatchFilter = 'ALL';
                        _selectedTestId = 'ALL';
                      }),
                    ),
                  ),
                  ...widget.batches.map((b) {
                    final bId = (b['id'] ?? '').toString();
                    final bName = b['batch_name'] ?? 'Batch';
                    final bool isSelected = _selectedBatchFilter == bId;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('🏫 $bName'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        onSelected: (_) => setState(() {
                          _selectedBatchFilter = bId;
                          _selectedTestId = 'ALL';
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2️⃣ DYNAMIC PERFORMANCE SUMMARY CARD
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
                      Text(
                        _selectedBatchFilter == 'ALL'
                            ? 'OVERALL INSTITUTE PERFORMANCE'
                            : 'BATCH-WISE PERFORMANCE',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${batchSubmissions.length} Submissions',
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
                            const Text('Avg Score',
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
                            const Text('Critical Weak Area',
                                style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                            Text(topWeakArea,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5,
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
            const Text('Filter by CBT Mock Drill:',
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
                      selected: _selectedTestId == 'ALL',
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _selectedTestId == 'ALL' ? Colors.white : Colors.black87,
                      ),
                      onSelected: (_) => setState(() => _selectedTestId = 'ALL'),
                    ),
                  ),
                  ...batchTests.map((t) {
                    final String tId = (t['id'] ?? '').toString();
                    final bool isSelected = _selectedTestId == tId;
                    final count = batchSubmissions
                        .where((s) => (s['test_id'] ?? '').toString() == tId)
                        .length;
                    final String testName = t['title'] ?? t['test_title'] ?? t['testTitle'] ?? 'Mock Drill';

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('🎯 $testName ($count)'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        onSelected: (_) => setState(() => _selectedTestId = tId),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 16),

            // 4️⃣ STUDENT SUBMISSIONS LIST
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
                            'Is selection me koi submission record nahi mila.',
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

                        String matchedTestTitle = 'Classroom CBT Test';
                        final matchingTestList = batchTests.where(
                          (t) => (t['id'] ?? '').toString() == (s['test_id'] ?? '').toString(),
                        );
                        if (matchingTestList.isNotEmpty) {
                          final tMatch = matchingTestList.first;
                          matchedTestTitle = tMatch['title'] ?? tMatch['test_title'] ?? tMatch['testTitle'] ?? 'Classroom CBT Test';
                        }

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
                                      if (responses.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Is attempt ka detailed response available nahi hai.')),
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
      ),
    );
  }
}
