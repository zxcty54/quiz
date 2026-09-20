import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DistrictLeaderboardScreen extends StatefulWidget {
  final bool isDarkMode;
  final String userDistrict;

  const DistrictLeaderboardScreen({
    super.key,
    required this.isDarkMode,
    this.userDistrict = 'All Bihar',
  });

  @override
  State<DistrictLeaderboardScreen> createState() =>
      _DistrictLeaderboardScreenState();
}

class _DistrictLeaderboardScreenState extends State<DistrictLeaderboardScreen> {
  // 📍 Bihar ke sabhi 38 districts + All Bihar option
  final List<String> _districts = const [
    'All Bihar',
    'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur', 'Bhojpur',
    'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj', 'Jamui', 'Jehanabad',
    'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj', 'Lakhisarai', 'Madhepura',
    'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda', 'Nawada', 'Patna', 'Purnia',
    'Rohtas', 'Saharsa', 'Samastipur', 'Saran', 'Sheikhpura', 'Sheohar',
    'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali', 'West Champaran'
  ];

  late String _selectedDistrict;
  List<Map<String, dynamic>> _ranks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDistrict = _districts.contains(widget.userDistrict)
        ? widget.userDistrict
        : 'All Bihar';
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final todayDate = DateTime.now().toIso8601String().substring(0, 10);

      // 1. Aaj ke challenge data ke liye query
      var query = Supabase.instance.client
          .from('daily_challenge_submissions')
          .select('user_name, district, score, time_taken_seconds, challenge_date')
          .ilike('challenge_date', '$todayDate%');

      if (_selectedDistrict != 'All Bihar') {
        query = query.eq('district', _selectedDistrict);
      }

      var res = await query
          .order('score', ascending: false)
          .order('time_taken_seconds', ascending: true)
          .limit(50);

      // 2. Agar aaj ke submissions zero hain, toh fallback: latest overall submissions
      if (res == null || (res as List).isEmpty) {
        var fallbackQuery = Supabase.instance.client
            .from('daily_challenge_submissions')
            .select('user_name, district, score, time_taken_seconds, challenge_date');

        if (_selectedDistrict != 'All Bihar') {
          fallbackQuery = fallbackQuery.eq('district', _selectedDistrict);
        }

        res = await fallbackQuery
            .order('score', ascending: false)
            .order('time_taken_seconds', ascending: true)
            .limit(50);
      }

      if (mounted) {
        setState(() {
          _ranks = List<Map<String, dynamic>>.from(res ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Leaderboard fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor =
        widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor =
        widget.isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subTextColor =
        widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Daily Duel Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          // District Filter Chips
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _districts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final dist = _districts[index];
                final isSelected = dist == _selectedDistrict;
                return ChoiceChip(
                  label: Text(dist),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: widget.isDarkMode
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (widget.isDarkMode ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                    ),
                  ),
                  onSelected: (val) {
                    if (val && _selectedDistrict != dist) {
                      setState(() => _selectedDistrict = dist);
                      _fetchLeaderboard();
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Submissions List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  )
                : _ranks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🎯', style: TextStyle(fontSize: 36)),
                              const SizedBox(height: 10),
                              Text(
                                '$_selectedDistrict me abhi tak koi duel record nahi mila.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Challenge complete karke pehle topper baniye!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _ranks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _ranks[index];
                          final int rank = index + 1;
                          final bool isTop3 = rank <= 3;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isTop3
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                                    : (widget.isDarkMode
                                        ? Colors.white10
                                        : const Color(0xFFE2E8F0)),
                                width: isTop3 ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Rank Icon / Number
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isTop3
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    isTop3
                                        ? (rank == 1
                                            ? '🥇'
                                            : (rank == 2 ? '🥈' : '🥉'))
                                        : '#$rank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: isTop3 ? 16 : 12.5,
                                      color: isTop3
                                          ? const Color(0xFFD97706)
                                          : subTextColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // User Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (item['user_name'] ?? 'Candidate')
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_rounded,
                                              size: 12,
                                              color: Color(0xFF2563EB)),
                                          const SizedBox(width: 3),
                                          Text(
                                            (item['district'] ?? 'Bihar')
                                                .toString(),
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: subTextColor),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '⏱ ${item['time_taken_seconds'] ?? 0}s',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: subTextColor),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Score Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item['score'] ?? 0}/10',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF059669),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
