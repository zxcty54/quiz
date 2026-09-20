import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/challenge_quiz_screen.dart';
import '../screens/district_leaderboard_screen.dart';
import '../services/challenge_service.dart';

class ChallengeCardWidget extends StatefulWidget {
  final bool isDarkMode;

  const ChallengeCardWidget({super.key, required this.isDarkMode});

  @override
  State<ChallengeCardWidget> createState() => _ChallengeCardWidgetState();
}

class _ChallengeCardWidgetState extends State<ChallengeCardWidget> {
  bool _isLoading = false;
  bool _isLoadingLeaderboard = true;

  // 🏆 Live District Toppers Data
  List<Map<String, String>> _topDistricts = [];

  @override
  void initState() {
    super.initState();
    _fetchLiveLeaderboardPreview();
  }

  // 🔄 Supabase se Aaj ke Top 3 Rankers Fetch Karne Ka Logic
  Future<void> _fetchLiveLeaderboardPreview() async {
    try {
      final todayDate = DateTime.now().toIso8601String().substring(0, 10);

      final response = await Supabase.instance.client
          .from('daily_challenge_submissions')
          .select('user_name, district, score, time_taken_seconds')
          .eq('challenge_date', todayDate)
          .order('score', ascending: false)
          .order('time_taken_seconds', ascending: true)
          .limit(3);

      if (mounted && response.isNotEmpty) {
        setState(() {
          _topDistricts = (response as List).map<Map<String, String>>((item) {
            int index = response.indexOf(item);
            String badge = index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉");
            return {
              "rank": "${index + 1}",
              "name": item['user_name']?.toString() ?? '',
              "district": item['district']?.toString() ?? '',
              "score": "${item['score']}/10",
              "badge": badge,
            };
          }).toList();
          _isLoadingLeaderboard = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("Leaderboard preview fetch error: $e");
    }

    if (mounted) {
      setState(() => _isLoadingLeaderboard = false);
    }
  }

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

      // Quiz dekar bahar aate hi card ke toppers refresh karein
      _fetchLiveLeaderboardPreview();
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

  void _navigateToLeaderboard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DistrictLeaderboardScreen(
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
    // Leaderboard screen se wapas aane par refresh karein
    _fetchLiveLeaderboardPreview();
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ Filter valid items: Jis item me name genuinely ho sirf wahi render ho
    final validDistricts = _topDistricts
        .where((d) => (d['name'] ?? '').trim().isNotEmpty)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
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
          // 1. Header Section
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

          // 🏆 2. LIVE LEADERBOARD PREVIEW STRIP (Sirf tabhi aayega jab data hoga)
          if (!_isLoadingLeaderboard && validDistricts.isNotEmpty) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: _navigateToLeaderboard,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.leaderboard_rounded, size: 14, color: Color(0xFFFBBF24)),
                            const SizedBox(width: 5),
                            Text(
                              'DISTRICT TOPPERS',
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'Full Ranklist',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 9, color: Colors.white.withValues(alpha: 0.6)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Podiums: 1 naam ho, 2 hon ya 3 hon, perfectly adjust hoga
                    Row(
                      children: validDistricts.map((item) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item["badge"] ?? '🎖️', style: const TextStyle(fontSize: 11)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        item["name"]!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item["score"]!,
                                  style: const TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ⚡ 3. Start Quiz Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startNewChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4F46E5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF4F46E5)),
                        SizedBox(width: 6),
                        Text(
                          'Start 1v1 Daily Duel 🚀',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
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
