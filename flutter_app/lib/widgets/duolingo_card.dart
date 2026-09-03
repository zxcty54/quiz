import 'package:flutter/material.dart';
import 'package:mocktester/models/duolingo_payload.dart';

class DuolingoCard extends StatefulWidget {
  final DuolingoPayload payload;
  final bool isDarkMode;

  const DuolingoCard({Key? key, required this.payload, this.isDarkMode = false}) : super(key: key);

  @override
  State<DuolingoCard> createState() => _DuolingoCardState();
}

class _DuolingoCardState extends State<DuolingoCard> {
  String? _selectedOption;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    final isDark = widget.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💡 1. Micro Concept Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("💡", style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    payload.microConcept,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ⚡ 2. Three Step Breakdown
          if (payload.steps.isNotEmpty) ...[
            Text("⚡ Quick Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 6),
            ...payload.steps.map((step) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade300 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),
          ],

          // 🎯 3. Micro Challenge
          if (payload.challengeQuestion.isNotEmpty) ...[
            Text("🎯 Micro Challenge", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent.shade200)),
            const SizedBox(height: 6),
            Text(payload.challengeQuestion, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),

            // MCQ Options Grid
            ...payload.options.entries.map((opt) {
              final optKey = opt.key;
              final isChosen = _selectedOption == optKey;
              final isCorrect = payload.correctAnswer.contains(optKey);

              Color btnColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100;
              Color borderCol = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

              if (_submitted) {
                if (isCorrect) {
                  btnColor = Colors.green.withOpacity(0.2);
                  borderCol = Colors.green;
                } else if (isChosen && !isCorrect) {
                  btnColor = Colors.red.withOpacity(0.2);
                  borderCol = Colors.red;
                }
              } else if (isChosen) {
                btnColor = Colors.blue.withOpacity(0.2);
                borderCol = Colors.blueAccent;
              }

              return InkWell(
                onTap: _submitted ? null : () => setState(() => _selectedOption = optKey),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: btnColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderCol, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: borderCol,
                        child: Text(optKey, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          opt.value,
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),
            if (!_submitted && _selectedOption != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => _submitted = true),
                  child: const Text("CHECK ANSWER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),

            // Feedback Explanation
            if (_submitted)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedOption == payload.correctAnswer ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payload.explanation.isNotEmpty ? payload.explanation : "Correct Answer: ${payload.correctAnswer}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _selectedOption == payload.correctAnswer ? Colors.green : Colors.redAccent,
                  ),
                ),
              )
          ]
        ],
      ),
    );
  }
}
