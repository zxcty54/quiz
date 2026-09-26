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
  final List<String> _biharDistricts = const [
    'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur',
    'Bhojpur', 'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj',
    'Jamui', 'Jehanabad', 'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj',
    'Lakhisarai', 'Madhepura', 'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda',
    'Nawada', 'Patna', 'Purnia', 'Rohtas', 'Saharsa', 'Samastipur', 'Saran',
    'Sheikhpura', 'Sheohar', 'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali',
    'West Champaran',
  ];

  String _selectedDistrict = 'Patna';
  bool _isLoading = true;
  List<Map<String, dynamic>> _topRankers = [];

  @override
  void initState() {
    super.initState();
    _initUserDistrict();
  }

  Future<void> _initUserDistrict() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDistrict =
        prefs.getString('user_district')?.trim() ?? 'Patna';

    final district = _biharDistricts.contains(savedDistrict)
        ? savedDistrict
        : 'Patna';

    if (!mounted) return;
    setState(() {
      _selectedDistrict = district;
    });

    await _fetchDistrictLeaderboard(district);
  }

  // BULLETPROOF SUPABASE QUERY (UNCHANGED)
  Future<void> _fetchDistrictLeaderboard(String district) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final res = await Supabase.instance.client
          .from('daily_challenge_submissions')
          .select(
            'user_name, district, score, time_taken_seconds',
          )
          .eq('district', district)
          .order('score', ascending: false)
          .order('time_taken_seconds', ascending: true)
          .limit(5);

      if (!mounted) return;
      setState(() {
        _topRankers = List<Map<String, dynamic>>.from(res);
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
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 18,
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
                        backgroundColor: Color(0xFFE2E8F0),
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

                const SizedBox(height: 10),

                // Sticky Current User Rank Bar (Crystal Clear Contrast)
                _buildUserStickyBar(isDark),

                const SizedBox(height: 10),

                // View All Bihar Districts CTA
                _buildFullRanklistButton(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          // Trophy icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFDE047),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),

          // Title + District
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      'District Leaderboard',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    _buildLiveBadge(isDark),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$_selectedDistrict District',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Share Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _shareLeaderboard,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.share_rounded,
                      size: 14,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF15803D),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB BADGE
  // ============================================================
  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'Top 5 Hall of Fame',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PODIUM CARDS (Top 1, 2, 3)
  // ============================================================
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
    Color cardBgColor;

    if (rank == 1) {
      badgeBgColor = const Color(0xFFF59E0B);
      borderColor = const Color(0xFFF59E0B);
      cardBgColor = isDark ? const Color(0xFF1E1A11) : const Color(0xFFFFFBEB);
    } else if (rank == 2) {
      badgeBgColor = const Color(0xFF64748B);
      borderColor = const Color(0xFF94A3B8);
      cardBgColor = isDark ? const Color(0xFF171D27) : const Color(0xFFF8FAFC);
    } else {
      badgeBgColor = const Color(0xFFD97706);
      borderColor = const Color(0xFFD97706);
      cardBgColor = isDark ? const Color(0xFF1E1611) : const Color(0xFFFFF7ED);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor.withOpacity(isDark ? 0.45 : 0.4),
          width: rank == 1 ? 1.4 : 1.1,
        ),
      ),
      child: Row(
        children: [
          // Rank Medal Circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeBgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: badgeBgColor.withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech_rounded, size: 15, color: Colors.white),
                Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Name & District
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
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Score Badge & Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF064E3B).withOpacity(0.6)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF059669).withOpacity(0.6)
                        : const Color(0xFF86EFAC),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 12,
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$score/10',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 11,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${time}s',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

  // ============================================================
  // ROWS (Rank 4 & 5)
  // ============================================================
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
            width: 26,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name.isEmpty ? 'Candidate' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            '$score/10',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${time}s',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USER STICKY BAR (Ultra Crisp in Light & Dark Mode)
  // ============================================================
  Widget _buildUserStickyBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF063A34) : const Color(0xFF042F2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF14B8A6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF042F2C).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // #Me Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '#Me',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 9),

          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your Today's Rank in $_selectedDistrict",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Check accuracy & analyze mistakes",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5EEAD4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // High-Visibility Button
          ElevatedButton(
            onPressed: widget.onReviewMistakes ?? widget.onTakeQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 0),
              minimumSize: const Size(64, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text(
              'Review Mistakes',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FULL BIHAR CTA
  // ============================================================
  Widget _buildFullRanklistButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 17, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'View All 38 Bihar Districts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF6366F1)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING STATE
  // ============================================================
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

  // ============================================================
  // EMPTY STATE WITH CTA
  // ============================================================
  Widget _buildEmptyCard(bool isDark) {
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
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
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
              fontSize: 14,
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
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: widget.onTakeQuiz,
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text(
              'Play Challenge',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
