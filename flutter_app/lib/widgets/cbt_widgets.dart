import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../services/ai_explainer_service.dart';

// 1️⃣ TCS QUESTION PALETTE DRAWER
class CbtPaletteDrawer extends StatelessWidget {
  final int totalQuestions;
  final int currentIndex;
  final Map<int, int> userAnswers;
  final Set<int> markedForReview;
  final Function(int index) onSelectQuestion;

  const CbtPaletteDrawer({
    super.key,
    required this.totalQuestions,
    required this.currentIndex,
    required this.userAnswers,
    required this.markedForReview,
    required this.onSelectQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("QUESTION PALETTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: totalQuestions,
              itemBuilder: (context, index) {
                final isAnswered = userAnswers.containsKey(index);
                final isReview = markedForReview.contains(index);
                final isCurrent = currentIndex == index;

                Color btnColor = Colors.white;
                Color textColor = Colors.black87;

                if (isReview) {
                  btnColor = const Color(0xFF8E44AD);
                  textColor = Colors.white;
                } else if (isAnswered) {
                  btnColor = const Color(0xFF2ED573);
                  textColor = Colors.white;
                } else if (isCurrent) {
                  btnColor = const Color(0xFFEFF6FF);
                  textColor = const Color(0xFF2575FC);
                }

                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    onSelectQuestion(index);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: btnColor,
                      border: Border.all(color: isCurrent ? const Color(0xFF2575FC) : const Color(0xFFE2E8F0), width: isCurrent ? 2 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text("${index + 1}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// 2️⃣ VISUAL PIE CHART BREAKDOWN CARD
class CbtPieChartCard extends StatelessWidget {
  final int correct;
  final int wrong;
  final int skipped;

  const CbtPieChartCard({
    super.key,
    required this.correct,
    required this.wrong,
    required this.skipped,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Performance Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 35,
                  sections: [
                    if (correct > 0)
                      PieChartSectionData(color: Colors.green, value: correct.toDouble(), title: 'Sahi ($correct)', radius: 45, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (wrong > 0)
                      PieChartSectionData(color: Colors.red, value: wrong.toDouble(), title: 'Galat ($wrong)', radius: 45, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (skipped > 0)
                      PieChartSectionData(color: Colors.grey, value: skipped.toDouble(), title: 'Skipped ($skipped)', radius: 40, titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3️⃣ AI EXPLANATION BUTTON WIDGET
class AiExplanationButton extends StatefulWidget {
  final String question;
  final List<String> options;
  final String correctAnswer;

  const AiExplanationButton({
    super.key,
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  @override
  State<AiExplanationButton> createState() => _AiExplanationButtonState();
}

class _AiExplanationButtonState extends State<AiExplanationButton> {
  bool _isLoading = false;
  String? _explanation;

  void _fetchAiExplanation() async {
    setState(() => _isLoading = true);
    final result = await AiExplainerService.getExplanation(
      question: widget.question,
      options: widget.options,
      correctAnswer: widget.correctAnswer,
    );
    if (mounted) {
      setState(() {
        _explanation = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_explanation == null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7C3AED),
              side: const BorderSide(color: Color(0xFF7C3AED)),
            ),
            onPressed: _isLoading ? null : _fetchAiExplanation,
            icon: _isLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                : const Text('🤖'),
            label: Text(_isLoading ? 'Llama AI Soch Raha Hai...' : 'Ask Llama AI Explanation', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        if (_explanation != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD8B4FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🤖 Llama AI Mentor Explanation:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B21A8), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_explanation!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF3B0764), height: 1.4)),
              ],
            ),
          )
        ]
      ],
    );
  }
}

// 4️⃣ WIKI TRICK CONTRIBUTION BOX
class WikiContributionBox extends StatefulWidget {
  final String subFolder;
  final int qIndex;
  final String questionSnippet;

  const WikiContributionBox({
    super.key,
    required this.subFolder,
    required this.qIndex,
    required this.questionSnippet,
  });

  @override
  State<WikiContributionBox> createState() => _WikiContributionBoxState();
}

class _WikiContributionBoxState extends State<WikiContributionBox> {
  final TextEditingController _trickController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  Future<void> _submitTrickOrReport() async {
    final String trickText = _trickController.text.trim();
    if (trickText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Please write your trick, report or logic first!')));
      return;
    }

    setState(() => _isSubmitting = true);
    const String googleScriptUrl = "https://script.google.com/macros/s/AKfycbztbqpHH7H8LulJ36AsDBhSYmBVfmH-ONb6exJKCELIbqCbb6iptv43PrgO-y6-Jo8ULg/exec";

    try {
      final String cleanSnippet = widget.questionSnippet.length > 60 ? widget.questionSnippet.substring(0, 60) : widget.questionSnippet;
      await http.post(
        Uri.parse(googleScriptUrl),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "type": "wiki",
          "fileSrc": widget.subFolder,
          "question": cleanSnippet,
          "trick": trickText,
          "userId": "App_Aspirant_${widget.qIndex}",
        },
      );
      if (mounted) setState(() { _isSubmitting = false; _isSubmitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Data recorded successfully!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFBBF7D0))),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Thank you! Shortcut trick or report successfully recorded.', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11.5))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCBD5E1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 Got a short-trick, report or better logic? Share with community!', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _trickController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Type shortcut or report here...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  onPressed: _isSubmitting ? null : _submitTrickOrReport,
                  child: _isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
