import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'creator_profile_screen.dart';

class CoachingDirectoryScreen extends StatefulWidget {
  final bool isDarkMode;
  const CoachingDirectoryScreen({super.key, required this.isDarkMode});

  @override
  State<CoachingDirectoryScreen> createState() => _CoachingDirectoryScreenState();
}

class _CoachingDirectoryScreenState extends State<CoachingDirectoryScreen> {
  List<Map<String, dynamic>> _coachings = [];
  List<String> _liveCities = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCity = 'All';
  String _selectedExam = 'All';

  final List<String> _popularExams = ['All', 'BPSC', 'BSSC', 'SSC', 'Railway', 'Daroga'];

  @override
  void initState() {
    super.initState();
    _fetchCoachingsDirectory();
  }

  Future<void> _fetchCoachingsDirectory() async {
    try {
      final res = await Supabase.instance.client
          .from('coachings')
          .select('*, batches(id, batch_name, status, batch_tests(id)), coaching_selections(id, is_verified, testimonial_text, target_exam)')
          .eq('is_approved', true);

      final List rawData = res ?? [];
      List<Map<String, dynamic>> processedList = [];

      final Set<String> activeCities = {'All'};

      for (var item in rawData) {
        final c = Map<String, dynamic>.from(item);
        final city = (c['district'] ?? c['city'] ?? '').toString().trim();
        if (city.isNotEmpty) {
          activeCities.add(city);
        }

        // Calculate verified selections & impact score
        final List selectionsList = (c['coaching_selections'] as List?) ?? [];
        int verifiedCount = 0;
        int impactScore = 0;

        for (var s in selectionsList) {
          if (s['is_verified'] == true) {
            verifiedCount++;
            final String quote = (s['testimonial_text'] ?? '').toString().trim();
            impactScore += (quote.length > 20) ? 15 : 10;
          }
        }

        c['verified_selections_count'] = verifiedCount;
        c['impact_score'] = impactScore;
        processedList.add(c);
      }

      // 🏆 Highest Impact Score & Selections top par aayenge
      processedList.sort((a, b) {
        int scoreA = a['impact_score'] ?? 0;
        int scoreB = b['impact_score'] ?? 0;
        if (scoreB != scoreA) return scoreB.compareTo(scoreA);
        int countA = a['verified_selections_count'] ?? 0;
        int countB = b['verified_selections_count'] ?? 0;
        return countB.compareTo(countA);
      });

      if (mounted) {
        setState(() {
          _coachings = processedList;
          _liveCities = activeCities.toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textHeading = isDark ? Colors.white : const Color(0xFF0F172A);

    // Filter Logic: Search, City & Exam
    final filteredList = _coachings.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final city = (c['district'] ?? c['city'] ?? '').toString().toLowerCase();
      final landmark = (c['landmark_address'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      bool matchesSearch = name.contains(q) || city.contains(q) || landmark.contains(q);
      bool matchesCity = _selectedCity == 'All' || city.contains(_selectedCity.toLowerCase());

      bool matchesExam = true;
      if (_selectedExam != 'All') {
        final batchesStr = ((c['batches'] as List?) ?? [])
            .map((b) => (b['batch_name'] ?? '').toString().toLowerCase())
            .join(' ');
        final selectionsExamStr = ((c['coaching_selections'] as List?) ?? [])
            .map((s) => (s['target_exam'] ?? '').toString().toLowerCase())
            .join(' ');

        matchesExam = batchesStr.contains(_selectedExam.toLowerCase()) ||
            selectionsExamStr.contains(_selectedExam.toLowerCase()) ||
            landmark.contains(_selectedExam.toLowerCase()) ||
            name.contains(_selectedExam.toLowerCase());
      }

      return matchesSearch && matchesCity && matchesExam;
    }).toList();

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Coaching Leaderboard & Hub',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textHeading),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : CustomScrollView(
              slivers: [
                // 1. Header & Filters
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verified Selections & Success Leaderboard 🏆',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textHeading),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Ranked by authenticated results, student proofs and active batches',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                        const SizedBox(height: 14),

                        // Search Field
                        TextField(
                          style: TextStyle(color: textHeading, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Search coaching, teacher, or city...',
                            hintStyle: TextStyle(color: textMuted, fontSize: 13),
                            prefixIcon: Icon(Icons.search, color: textMuted, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 18, color: textMuted),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 14),

                        // Popular Exams Filter
                        Text('Filter by Exam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: _popularExams.map((exam) {
                            final isSel = _selectedExam == exam;
                            return ChoiceChip(
                              label: Text(exam),
                              selected: isSel,
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              onSelected: (_) => setState(() => _selectedExam = exam),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),

                        // District Filter
                        Text('Coaching Available in Bihar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: _liveCities.map((city) {
                            final isSel = _selectedCity == city;
                            return FilterChip(
                              label: Text(city),
                              selected: isSel,
                              selectedColor: const Color(0xFF16A34A).withOpacity(0.18),
                              checkmarkColor: const Color(0xFF16A34A),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? const Color(0xFF16A34A) : textMuted,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              onSelected: (_) => setState(() => _selectedCity = city),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),

                // 2. Count Bar
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Divider(height: 1, thickness: 0.8, color: dividerColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filteredList.length} Ranked Centres',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textHeading),
                            ),
                            if (_selectedCity != 'All' || _selectedExam != 'All')
                              InkWell(
                                onTap: () => setState(() {
                                  _selectedCity = 'All';
                                  _selectedExam = 'All';
                                }),
                                child: const Text(
                                  'Reset Filters ✕',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 0.8, color: dividerColor),
                    ],
                  ),
                ),

                // 3. Ranked Feed Rows
                if (filteredList.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No coaching centres found matching your search.',
                          style: TextStyle(color: textMuted, fontSize: 13),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final c = filteredList[idx];
                        final coachingName = c['name'] ?? 'Coaching Center';
                        final district = c['district'] ?? c['city'] ?? 'Bihar';
                        final landmark = c['landmark_address'] ?? '';
                        final ownerHandle = c['owner_name'] ?? 'creator';
                        final verifiedSelections = c['verified_selections_count'] ?? 0;
                        final impactScore = c['impact_score'] ?? 0;

                        final rank = idx + 1;
                        final isTop3 = rank <= 3;
                        final Color badgeColor = rank == 1
                            ? const Color(0xFFF59E0B) // Gold
                            : rank == 2
                                ? const Color(0xFF94A3B8) // Silver
                                : rank == 3
                                    ? const Color(0xFFB45309) // Bronze
                                    : const Color(0xFF2563EB);

                        final List allBatches = c['batches'] ?? [];
                        final List visibleBatches = allBatches.where((b) => b['status'] != 'HIDDEN').toList();

                        int totalTests = 0;
                        for (var b in visibleBatches) {
                          totalTests += ((b['batch_tests'] as List?) ?? []).length;
                        }

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreatorProfileScreen(
                                  creatorHandle: ownerHandle,
                                  isDarkMode: isDark,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🥇 Rank Position Indicator
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: badgeColor, width: isTop3 ? 1.5 : 1.0),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '#$rank',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        coachingName,
                                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textHeading),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.verified, size: 15, color: Color(0xFF2563EB)),
                                                  ],
                                                ),
                                              ),
                                              // 🎓 Verified Selections Count Pill
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: (verifiedSelections > 0 ? const Color(0xFF16A34A) : Colors.grey).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  verifiedSelections > 0
                                                      ? '$verifiedSelections Selected 🎓'
                                                      : 'New Center',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: verifiedSelections > 0 ? const Color(0xFF16A34A) : Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '📍 $district${landmark.isNotEmpty ? ", $landmark" : ""}',
                                            style: TextStyle(fontSize: 12, color: textMuted),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${visibleBatches.length} Batches · $totalTests CBT Tests · $impactScore Impact Pts',
                                            style: TextStyle(fontSize: 11.5, color: textMuted),
                                          ),
                                          const SizedBox(height: 8),

                                          // Mini Impact Progress Bar
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: (impactScore / 150).clamp(0.06, 1.0),
                                              minHeight: 4,
                                              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, thickness: 0.8, color: dividerColor),
                            ],
                          ),
                        );
                      },
                      childCount: filteredList.length,
                    ),
                  ),

                // 4. Bottom Notice
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
                    child: Center(
                      child: Text(
                        "Rankings update automatically upon selection verification.",
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
