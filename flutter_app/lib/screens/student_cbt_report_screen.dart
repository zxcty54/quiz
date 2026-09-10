import 'package:flutter/material.dart';

class StudentCbtReportScreen extends StatelessWidget {
  final String studentName;
  final String testTitle;
  final num score;
  final List<dynamic> responseBreakdown; // batch_submissions se aaya hua JSON array

  const StudentCbtReportScreen({
    super.key,
    required this.studentName,
    required this.testTitle,
    required this.score,
    required this.responseBreakdown,
  });

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _successGreen = Color(0xFF16A34A);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _warningAmber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    int correctCount = 0;
    int wrongCount = 0;
    int skippedCount = 0;
    int totalTimeSpent = 0;

    for (var item in responseBreakdown) {
      if (item is Map) {
        final bool isCorrect = item['is_correct'] == true;
        final bool isSkipped = item['selected_option'] == null ||
            item['selected_option'].toString().trim().isEmpty ||
            item['selected_option'].toString() == 'Skipped';

        if (isSkipped) {
          skippedCount++;
        } else if (isCorrect) {
          correctCount++;
        } else {
          wrongCount++;
        }

        totalTimeSpent += (item['time_spent'] as num?)?.toInt() ?? 0;
      }
    }

    final int totalQs = responseBreakdown.length;
    final int attempted = correctCount + wrongCount;
    final int accuracy = attempted > 0 ? ((correctCount / attempted) * 100).round() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              studentName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.5,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              testTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 📊 TOP METRICS OVERVIEW CARD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PERFORMANCE SUMMARY',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Total Time: ${_formatDuration(totalTimeSpent)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _metricStat(
                      label: 'Final Score',
                      value: score.toStringAsFixed(1),
                      color: _primaryBlue,
                    ),
                    _metricStat(
                      label: 'Accuracy',
                      value: '$accuracy%',
                      color: accuracy >= 70
                          ? _successGreen
                          : (accuracy >= 45 ? _warningAmber : _dangerRed),
                    ),
                    _metricStat(
                      label: 'Correct',
                      value: '$correctCount / $totalQs',
                      color: _successGreen,
                    ),
                    _metricStat(
                      label: 'Wrong',
                      value: '$wrongCount',
                      color: _dangerRed,
                    ),
                    _metricStat(
                      label: 'Skipped',
                      value: '$skippedCount',
                      color: Colors.grey.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 📝 SECTION TITLE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Question-by-Question Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '$totalQs Questions',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 🔍 QUESTION BREAKDOWN LIST
          ...List.generate(responseBreakdown.length, (idx) {
            final qData = responseBreakdown[idx] as Map<String, dynamic>;
            final bool isCorrect = qData['is_correct'] == true;
            final bool isSkipped = qData['selected_option'] == null ||
                qData['selected_option'].toString().trim().isEmpty ||
                qData['selected_option'].toString() == 'Skipped';

            final int timeSpent = (qData['time_spent'] as num?)?.toInt() ?? 0;
            final String subtopic = (qData['subtopic'] ?? '').toString();
            final String explanation = (qData['explanation'] ?? '').toString().trim();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSkipped
                      ? Colors.grey.shade300
                      : isCorrect
                          ? _successGreen.withOpacity(0.35)
                          : _dangerRed.withOpacity(0.3),
                  width: 1.1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Q Number + Timer + Status Badge
                  Row(
                    children: [
                      Text(
                        'Q${idx + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // ⏱️ Per-Question Time Spent Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF475569)),
                            const SizedBox(width: 3),
                            Text(
                              '${timeSpent}s',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Result Status Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSkipped
                              ? Colors.grey.shade100
                              : isCorrect
                                  ? _successGreen.withOpacity(0.12)
                                  : _dangerRed.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSkipped
                              ? 'SKIPPED'
                              : isCorrect
                                  ? '✓ CORRECT'
                                  : '✗ WRONG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSkipped
                                ? Colors.grey.shade600
                                : isCorrect
                                    ? _successGreen
                                    : _dangerRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Subtopic / Concept Tag
                  if (subtopic.isNotEmpty && subtopic != 'All Clear') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Concept: $subtopic',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  ],

                  // Question Text
                  Text(
                    qData['question'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Student's Chosen Option
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: isSkipped
                          ? Colors.grey.shade50
                          : isCorrect
                              ? _successGreen.withOpacity(0.07)
                              : _dangerRed.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isSkipped
                            ? Colors.grey.shade200
                            : isCorrect
                                ? _successGreen.withOpacity(0.2)
                                : _dangerRed.withOpacity(0.15),
                      ),
                    ),
                    child: Text(
                      "$studentName's Answer: ${isSkipped ? 'Not Attempted (Skipped)' : (qData['selected_option'] ?? '')}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSkipped
                            ? Colors.grey.shade700
                            : isCorrect
                                ? _successGreen
                                : _dangerRed,
                      ),
                    ),
                  ),

                  // Correct Answer (Agar Galat ya Skip hua ho)
                  if (!isCorrect) ...[
                    const SizedBox(height: 5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _successGreen.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _successGreen.withOpacity(0.2)),
                      ),
                      child: Text(
                        "Correct Answer: ${qData['correct_option'] ?? ''}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _successGreen,
                        ),
                      ),
                    ),
                  ],

                  // Detailed Explanation
                  if (explanation.isNotEmpty && explanation != 'N/A') ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Explanation:',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            explanation,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF334155),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static Widget _metricStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final int mins = seconds ~/ 60;
    final int remainingSecs = seconds % 60;
    return '${mins}m ${remainingSecs}s';
  }
}
