import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../services/user_stats_service.dart';
import '../widgets/math_text.dart';

class SavedQuestionsScreen extends StatefulWidget {
  final bool isDarkMode;
  const SavedQuestionsScreen({super.key, this.isDarkMode = false});

  @override
  State<SavedQuestionsScreen> createState() => _SavedQuestionsScreenState();
}

class _SavedQuestionsScreenState extends State<SavedQuestionsScreen> {
  late Future<List<Map<String, dynamic>>> _savedQuestionsFuture;
  bool _isHindi = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _savedQuestionsFuture = UserStatsService.getSavedQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Explicit High-Contrast Theme Colors (Prevents White Foggy Layer)
    final bool isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    final Color bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
        title: Text(
          '⭐ Bookmarked Questions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2563EB)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isHindi ? 'हिंदी' : 'ENG',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
            onPressed: () => setState(() => _isHindi = !_isHindi),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _savedQuestionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'No Bookmarked Questions Yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Questions test ke dauran bookmark karein, wo yahan save ho jayenge.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final qJson = list[index];
              final q = Question.fromJson(qJson);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
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
                            'Question ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 11),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            await UserStatsService.toggleBookmark(qJson);
                            _loadData();
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 📝 Question Text with Solid Forced Color
                    MathFormattedText(
                      text: q.getText(_isHindi),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 🔘 Option List with Adaptive Contrast
                    ...List.generate(q.options.length, (optIdx) {
                      final bool isCorrect = optIdx == q.answerIndex;
                      final Color optBg = isCorrect
                          ? (isDark ? const Color(0xFF14532D).withOpacity(0.4) : const Color(0xFFDCFCE7))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9));
                      final Color optBorder = isCorrect
                          ? const Color(0xFF16A34A)
                          : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: optBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: optBorder, width: isCorrect ? 1.5 : 1.0),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "${String.fromCharCode(65 + optIdx)}. ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isCorrect ? const Color(0xFF16A34A) : textColor,
                              ),
                            ),
                            Expanded(
                              child: MathFormattedText(
                                text: q.options[optIdx],
                                textStyle: TextStyle(
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (isCorrect) const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                          ],
                        ),
                      );
                    }),

                    if (q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Solution: ${q.explanation}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
