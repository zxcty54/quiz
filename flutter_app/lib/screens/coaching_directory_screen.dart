import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/bihar_location_data.dart';
import 'creator_profile_screen.dart';

class CoachingDirectoryScreen extends StatefulWidget {
  final bool isDarkMode;
  const CoachingDirectoryScreen({super.key, required this.isDarkMode});

  @override
  State<CoachingDirectoryScreen> createState() => _CoachingDirectoryScreenState();
}

class _CoachingDirectoryScreenState extends State<CoachingDirectoryScreen> {
  List<dynamic> _coachings = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedDistrict = 'All';
  String _selectedCity = 'All';

  final Map<String, List<String>> _biharMap = kBiharDistrictCityMap;

  @override
  void initState() {
    super.initState();
    _fetchCoachings();
  }

  Future<void> _fetchCoachings() async {
    try {
      final res = await Supabase.instance.client
          .from('coachings')
          .select('*, batches(id, batch_name, status, batch_tests(id))')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _coachings = res ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openJoinBatchDialog({String? prefillCoachingName}) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.vpn_key_rounded, color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            Text(
              prefillCoachingName != null ? 'Join $prefillCoachingName' : 'Enroll in Batch',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apne coaching ya teacher dwara diya gaya Secret Batch Code enter karein:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. PATNA100',
                labelText: 'Batch Password / Code',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final code = codeCtrl.text.trim().toUpperCase();
              if (code.isEmpty) return;
              try {
                final batch = await Supabase.instance.client
                    .from('batches')
                    .select('*, coachings(*)')
                    .eq('batch_code', code)
                    .maybeSingle();

                if (ctx.mounted) Navigator.pop(ctx);
                if (batch != null && mounted) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_enrolled_batch_code', code);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Verified! Enrolled in "${batch['batch_name']}"'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid Batch Code! Teacher se sahi password/code lein.')),
                  );
                }
              } catch (_) {}
            },
            child: const Text('Unlock Batch 🚀'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final allDistricts = ['All', ..._biharMap.keys];
    final currentCities = _selectedDistrict == 'All'
        ? ['All']
        : ['All', ...(_biharMap[_selectedDistrict] ?? [])];

    final filteredList = _coachings.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final dist = (c['district'] ?? c['city'] ?? '').toString().toLowerCase();
      final city = (c['city'] ?? '').toString().toLowerCase();
      final landmark = (c['landmark_address'] ?? c['area_locality'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      bool matchesSearch = name.contains(q) || dist.contains(q) || city.contains(q) || landmark.contains(q);
      bool matchesDistrict = _selectedDistrict == 'All' || dist.contains(_selectedDistrict.toLowerCase().split(' ')[0]);
      bool matchesCity = _selectedCity == 'All' || city.contains(_selectedCity.toLowerCase()) || landmark.contains(_selectedCity.toLowerCase());

      return matchesSearch && matchesDistrict && matchesCity;
    }).toList();

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bihar Institutes & Batches 🏫', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('${_coachings.length} Verified Centers Across 38 Districts', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF2563EB)),
            tooltip: 'Enter Batch Code',
            onPressed: () => _openJoinBatchDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Coaching, District or Hub (e.g. Musallahpur, Ara)...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                    : null,
                isDense: true,
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.15))),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // 📍 38 Districts Strip
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: allDistricts.length,
              itemBuilder: (context, idx) {
                final d = allDistricts[idx];
                final isSelected = _selectedDistrict == d;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(d, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                    backgroundColor: cardBg,
                    visualDensity: VisualDensity.compact,
                    onSelected: (val) {
                      setState(() {
                        _selectedDistrict = d;
                        _selectedCity = 'All';
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // 🏙️ Sub-Towns Strip
          if (currentCities.length > 1 && _selectedDistrict != 'All') ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: currentCities.length,
                itemBuilder: (context, idx) {
                  final town = currentCities[idx];
                  final isSelected = _selectedCity == town;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(town, style: TextStyle(fontSize: 10.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF16A34A).withOpacity(0.18),
                      checkmarkColor: const Color(0xFF16A34A),
                      labelStyle: TextStyle(color: isSelected ? const Color(0xFF16A34A) : Colors.grey[600]),
                      backgroundColor: cardBg,
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) => setState(() => _selectedCity = town),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),

          // 🏛️ Coaching Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined, size: 54, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            Text('No verified centers in $_selectedDistrict', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('Try searching another district or reset filter.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: filteredList.length,
                        itemBuilder: (context, idx) {
                          final c = filteredList[idx];
                          final List allBatches = c['batches'] ?? [];
                          // Hidden batches filter
                          final List visibleBatches = allBatches.where((b) => b['status'] != 'HIDDEN').toList();
                          final String? banner = c['banner_url'];
                          final String districtName = c['district'] ?? c['city'] ?? 'Bihar';
                          final String? areaName = c['landmark_address'] ?? c['area_locality'];

                          int totalScheduledMocks = 0;
                          for (var b in visibleBatches) {
                            totalScheduledMocks += ((b['batch_tests'] as List?) ?? []).length;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: cardBg,
                            elevation: 2.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: Colors.grey.withOpacity(0.18)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🖼️ BADA HIGH-RES BANNER (Height: 180px for clear visibility)
                                if (banner != null && banner.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                    child: Image.network(
                                      banner,
                                      height: 180, // 👈 Height increased for crisp banner display
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                  ),

                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header Info
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: const Color(0xFF2563EB),
                                            child: Text(
                                              (c['name'] ?? 'C')[0].toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
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
                                                        c['name'] ?? 'Coaching Center',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.verified, color: Color(0xFF2563EB), size: 16),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '📍 $districtName${areaName != null && areaName.isNotEmpty ? " • $areaName" : ""}',
                                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Active Batches & Tests Badge
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF16A34A).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${visibleBatches.length} Available Batches',
                                              style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '$totalScheduledMocks Private CBT Tests',
                                              style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // 🔒 List of Batches (Names only, Code is hidden)
                                      if (visibleBatches.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 10),
                                        const Text('Available Classroom Batches:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        ...visibleBatches.take(3).map((b) {
                                          final isUpcoming = b['status'] == 'UPCOMING';
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      isUpcoming ? Icons.schedule_rounded : Icons.lock_outline_rounded,
                                                      size: 14,
                                                      color: isUpcoming ? Colors.amber.shade800 : const Color(0xFF2563EB),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      b['batch_name'] ?? 'Target Batch',
                                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  isUpcoming ? '⏳ Upcoming' : '🔒 Password Protected',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isUpcoming ? Colors.amber.shade800 : Colors.grey[500],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],

                                      const SizedBox(height: 12),

                                      // Action Buttons
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF2563EB),
                                                side: const BorderSide(color: Color(0xFF2563EB)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => CreatorProfileScreen(
                                                      creatorHandle: c['owner_name'] ?? 'user',
                                                      isDarkMode: isDark,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: const Text('View Profile & Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.vpn_key_rounded, size: 14),
                                              label: const Text('Enroll via Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2563EB),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => _openJoinBatchDialog(prefillCoachingName: c['name']),
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
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
