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
  List<dynamic> _coachings = [];
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
          .select('*, batches(id, batch_name, status, batch_tests(id))')
          .eq('is_approved', true)
          .order('created_at', ascending: false);

      final List data = res ?? [];

      // Sirf wahi cities select karein jahan actual coachings database me available hain
      final Set<String> activeCities = {'All'};
      for (var c in data) {
        final city = (c['district'] ?? c['city'] ?? '').toString().trim();
        if (city.isNotEmpty) {
          activeCities.add(city);
        }
      }

      if (mounted) {
        setState(() {
          _coachings = data;
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

    // Filter Logic: Search, Active City & Exam
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
        matchesExam = batchesStr.contains(_selectedExam.toLowerCase()) ||
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
          'Explore Coaching',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textHeading),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : CustomScrollView(
              slivers: [
                // 1. Top Header & Search Area
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bihar ke Students aur Local Coaching Centres ka Digital Hub',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textHeading),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Coaching ke Mocks • Notes • Batches — Ek Hi Platform Par',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                        const SizedBox(height: 14),

                        // Search Field
                        TextField(
                          style: TextStyle(color: textHeading, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Search any coaching, teacher or city...',
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

                        // Popular Exams
                        Text('Popular Exams', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
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

                        // Coaching Available in Bihar (Live Cities Only)
                        Text('Coaching available in Bihar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
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

                // 2. Count Bar & Thin 1px Divider
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
                              '${filteredList.length} Coaching Centres',
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

                // 3. Twitter/X Style Flat Feed Rows
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

                        final List allBatches = c['batches'] ?? [];
                        final List visibleBatches = allBatches.where((b) => b['status'] != 'HIDDEN').toList();

                        int totalTests = 0;
                        for (var b in visibleBatches) {
                          totalTests += ((b['batch_tests'] as List?) ?? []).length;
                        }
                        int notesCount = visibleBatches.length * 5;

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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
                                      child: Text(
                                        coachingName.isNotEmpty ? coachingName[0].toUpperCase() : 'C',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2563EB)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  coachingName,
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textHeading),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '📍 $district${landmark.isNotEmpty ? ", $landmark" : ""}',
                                            style: TextStyle(fontSize: 12, color: textMuted),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            'BPSC · BSSC · SSC',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textHeading.withOpacity(0.85)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${visibleBatches.length} Batches · $totalTests Tests · $notesCount Notes',
                                            style: TextStyle(fontSize: 11.5, color: textMuted),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'View Coaching →',
                                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
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

                // 4. Bottom Notice Strip
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            "Can't find your city?",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textHeading),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "We're adding coaching centres across all 38 districts.",
                            style: TextStyle(fontSize: 11.5, color: textMuted),
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
}
