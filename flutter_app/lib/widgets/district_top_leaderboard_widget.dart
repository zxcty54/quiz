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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF111827), const Color(0xFF1E1B4B)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEEF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏆 1. Top Header Row (Title & District Selector neatly aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFFDC2626)),
                        SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'District Leaderboard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              // District Dropdown (Compact & never overflows)
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDistrict,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF4F46E5)),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
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

          // ⚡ 2. Leaderboard Ranks Cards
          ...List.generate(_topRankers.length, (idx) {
            final item = _topRankers[idx];
            final rank = idx + 1;
            final isRank1 = rank == 1;
            final isRank2 = rank == 2;

            final name = (item['user_name'] ?? 'Candidate').toString();
            final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: isRank1
                    ? const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isRank1
                    ? null
                    : (isDark ? const Color(0xFF1F2937) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRank1
                      ? const Color(0xFFF59E0B)
                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  width: isRank1 ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isRank1
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rank Crown / Emoji
                  Text(
                    isRank1 ? '👑' : (isRank2 ? '🥈' : (rank == 3 ? '🥉' : '#$rank')),
                    style: TextStyle(
                      fontSize: rank <= 3 ? 15 : 12,
                      fontWeight: FontWeight.w900,
                      color: isRank1 ? const Color(0xFFD97706) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Initial Circle
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isRank1
                        ? const Color(0xFFF59E0B)
                        : (isDark ? const Color(0xFF374151) : const Color(0xFFE0E7FF)),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isRank1 ? Colors.white : const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Name & District
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${item['district'] ?? _selectedDistrict} District',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Score Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item['score'] ?? 0}/10',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Time Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item['time_taken_seconds'] ?? 0}s',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // 🚀 3. Footer Link
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Full Bihar State Ranklist →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
