import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
    _fetchCoachingsWithBatches();
  }

  Future<void> _fetchCoachingsWithBatches() async {
    try {
      final res = await Supabase.instance.client
          .from('coachings')
          .select('*, batches(*, batch_tests(*))')
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

  void _openCallOrWhatsApp(String? contact) async {
    if (contact == null || contact.trim().isEmpty) return;
    final cleanPhone = contact.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openBatchUnlockDialog(Map<String, dynamic> batch, String coachingName) {
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
            Expanded(
              child: Text(
                'Enroll: ${batch['batch_name']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the private batch code shared by $coachingName:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. PATNA100',
                labelText: 'Secret Batch Code',
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
              final enteredCode = codeCtrl.text.trim().toUpperCase();
              final actualCode = (batch['batch_code'] ?? '').toString().toUpperCase();

              if (enteredCode.isNotEmpty && enteredCode == actualCode) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_enrolled_batch_code', enteredCode);

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Verified! Welcome to "${batch['batch_name']}"'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Invalid Batch Code! Contact coaching center.')),
                  );
                }
              }
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

    // Filter Logic: Search, District & City
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
            const Text('Explore Bihar Coaching Batches 🏫', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
            Text('${_coachings.length} Verified Centers Across Bihar', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
      body: Column(
        children: [
          // 🔍 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Coaching, District, Town (e.g. Ara, Musallahpur)...',
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

          // 📍 2. Bihar 38 Districts Strip
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

          // 🏙️ 3. Sub-Towns / Area Filter
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

          // 🏛️ 4. Coaching & Batch Cards Feed
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
                            Text('No coaching found in $_selectedDistrict', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('Try selecting "All" or another district.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: filteredList.length,
                        itemBuilder: (context, idx) {
                          final c = filteredList[idx];
                          final String coachingName = c['name'] ?? 'Coaching Center';
                          final String district = c['district'] ?? c['city'] ?? 'Bihar';
                          final String? landmark = c['landmark_address'] ?? c['area_locality'];
                          final String? contactNumber = c['contact_number'];
                          final String? ownerHandle = c['owner_name'];
                          final String? bannerUrl = c['banner_url'];

                          final List allBatches = c['batches'] ?? [];
                          final List visibleBatches = allBatches.where((b) => b['status'] != 'HIDDEN').toList();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 18),
                            color: cardBg,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: Colors.grey.withOpacity(0.18)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🏢 Top Institute Profile & Contact Bar
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 📸 Coaching Avatar / Logo
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: const Color(0xFF2563EB),
                                        backgroundImage: (bannerUrl != null && bannerUrl.isNotEmpty)
                                            ? NetworkImage(bannerUrl)
                                            : null,
                                        child: (bannerUrl == null || bannerUrl.isEmpty)
                                            ? Text(
                                                coachingName[0].toUpperCase(),
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                              )
                                            : null,
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
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.verified, color: Color(0xFF2563EB), size: 16),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '📍 $district${landmark != null && landmark.isNotEmpty ? " • $landmark" : ""}',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (contactNumber != null && contactNumber.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A), size: 20),
                                          tooltip: 'Call / WhatsApp Helpline',
                                          onPressed: () => _openCallOrWhatsApp(contactNumber),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // 🎓 Distinct Batch Boxes Grid
                                  if (visibleBatches.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('No active batches right now. Check profile for updates.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                                    )
                                  else
                                    ...visibleBatches.map((b) {
                                      final List tests = b['batch_tests'] ?? [];
                                      final String patternTag = b['target_pattern'] ?? 'Based on 72nd BPSC Prelims Pattern';
                                      final int pdfCount = b['pdf_notes_count'] ?? 12;

                                      int totalQuestions = 0;
                                      int durationMins = 120;
                                      if (tests.isNotEmpty) {
                                        totalQuestions = tests.fold<int>(0, (sum, t) => sum + (t['total_questions'] as int? ?? 50));
                                        durationMins = tests.first['duration_mins'] ?? 120;
                                      }

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2), width: 1.1),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Batch Title + Target Pattern Badge
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    b['batch_name'] ?? 'Target Batch',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF16A34A).withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'BATCH',
                                                    style: TextStyle(color: Color(0xFF16A34A), fontSize: 9.5, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),

                                            // 🎯 Exam Trend / Pattern Indicator
                                            Row(
                                              children: [
                                                const Icon(Icons.track_changes_rounded, size: 13, color: Color(0xFFEA580C)),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    patternTag,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C), fontWeight: FontWeight.w600),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // 📊 CBT Mocks & PDF Details Row
                                            Row(
                                              children: [
                                                _buildBatchSpecChip(
                                                  icon: Icons.bolt_rounded,
                                                  label: '${tests.length} CBT Tests (${totalQuestions > 0 ? "$totalQuestions Qs" : "Full Length"})',
                                                  color: const Color(0xFF2563EB),
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(width: 6),
                                                _buildBatchSpecChip(
                                                  icon: Icons.timer_outlined,
                                                  label: '$durationMins Mins',
                                                  color: Colors.amber.shade800,
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(width: 6),
                                                _buildBatchSpecChip(
                                                  icon: Icons.picture_as_pdf_outlined,
                                                  label: '$pdfCount Handouts',
                                                  color: const Color(0xFF059669),
                                                  isDark: isDark,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // 🔒 Secret Code Unlock Button
                                            SizedBox(
                                              width: double.infinity,
                                              height: 36,
                                              child: ElevatedButton.icon(
                                                icon: const Icon(Icons.vpn_key_rounded, size: 14),
                                                label: const Text('Unlock Batch with Code 🔑', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF2563EB),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  elevation: 0,
                                                ),
                                                onPressed: () => _openBatchUnlockDialog(b, coachingName),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),

                                  const SizedBox(height: 6),

                                  // 🌐 Visit Public Profile & Community Hub CTA
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.storefront_outlined, size: 16),
                                      label: const Text('Visit Institute Profile & Open Hub →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                        side: BorderSide(color: Colors.grey.withOpacity(0.35)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        if (ownerHandle != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreatorProfileScreen(
                                                creatorHandle: ownerHandle,
                                                isDarkMode: isDark,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchSpecChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
