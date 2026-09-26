import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/district_leaderboard_screen.dart';

class DistrictTopLeaderboardWidget extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onTakeQuiz;
  final VoidCallback? onReviewMistakes;

  const DistrictTopLeaderboardWidget({
    super.key,
    required this.isDarkMode,
    this.onTakeQuiz,
    this.onReviewMistakes,
  });

  @override
  State<DistrictTopLeaderboardWidget> createState() =>
      _DistrictTopLeaderboardWidgetState();
}

class _DistrictTopLeaderboardWidgetState
    extends State<DistrictTopLeaderboardWidget> {
  String _selectedDistrict = 'Patna';
  bool _isLoading = true;
  List<Map<String, dynamic>> _topRankers = [];
  Map<String, dynamic>? _currentUserSubmission;
  int? _currentUserRank;
  int _totalDistrictParticipants = 0;

  @override
  void initState() {
    super.initState();
    _initUserDistrict();
  }

  Future<void> _initUserDistrict() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDistrict = prefs.getString('user_district')?.trim() ?? 'Patna';

    if (!mounted) return;
    setState(() {
      _selectedDistrict = savedDistrict.isNotEmpty ? savedDistrict : 'Patna';
    });

    await _fetchDistrictLeaderboard(_selectedDistrict);
  }

  Future<void> _fetchDistrictLeaderboard(String district) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final client = Supabase.instance.client;

      // 1. Top 5 Fetch
      final res = await client
          .from('daily_challenge_submissions')
          .select('user_id, user_name, district, score, time_taken_seconds')
          .eq('district', district)
          .order('score', ascending: false)
          .order('time_taken_seconds', ascending: true)
          .limit(5);

      // 2. Current User Submission
      final currentUserId = client.auth.currentUser?.id;
      Map<String, dynamic>? mySub;
      int? myRank;
      int totalCount = 0;

      if (currentUserId != null) {
        final myRes = await client
            .from('daily_challenge_submissions')
            .select()
            .eq('user_id', currentUserId)
            .eq('district', district)
            .maybeSingle();

        mySub = myRes;

        if (mySub != null) {
          final higherRankersCount = await client
              .from('daily_challenge_submissions')
              .count(CountOption.exact)
              .eq('district', district)
              .or(
                'score.gt.${mySub['score']},and(score.eq.${mySub['score']},time_taken_seconds.lt.${mySub['time_taken_seconds']})',
              );

          myRank = higherRankersCount + 1;
        }
      }

      // 3. Total Participants
      totalCount = await client
          .from('daily_challenge_submissions')
          .count(CountOption.exact)
          .eq('district', district);

      if (!mounted) return;
      setState(() {
        _topRankers = List<Map<String, dynamic>>.from(res);
        _currentUserSubmission = mySub;
        _currentUserRank = myRank;
        _totalDistrictParticipants = totalCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('District Leaderboard error: $e');
      if (!mounted) return;
      setState(() {
        _topRankers = [];
        _isLoading = false;
      });
    }
  }

  void _shareLeaderboard() {
    if (_topRankers.isEmpty) return;
    final top1 = _topRankers.first;
    final text = "🏆 *$_selectedDistrict Leaderboard Topper!*\n"
        "🥇 *${top1['user_name']}* scored ${top1['score']}/10 in ${top1['time_taken_seconds']}s! ⚡\n"
        "Can you beat their record? Check rank on MockTester.Online!";
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copied $_selectedDistrict Leaderboard to clipboard! 📋"),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    if (_isLoading && _topRankers.isEmpty) {
      return _buildLoadingCard(isDark);
    }

    if (!_isLoading && _topRankers.isEmpty) {
      return _buildEmptyCard(isDark);
    }

    final top3 = _topRankers.take(3).toList();
    final remainingRankers = _topRankers.skip(3).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1523) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          _buildTabBar(isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: Color(0xFF6366F1),
                        backgroundColor: Color(0xFF1E293B),
                      ),
                    ),
                  ),

                // Top 3 Podium Cards
                ...List.generate(top3.length, (index) {
                  return _buildPodiumRankCard(
                    item: top3[index],
                    rank: index + 1,
                    isDark: isDark,
                  );
                }),

                // Rank 4 & 5 Rows
                ...List.generate(remainingRankers.length, (index) {
                  return _buildRegularRankRow(
                    item: remainingRankers[index],
                    rank: index + 4,
                    isDark: isDark,
                  );
                }),

                const SizedBox(height: 12),

                // Sticky Current User Bottom Bar
                _buildUserStickyBar(isDark),

                const SizedBox(height: 10),

                // View All Districts Leaderboard Button
                _buildFullRanklistButton(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Header Section
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFBBF24),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'District Leaderboard',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildLiveBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$_selectedDistrict District',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _shareLeaderboard,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.share_outlined,
                    size: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Share',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 5, color: Color(0xFF10B981)),
          SizedBox(width: 3),
          Text(
            'LIVE RANK',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: Color(0xFF34D399),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // Tabs: Top 5 Hall of Fame & District Stats
  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Top 5 Hall of Fame',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 14,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                'District Stats ($_totalDistrictParticipants)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Top 3 Elevated Cards
  Widget _buildPodiumRankCard({
    required Map<String, dynamic> item,
    required int rank,
    required bool isDark,
  }) {
    final name = (item['user_name'] ?? 'Candidate').toString().trim();
    final score = item['score'] ?? 0;
    final time = item['time_taken_seconds'] ?? 0;

    Color badgeBgColor;
    Color borderColor;

    if (rank == 1) {
      badgeBgColor = const Color(0xFFF59E0B);
      borderColor = const Color(0xFFD97706);
    } else if (rank == 2) {
      badgeBgColor = const Color(0xFF94A3B8);
      borderColor = const Color(0xFF64748B);
    } else {
      badgeBgColor = const Color(0xFFD97706);
      borderColor = const Color(0xFFB45309);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? borderColor.withOpacity(0.45)
              : borderColor.withOpacity(0.35),
          width: rank == 1 ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: badgeBgColor,
              shape: BoxShape.circle,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech_rounded, size: 16, color: Colors.white),
                Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Candidate' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['district'] ?? _selectedDistrict,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF059669).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 11, color: Color(0xFF34D399)),
                    const SizedBox(width: 3),
                    Text(
                      '$score/10',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 10, color: Color(0xFF64748B)),
                  const SizedBox(width: 2),
                  Text(
                    '${time}s',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Rank 4 & 5 Simple Rows
  Widget _buildRegularRankRow({
    required Map<String, dynamic> item,
    required int rank,
    required bool isDark,
  }) {
    final name = (item['user_name'] ?? 'Candidate').toString().trim();
    final score = item['score'] ?? 0;
    final time = item['time_taken_seconds'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name.isEmpty ? 'Candidate' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
          Text(
            '$score/10',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${time}s',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // Sticky User Status Bar
  Widget _buildUserStickyBar(bool isDark) {
    if (_currentUserSubmission != null) {
      final myScore = _currentUserSubmission!['score'] ?? 0;
      final myTime = _currentUserSubmission!['time_taken_seconds'] ?? 0;
      final displayRank = _currentUserRank ?? 1;

      double percentile = 100.0;
      if (_totalDistrictParticipants > 0) {
        percentile = (displayRank / _totalDistrictParticipants) * 100;
      }
      final cleanPercentile = percentile.toStringAsFixed(1);

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF042F2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$displayRank',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Today's Rank in $_selectedDistrict",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Score: $myScore/10 (${myTime}s) • Top $cleanPercentile%",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5EEAD4),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: widget.onReviewMistakes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(60, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Review Mistakes',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    // Agar user ne quiz attempt nahi kiya hai
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF312E81).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              "You haven't taken today's test!",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA5B4FC),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: widget.onTakeQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Start 🚀',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // Full Bihar Ranklist Button
  Widget _buildFullRanklistButton(bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DistrictLeaderboardScreen(
              isDarkMode: widget.isDarkMode,
              userDistrict: _selectedDistrict,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.leaderboard_rounded, size: 15, color: Color(0xFF6366F1)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'View All 38 Bihar Districts',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  // Loading State
  Widget _buildLoadingCard(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1523) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF6366F1),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Loading leaderboard...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // Empty State
  Widget _buildEmptyCard(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1523) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: Color(0xFF6366F1),
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No rankings yet in $_selectedDistrict',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to appear on the leaderboard!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: widget.onTakeQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Play Today\'s Challenge',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
