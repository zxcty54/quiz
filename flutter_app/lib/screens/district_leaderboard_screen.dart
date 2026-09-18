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
  State<DistrictLeaderboardScreen> createState() => _DistrictLeaderboardScreenState();
}

class _DistrictLeaderboardScreenState extends State<DistrictLeaderboardScreen> {
  final List<String> _districts = [
    'All Bihar',
    'Patna',
    'Gaya',
    'Muzaffarpur',
    'Bhagalpur',
    'Darbhanga',
    'Purnia',
    'Rohtas',
    'Saran',
    'Begusarai',
    'Samastipur',
    'Nalanda',
    'Siwan',
    'Vaishali',
  ];

  late String _selectedDistrict;
  List<Map<String, dynamic>> _ranks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDistrict = widget.userDistrict;
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      var query = Supabase.instance.client
          .from('daily_challenge_submissions')
          .select()
          .eq('challenge_date', DateTime.now().toIso8601String().substring(0, 10));

      if (_selectedDistrict != 'All Bihar') {
        query = query.eq('district', _selectedDistrict);
      }

      final res = await query
          .order('score', ascending: false)
          .order('time_taken_seconds', ascending: true)
          .limit(50);

      if (mounted) {
        setState(() {
          _ranks = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Daily Duel Leaderboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // District Filter Chips
          SizedBox(
            height: 48,
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
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (widget.isDarkMode ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  onSelected: (val) {
                    if (val) {
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
                ? const Center(child: CircularProgressIndicator())
                : _ranks.isEmpty
                    ? Center(
                        child: Text(
                          '$_selectedDistrict me abhi tak koi submission nahi hui.\nPehle topper baniye!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _ranks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _ranks[index];
                          final int rank = index + 1;
                          final bool isTop3 = rank <= 3;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isTop3
                                    ? const Color(0xFFF59E0B).withOpacity(0.5)
                                    : (widget.isDarkMode
                                        ? Colors.white10
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Rank Icon / Number
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isTop3
                                        ? const Color(0xFFF59E0B).withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    isTop3
                                        ? (rank == 1 ? '🥇' : (rank == 2 ? '🥈' : '🥉'))
                                        : '#$rank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: isTop3 ? 16 : 12,
                                      color: isTop3 ? const Color(0xFFD97706) : Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // User Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['user_name'] ?? 'Candidate',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_rounded,
                                              size: 12, color: Colors.grey),
                                          const SizedBox(width: 3),
                                          Text(
                                            item['district'] ?? 'Bihar',
                                            style: const TextStyle(
                                                fontSize: 11, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '⏱ ${item['time_taken_seconds']}s',
                                            style: const TextStyle(
                                                fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Score Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${item['score']}/10',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF059669),
                                      fontSize: 14,
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
