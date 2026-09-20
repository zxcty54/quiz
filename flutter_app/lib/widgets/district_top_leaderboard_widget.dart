import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/district_leaderboard_screen.dart';

class DistrictTopLeaderboardWidget extends StatefulWidget {
  final bool isDarkMode;

  const DistrictTopLeaderboardWidget({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<DistrictTopLeaderboardWidget> createState() =>
      _DistrictTopLeaderboardWidgetState();
}

class _DistrictTopLeaderboardWidgetState
    extends State<DistrictTopLeaderboardWidget> {
  final List<String> _biharDistricts = const [
    'Araria',
    'Arwal',
    'Aurangabad',
    'Banka',
    'Begusarai',
    'Bhagalpur',
    'Bhojpur',
    'Buxar',
    'Darbhanga',
    'East Champaran',
    'Gaya',
    'Gopalganj',
    'Jamui',
    'Jehanabad',
    'Kaimur',
    'Katihar',
    'Khagaria',
    'Kishanganj',
    'Lakhisarai',
    'Madhepura',
    'Madhubani',
    'Munger',
    'Muzaffarpur',
    'Nalanda',
    'Nawada',
    'Patna',
    'Purnia',
    'Rohtas',
    'Saharsa',
    'Samastipur',
    'Saran',
    'Sheikhpura',
    'Sheohar',
    'Sitamarhi',
    'Siwan',
    'Supaul',
    'Vaishali',
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    if (_isLoading && _topRankers.isEmpty) {
      return _buildLoadingCard(isDark);
    }

    if (!_isLoading && _topRankers.isEmpty) {
      return _buildEmptyCard(isDark);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111827)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF273449)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.18 : 0.055,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(isDark),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              4,
              14,
              14,
            ),
            child: Column(
              children: [
                // Small loading indicator when changing/loading data
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        minHeight: 2,
                        color: Color(0xFF6366F1),
                        backgroundColor: Color(0xFFE5E7EB),
                      ),
                    ),
                  ),

                // Leaderboard rows
                ...List.generate(
                  _topRankers.length,
                  (index) {
                    return _buildRankItem(
                      item: _topRankers[index],
                      rank: index + 1,
                      isDark: isDark,
                    );
                  },
                ),

                const SizedBox(height: 4),

                // Full Bihar Ranklist
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
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        15,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF171D35),
                  Color(0xFF111827),
                ]
              : const [
                  Color(0xFFF8FAFF),
                  Color(0xFFFFFFFF),
                ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          // Trophy icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF4F46E5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(
                    alpha: 0.25,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),

          const SizedBox(width: 11),

          // Title + district
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Live
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'District Leaderboard',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),

                    const SizedBox(width: 7),

                    _liveBadge(),
                  ],
                ),

                const SizedBox(height: 4),

                // District name
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 11,
                      color: isDark
                          ? const Color(0xFFA5B4FC)
                          : const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '$_selectedDistrict • Today’s top performers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LIVE BADGE
  // ============================================================

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 5,
            color: Color(0xFF16A34A),
          ),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 8,
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
  // RANK ITEM
  // ============================================================

  Widget _buildRankItem({
    required Map<String, dynamic> item,
    required int rank,
    required bool isDark,
  }) {
    final name = (item['user_name'] ?? 'Candidate')
        .toString()
        .trim();

    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : 'A';

    final score = item['score'] ?? 0;
    final time = item['time_taken_seconds'] ?? 0;

    final isFirst = rank == 1;
    final isSecond = rank == 2;
    final isThird = rank == 3;

    final rankColor = isFirst
        ? const Color(0xFFF59E0B)
        : isSecond
            ? const Color(0xFF64748B)
            : isThird
                ? const Color(0xFFB45309)
                : const Color(0xFF94A3B8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        gradient: isFirst
            ? LinearGradient(
                colors: isDark
                    ? const [
                        Color(0xFF332B13),
                        Color(0xFF211D12),
                      ]
                    : const [
                        Color(0xFFFFFBEB),
                        Color(0xFFFFF7D6),
                      ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isFirst
            ? null
            : isDark
                ? const Color(0xFF1F2937)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFirst
              ? const Color(0xFFF5C451)
              : isDark
                  ? const Color(0xFF293548)
                  : const Color(0xFFE8EDF3),
          width: isFirst ? 1.2 : 1,
        ),
      ),
      child: Row(
        children: [
          // ----------------------------------------------------
          // Rank
          // ----------------------------------------------------

          SizedBox(
            width: 30,
            child: Center(
              child: isFirst || isSecond || isThird
                  ? Text(
                      isFirst
                          ? '🥇'
                          : isSecond
                              ? '🥈'
                              : '🥉',
                      style: const TextStyle(
                        fontSize: 18,
                      ),
                    )
                  : Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 8),

          // ----------------------------------------------------
          // Avatar
          // ----------------------------------------------------

          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isFirst
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFFBBF24),
                        Color(0xFFD97706),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFE0E7FF),
                        Color(0xFFC7D2FE),
                      ],
                    ),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isFirst
                      ? Colors.white
                      : const Color(0xFF4338CA),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ----------------------------------------------------
          // User Name + District
          // ----------------------------------------------------

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
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 2),

                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 10,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 3),

                    Flexible(
                      child: Text(
                        '${item['district'] ?? _selectedDistrict}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ----------------------------------------------------
          // Score + Time
          // ----------------------------------------------------

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$score/10',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 11,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${time}s',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
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

  // ============================================================
  // FULL BIHAR RANKLIST BUTTON
  // ============================================================

  Widget _buildFullRanklistButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
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
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE4E0FF),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
              ),

              const SizedBox(width: 9),

              // Text
              Expanded(
                child: Text(
                  'View Full Bihar Ranklist',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFA5B4FC)
                        : const Color(0xFF4F46E5),
                  ),
                ),
              ),

              // Arrow
              const Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: Color(0xFF6366F1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING CARD
  // ============================================================

  Widget _buildLoadingCard(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111827)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF273449)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.15 : 0.04,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 25,
            height: 25,
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
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyCard(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111827)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF273449)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1)
                  .withValues(alpha: 0.1),
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
            'No rankings yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? Colors.white
                  : const Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Be the first to appear on the leaderboard!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}