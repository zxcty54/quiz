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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              studentName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            ),
            Text(
              testTitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: responseBreakdown.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final qData = responseBreakdown[idx];
          final bool isCorrect = qData['is_correct'] == true;
          final bool isSkipped = qData['selected_option'] == null || qData['selected_option'].toString().isEmpty;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSkipped
                    ? Colors.grey.shade300
                    : isCorrect
                        ? const Color(0xFF16A34A).withOpacity(0.3)
                        : Colors.red.shade200,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Q${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryBlue)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSkipped
                            ? Colors.grey.shade100
                            : isCorrect
                                ? const Color(0xFF16A34A).withOpacity(0.12)
                                : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isSkipped
                            ? 'SKIPPED'
                            : isCorrect
                                ? '✓ CORRECT (+1)'
                                : '✗ WRONG (-0.25)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSkipped
                              ? Colors.grey.shade600
                              : isCorrect
                                  ? const Color(0xFF16A34A)
                                  : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  qData['question'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                const SizedBox(height: 8),

                // Suresh ka Answer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCorrect ? const Color(0xFF16A34A).withOpacity(0.06) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Suresh's Answer: ${qData['selected_option'] ?? 'Not Attempted'}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isCorrect ? const Color(0xFF16A34A) : Colors.red.shade800,
                    ),
                  ),
                ),

                // Correct Answer (Agar Suresh ne galat kiya ho)
                if (!isCorrect) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Correct Answer: ${qData['correct_option'] ?? ''}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
