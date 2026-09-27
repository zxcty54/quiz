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

  @override
  void initState() {
    super.initState();
    _fetchCoachingsDirectory();
  }

  Future<void> _fetchCoachingsDirectory() async {
    try {
      final res = await Supabase.instance.client
          .from('coachings')
          .select('*, batches(id, batch_name, target_exam, status, batch_tests(id))')
          .eq('is_approved', true)
          .order('created_at', ascending: false);

      final List data = res ?? [];
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
    const bgSurface = Color(0xFF030712);
    const cardBg = Color(0xFF0F172A);
    const textHeading = Colors.white;
    const textMuted = Color(0xFF94A3B8);

    final filtered = _coachings.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final city = (c['district'] ?? c['city'] ?? '').toString().toLowerCase();
      final landmark = (c['landmark_address'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      bool matchesSearch = name.contains(q) || city.contains(q) || landmark.contains(q);
      bool matchesCity = _selectedCity == 'All' || city == _selectedCity.toLowerCase();
      return matchesSearch && matchesCity;
    }).toList();

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Explore Coaching Hubs',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          style: const TextStyle(color: textHeading, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Search coaching by name, area or district...',
                            hintStyle: const TextStyle(color: textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: textMuted),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        if (_liveCities.length > 1) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            children: _liveCities.map((city) {
                              final isSel = _selectedCity == city;
                              return FilterChip(
                                label: Text(city),
                                selected: isSel,
                                selectedColor: const Color(0xFF10B981).withOpacity(0.2),
                                checkmarkColor: const Color(0xFF10B981),
                                backgroundColor: const Color(0xFF1E293B),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? const Color(0xFF34D399) : textMuted,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                onSelected: (_) => setState(() => _selectedCity = city),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                if (_coachings.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} Verified Centres',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          if (_selectedCity != 'All' || _searchQuery.isNotEmpty)
                            InkWell(
                              onTap: () => setState(() {
                                _selectedCity = 'All';
                                _searchQuery = '';
                              }),
                              child: const Text(
                                'Reset Filter ✕',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.school_outlined, size: 40, color: Color(0xFF60A5FA)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _coachings.isEmpty ? 'Directory Launching Soon' : 'No Institutes Found',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textHeading),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _coachings.isEmpty
                                  ? 'Verified offline institutes from Patna, Gaya & all 38 districts will be live here shortly.'
                                  : 'Try adjusting your search query or reset your city filter.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: textMuted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                          final c = filtered[idx];
                          final name = (c['name'] ?? 'Coaching Center').toString();
                          final district = (c['district'] ?? c['city'] ?? 'Bihar').toString();
                          final landmark = (c['landmark_address'] ?? '').toString();
                          final ownerHandle = (c['owner_name'] ?? '').toString();
                          final logoUrl = (c['banner_url'] ?? c['logo_url'] ?? '').toString().trim();

                          final List batches = (c['batches'] as List?) ?? [];
                          final visibleBatches = batches.where((b) => b['status'] != 'HIDDEN').toList();

                          int testsTotal = 0;
                          for (var b in visibleBatches) {
                            testsTotal += ((b['batch_tests'] as List?) ?? []).length;
                          }

                          final Set<String> exams = {};
                          for (var b in visibleBatches) {
                            final ex = (b['target_exam'] ?? '').toString().trim();
                            if (ex.isNotEmpty) exams.add(ex);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF1E293B)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (ownerHandle.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreatorProfileScreen(
                                        creatorHandle: ownerHandle,
                                        isDarkMode: widget.isDarkMode,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFF334155)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: logoUrl.isNotEmpty
                                                ? Image.network(
                                                    logoUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Center(
                                                      child: Text(
                                                        name.isNotEmpty ? name[0] : 'C',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF60A5FA)),
                                                      ),
                                                    ),
                                                  )
                                                : Center(
                                                    child: Text(
                                                      name.isNotEmpty ? name[0] : 'C',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF60A5FA)),
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
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: textHeading),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '📍 $district${landmark.isNotEmpty ? " • $landmark" : ""}',
                                                style: const TextStyle(fontSize: 11.5, color: textMuted),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (exams.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: exams.map((ex) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withOpacity(0.14),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              ex,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF93C5FD)),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],

                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFF1E293B)),
                                    const SizedBox(height: 10),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${visibleBatches.length} Batches • $testsTotal CBT Tests',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                                        ),
                                        const Row(
                                          children: [
                                            Text(
                                              'View Hub',
                                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                                            ),
                                            SizedBox(width: 2),
                                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF38BDF8)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
