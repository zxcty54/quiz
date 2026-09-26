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
    extends State<DistrictTopLeaderboardWidget> with WidgetsBindingObserver {
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
  
  // State Overall Topper (All Bihar #1)
  Map<String, dynamic>? _stateTopper;
  
  // District Level Rankers
  List<Map<String, dynamic>> _topRankers = [];

  // Dynamic User Rank Performance Data
  String _currentUserName = 'Aspirant';
  int _userScore = 0;
  int _userTime = 0;
  int _userRank = 0;
  bool _hasAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAndLoadLeaderboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initAndLoadLeaderboard();
    }
  }

  Future<void> _initAndLoadLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final client = Supabase.instance.client;

    final savedDistrict = prefs.getString('user_district')?.trim() ?? 'Patna';
    final district = _biharDistricts.contains(savedDistrict) ? savedDistrict : 'Patna';
    final localUserId = prefs.getString('user_id')?.trim();

    String standardName = prefs.getString('user_name')?.trim() ??
        prefs.getString('custom_aspirant_name')?.trim() ??
        '';

    if ((standardName.isEmpty || standardName == 'Aspirant') && localUserId != null) {
      try {
        final userRow = await client
            .from('app_users')
            .select('full_name')
            .eq('user_id', localUserId)
            .maybeSingle();

        if (userRow != null && userRow['full_name'] != null) {
          final dbName = userRow['full_name'].toString().trim();
          if (dbName.isNotEmpty) {
            standardName = dbName;
            await prefs.setString('user_name', dbName);
            await prefs.setString('custom_aspirant_name', dbName);
          }
        }
      } catch (e) {
        debugPrint('app_users sync fallback error: $e');
      }
    }

    if (standardName.isEmpty) standardName = 'Aspirant';

    final cachedScore = prefs.getInt('last_sub_score');
    final cachedTime = prefs.getInt('last_sub_time') ?? 0;

    if (mounted) {
      setState(() {
        _selectedDistrict = district;
        _currentUserName = standardName;
        if (cachedScore != null) {
          _userScore = cachedScore;
          _userTime = cachedTime > 0 ? cachedTime : 15;
          _hasAttempted = true;
        }
      });
    }

    await _fetchLeaderboardData(district, localUserId, standardName);
  }

  Future<void> _fetchLeaderboardData(
    String district,
    String? localUserId,
    String standardName,
  ) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;

      // 🌟 1. FETCH OVERALL BIHAR TOPPER (No district filter)
      final stateRes = await client
          .from('daily_challenge_submissions')
          .select('user_name, district, score, time_taken_seconds')
          .order('score', ascending: false)
          .order('time_taken_seconds', ascending: true)
          .limit(1);

      Map<String, dynamic>? overallTopper;
      if (stateRes != null && stateRes.isNotEmpty) {
        overallTopper = Map<String, dynamic>.from(stateRes.first);
      }

      // 📍 2. FETCH DISTRICT TOP 50
      final res = await client
          .from('daily_challenge_submissions')
          .select('user_id, user_name, district, score, time_taken_seconds')
          .eq('district', district)
          .order('score', ascending: false)
          .order('time_taken_seconds', ascending: true)
          .limit(50);

      final List<Map<String, dynamic>> allRankers =
          List<Map<String, dynamic>>.from(res ?? []);

      int foundRank = 0;
      int myScore = 0;
      int myTime = 0;
      bool userFound = false;

      final normalizedTargetName = standardName.trim().toLowerCase();

      // Search user in district list
      for (int i = 0; i < allRankers.length; i++) {
        final row = allRankers[i];
        final rowUid = row['user_id']?.toString().trim();
        final rowName = (row['user_name'] ?? '').toString().trim().toLowerCase();

        bool isMe = false;
        if (localUserId != null && localUserId.isNotEmpty && rowUid == localUserId) {
          isMe = true;
        } else if (normalizedTargetName.isNotEmpty && rowName == normalizedTargetName) {
          isMe = true;
        }

        if (isMe) {
          foundRank = i + 1;
          myScore = (row['score'] ?? 0) as int;
          final int rawTime = (row['time_taken_seconds'] ?? 0) as int;
          myTime = rawTime > 0 ? rawTime : 15;
          userFound = true;
          break;
        }
      }

      // Fallback: If outside top 50
      if (!userFound) {
        var query = client
            .from('daily_challenge_submissions')
            .select('user_id, user_name, score, time_taken_seconds')
            .eq('district', district);

        if (localUserId != null && localUserId.isNotEmpty) {
          query = query.eq('user_id', localUserId);
        } else if (normalizedTargetName.isNotEmpty) {
          query = query.ilike('user_name', standardName.trim());
        }

        final myRes = await query.limit(1);

        if (myRes.isNotEmpty) {
          final sub = myRes.first;
          myScore = (sub['score'] ?? 0) as int;
          final int rawTime = (sub['time_taken_seconds'] ?? 0) as int;
          myTime = rawTime > 0 ? rawTime : 15;

          final higherCount = await client
              .from('daily_challenge_submissions')
              .count(CountOption.exact)
              .eq('district', district)
              .gt('score', myScore);

          final sameScoreFaster = await client
              .from('daily_challenge_submissions')
              .count(CountOption.exact)
              .eq('district', district)
              .eq('score', myScore)
              .lt('time_taken_seconds', myTime);

          foundRank = higherCount + sameScoreFaster + 1;
          userFound = true;
        }
      }

      // Local Cache Fallback
      final prefs = await SharedPreferences.getInstance();
      final cachedScore = prefs.getInt('last_sub_score');
      final cachedTime = prefs.getInt('last_sub_time') ?? 0;

      if (!userFound && cachedScore != null) {
        userFound = true;
        myScore = cachedScore;
        myTime = cachedTime > 0 ? cachedTime : 15;
        foundRank = allRankers.length > 5 ? allRankers.length : 1;
      }

      List<Map<String, dynamic>> finalRankers = allRankers.take(5).toList();
      if (finalRankers.isEmpty && userFound) {
        finalRankers = [
          {
            'user_name': standardName,
            'district': district,
            'score': myScore,
            'time_taken_seconds': myTime,
          }
        ];
      }

      if (!mounted) return;
      setState(() {
        _stateTopper = overallTopper;
        _topRankers = finalRankers;
        if (userFound) {
          _userRank = foundRank;
          _userScore = myScore;
          _userTime = myTime;
          _hasAttempted = true;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Leaderboard sync error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _shareLeaderboard() {
    if (_stateTopper == null && _topRankers.isEmpty) return;
    final top = _stateTopper ?? _topRankers.first;
    final text = "🏆 *Bihar GK Challenge Topper!*\n"
        "🥇 *${top['user_name']}* (${top['district']}) scored ${top['score']}/10 in ${top['time_taken_seconds']}s! ⚡\n"
        "Check your district rank on MockTester.Online!";
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Copied Leaderboard to clipboard! 📋"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    if (_isLoading && _topRankers.isEmpty && _stateTopper == null) {
      return _buildLoadingCard(isDark);
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

          // 👑 1. OVERALL BIHAR CHAMPION CARD
          if (_stateTopper != null) _buildStateChampionCard(isDark),

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

                // Top 3 Podium Cards in User District
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

                // 🌟 User's Local District Rank Bar (Clean - No Review Button)
                _buildUniformUserStatusBar(isDark),

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      'Daily Challenge',
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
                      '$_selectedDistrict District Leaderboard',
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

  // ============================================================
  // 👑 STATE OVERALL CHAMPION CARD
  // ============================================================
  Widget _buildStateChampionCard(bool isDark) {
    final name = (_stateTopper!['user_name'] ?? 'Candidate').toString().trim();
    final district = (_stateTopper!['district'] ?? 'Bihar').toString().trim();
    final score = _stateTopper!['score'] ?? 0;
    final int rawTime = (_stateTopper!['time_taken_seconds'] ?? 0) as int;
    final time = rawTime > 0 ? rawTime : 12;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF3B2506), const Color(0xFF201604)]
              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.25 : 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'BIHAR #1 TOPPER',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '• $district',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score/10',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF16A34A),
                ),
              ),
              Text(
                '${time}s',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF92400E),
                ),
              ),
            ],
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 5, color: Color(0xFF16A34A)),
          SizedBox(width: 3),
          Text(
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

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$_selectedDistrict Top 5',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PODIUM CARDS (Top 1, 2, 3 in District)
  // ============================================================
  Widget _buildPodiumRankCard({
    required Map<String, dynamic> item,
    required int rank,
    required bool isDark,
  }) {
    final name = (item['user_name'] ?? 'Candidate').toString().trim();
    final score = item['score'] ?? 0;
    final int rawTime = (item['time_taken_seconds'] ?? 0) as int;
    final time = rawTime > 0 ? rawTime : 15;

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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeBgColor,
              shape: BoxShape.circle,
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
    final int rawTime = (item['time_taken_seconds'] ?? 0) as int;
    final time = rawTime > 0 ? rawTime : 15;

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
  // UNIFORM USER STATUS BAR (Clean - Button Removed)
  // ============================================================
  Widget _buildUniformUserStatusBar(bool isDark) {
    final String rankLabel = _hasAttempted ? '#${_userRank > 0 ? _userRank : 1}' : '#0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF063A34) : const Color(0xFF042F2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF14B8A6), width: 1.2),
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
          // Rank Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hasAttempted ? const Color(0xFF0F766E) : const Color(0xFF334155),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rankLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User Performance Text (Full Width Clean Look)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your Rank in $_selectedDistrict",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _hasAttempted
                      ? "Score: $_userScore/10 (${_userTime > 0 ? _userTime : 15}s)"
                      : "Score: 0/10 (Not Attempted)",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _hasAttempted ? const Color(0xFF5EEAD4) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
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
          ).then((_) => _initAndLoadLeaderboard());
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
}
