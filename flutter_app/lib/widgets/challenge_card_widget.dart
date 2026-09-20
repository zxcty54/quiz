import 'package:flutter/material.dart';
import '../screens/challenge_quiz_screen.dart';
import '../services/challenge_service.dart';

class ChallengeCardWidget extends StatefulWidget {
  final bool isDarkMode;

  const ChallengeCardWidget({super.key, required this.isDarkMode});

  @override
  State<ChallengeCardWidget> createState() => _ChallengeCardWidgetState();
}

class _ChallengeCardWidgetState extends State<ChallengeCardWidget> {
  bool _isLoading = false;

  Future<void> _startNewChallenge() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final challengeData = await ChallengeService.generateDailyChallenge();
      if (!mounted) return;

      final List questions = challengeData['questions'] ?? [];

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Sawaal load nahi ho paye. Kripya internet check karein!'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChallengeQuizScreen(
            questions: List<Map<String, dynamic>>.from(questions),
            challengeCode: challengeData['challenge_code'] ?? '',
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test shuru karne me samasya aayi: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('⚔️', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1v1 Daily Duel Challenge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '10 Rapid Questions • 15s per question',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Direct Start Button (No Leaderboard Strip Inside Card)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startNewChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4F46E5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF4F46E5)),
                        SizedBox(width: 6),
                        Text(
                          'Start 1v1 Daily Duel 🚀',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
