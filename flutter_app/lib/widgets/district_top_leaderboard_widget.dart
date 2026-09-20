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
      debugPrint("District Leaderboard fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ Data nahi hoga toh koi empty space ya blank dabba render nahi hoga
    if (_isLoading || _topRankers.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subText = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🏆 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'Top 5 Duel Ranks',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                  ),
                ],
              ),
              // District Dropdown Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDistrict,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.amber.shade300 : const Color(0xFF4F28EB),
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
          const SizedBox(height: 12),

          // Top 5 Ranks
          ...List.generate(_topRankers.length, (idx) {
            final item = _topRankers[idx];
            final rank = idx + 1;
            final badge = rank == 1
                ? '🥇'
                : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '#$rank'));

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: rank == 1 ? Colors.amber.withValues(alpha: 0.35) : borderCol,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: rank <= 3 ? 14 : 11.5,
                        fontWeight: FontWeight.w800,
                        color: subText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (item['user_name'] ?? 'Candidate').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textCol,
                      ),
                    ),
                  ),
                  Text(
                    '${item['score'] ?? 0}/10',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item['time_taken_seconds'] ?? 0}s',
                    style: TextStyle(fontSize: 11, color: subText),
                  ),
                ],
              ),
            );
          }),

          // View All Button
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
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'View All Districts Ranklist →',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.amber.shade300 : const Color(0xFF4F28EB),
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
