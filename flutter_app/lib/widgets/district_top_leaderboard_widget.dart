import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/district_leaderboard_screen.dart';

class DistrictTopLeaderboardWidget extends StatefulWidget {
  final bool isDarkMode;

  const DistrictTopLeaderboardWidget({super.key, required this.isDarkMode});

  @override
  State<DistrictTopLeaderboardWidget> createState() =>
      _DistrictTopLeaderboardWidgetState();
}

class _DistrictTopLeaderboardWidgetState
    extends State<DistrictTopLeaderboardWidget> {
  final List<String> _biharDistricts = const [
    'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur', 'Bhojpur',
    'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj', 'Jamui', 'Jehanabad',
    'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj', 'Lakhisarai', 'Madhepura',
    'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda', 'Nawada', 'Patna', 'Purnia',
    'Rohtas', 'Saharsa', 'Samastipur', 'Saran', 'Sheikhpura', 'Sheohar',
    'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali', 'West Champaran'
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
    final savedDistrict = prefs.getString('user_district')?.trim() ?? 'Patna';

    if (mounted) {
      setState(() {
        _selectedDistrict =
            _biharDistricts.contains(savedDistrict) ? savedDistrict : 'Patna';
      });
      _fetchDistrictLeaderboard(_selectedDistrict);
    }
  }

  Future<void> _fetchDistrictLeaderboard(String district) async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('daily_challenge_submissions')
          .select('user_name, district, score, time_taken_seconds')
          .eq('district', district)
          .order('score', ascending: false)
          .order('time_taken_seconds', ascending: true)
          .limit(5);

      if (mounted) {
        setState(() {
          _topRankers = List<Map<String, dynamic>>.from(res ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("District Leaderboard error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _topRankers.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = widget.isDarkMode;
    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF5F3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final borderColor = isDark ? const Color(0xFF312E81) : const Color(0xFFDDD6FE);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      // Edge-to-edge: margin 0 horizontal
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔴 1. Arena Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFFDC2626)),
                        SizedBox(width: 5),
                        Text(
                          'LIVE BATTLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC2626),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'District Leaderboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),

              // District Dropdown Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDistrict,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4F46E5),
                    ),
                    items: _biharDistricts.map((String d) {
                      return DropdownMenuItem(value: d, child: Text(d));
                    }).toList(),
                    onChanged: (newDist) {
                      if (newDist != null && newDist != _selectedDistrict) {
                        setState(() => _selectedDistrict = newDist);
                        _fetchDistrictLeaderboard(newDist);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ⚡ 2. Competitive Top 5 Ranks
          ...List.generate(_topRankers.length, (idx) {
            final item = _topRankers[idx];
            final rank = idx + 1;
            final isRank1 = rank == 1;
            final isRank2 = rank == 2;
            final isRank3 = rank == 3;

            final name = (item['user_name'] ?? 'Aspirant').toString();
            final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

            Color rankColor;
            String badgeEmoji;
            if (isRank1) {
              rankColor = const Color(0xFFF59E0B);
              badgeEmoji = '👑';
            } else if (isRank2) {
              rankColor = const Color(0xFF94A3B8);
              badgeEmoji = '🥈';
            } else if (isRank3) {
              rankColor = const Color(0xFFD97706);
              badgeEmoji = '🥉';
            } else {
              rankColor = textMuted;
              badgeEmoji = '#$rank';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isRank1
                    ? (isDark
                        ? const Color(0xFF78350F).withValues(alpha: 0.25)
                        : const Color(0xFFFEF3C7).withValues(alpha: 0.5))
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRank1
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                      : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
                  width: isRank1 ? 1.4 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isRank1
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.02),
                    blurRadius: isRank1 ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rank Badge / Emoji
                  SizedBox(
                    width: 26,
                    child: Text(
                      badgeEmoji,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isRank1 || isRank2 || isRank3 ? 15 : 12,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Avatar with First Letter
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isRank1
                        ? const Color(0xFFF59E0B)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF)),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isRank1
                            ? Colors.black87
                            : (isDark ? Colors.white : const Color(0xFF4F46E5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // User Name & District
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isRank1 ? FontWeight.w900 : FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '${item['district'] ?? _selectedDistrict} District',
                          style: TextStyle(fontSize: 10.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),

                  // Score Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item['score'] ?? 0}/10',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Time Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item['time_taken_seconds'] ?? 0}s',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // 🚀 3. Footer Action Strip
          const SizedBox(height: 6),
          InkWell(
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
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Full Bihar State Ranklist',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
