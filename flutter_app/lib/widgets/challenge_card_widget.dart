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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const accent = Color(0xFFD97706);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.055),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.emoji_events_rounded, size: 23, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAILY CHALLENGE',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Dost ke saath 1v1 mukabla',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: Color(0xFF16A34A)),
                    SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: TextStyle(color: Color(0xFF15803D), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Challenge Your Friend',
            style: TextStyle(
              color: titleColor,
              fontSize: 20.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '10 rapid sawal, har sawal 15 second — dost ko challenge karo aur district ranking me aage badho.',
            style: TextStyle(
              color: muted,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Tum vs Dost — mukable ki tasveer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.45), width: 1.4),
                    ),
                    child: const Icon(Icons.person_rounded, size: 24, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'TUM',
                    style: TextStyle(color: titleColor, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 18),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF451A03)),
                ),
              ),
              Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: isDark ? 0.25 : 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.4), width: 1.4),
                    ),
                    child: Icon(Icons.person_rounded, size: 24, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'DOST',
                    style: TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _infoChip(Icons.people_alt_rounded, '1v1 Duel', const Color(0xFF2563EB), isDark),
              _infoChip(Icons.timer_outlined, '10 Qs • 15 sec each', const Color(0xFF64748B), isDark),
              _infoChip(Icons.leaderboard_rounded, 'District Rank', const Color(0xFFD97706), isDark),
            ],
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startNewChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF451A03),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF451A03)),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_kabaddi_rounded, size: 20, color: Color(0xFF451A03)),
                        SizedBox(width: 7),
                        Text(
                          'Start Challenge',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF451A03)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF334155),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
