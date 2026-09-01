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
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCoachings();
  }

  Future<void> _fetchCoachings() async {
    try {
      final res = await Supabase.instance.client
          .from('coachings')
          .select('*, batches(id, batch_name, batch_code)')
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgSurface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final filteredList = _coachings.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final city = (c['city'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();
      return name.contains(q) || city.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: const Text('Verified Coaching Institutes 🏫', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Coaching by Name or City (e.g. Patna, Gaya)...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? const Center(child: Text('No coaching institutes found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredList.length,
                        itemBuilder: (context, idx) {
                          final c = filteredList[idx];
                          final List batches = c['batches'] ?? [];
                          final String? banner = c['banner_url'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (banner != null && banner.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                      child: Image.network(banner, height: 100, width: double.infinity, fit: BoxFit.cover),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: const Color(0xFF2563EB),
                                          child: Text((c['name'] ?? 'C')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(c['name'] ?? 'Coaching Center', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              const SizedBox(height: 2),
                                              Text('📍 ${c['city'] ?? 'Patna'} • ${batches.length} Active Batches', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                      ],
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
}
