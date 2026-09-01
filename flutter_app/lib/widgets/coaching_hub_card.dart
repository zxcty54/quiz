import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/coaching_directory_screen.dart';
import '../screens/creator_profile_screen.dart';

class CoachingHubCard extends StatefulWidget {
  final bool isDarkMode;
  const CoachingHubCard({super.key, required this.isDarkMode});

  @override
  State<CoachingHubCard> createState() => CoachingHubCardState();
}

class CoachingHubCardState extends State<CoachingHubCard> {
  String? _enrolledBatchCode;
  String? _enrolledBatchName;
  String? _coachingName;
  String? _coachingBanner;
  String? _ownerHandle;
  String? _coachingCity;
  int _availableMocksCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadEnrolledBatchData();
  }

  Future<void> loadEnrolledBatchData() async {
    final prefs = await SharedPreferences.getInstance();
    final batchCode = prefs.getString('user_enrolled_batch_code');

    if (batchCode == null || batchCode.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final batchRes = await Supabase.instance.client
          .from('batches')
          .select('*, coachings(*), batch_tests(id)')
          .eq('batch_code', batchCode)
          .maybeSingle();

      if (batchRes != null && mounted) {
        final coaching = batchRes['coachings'];
        final tests = (batchRes['batch_tests'] as List?) ?? [];
        setState(() {
          _enrolledBatchCode = batchCode;
          _enrolledBatchName = batchRes['batch_name'];
          _coachingName = coaching?['name'] ?? 'Classroom Batch';
          _coachingBanner = coaching?['banner_url'];
          _ownerHandle = coaching?['owner_name'];
          _coachingCity = coaching?['district'] ?? coaching?['city'] ?? 'Bihar';
          _availableMocksCount = tests.length;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  void _openJoinBatchDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Join Batch via Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apne coaching ya teacher dwara diya gaya private batch code enter karein:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. PATNA100',
                labelText: 'Batch Code',
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

                if (batch != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_enrolled_batch_code', code);
                  loadEnrolledBatchData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🎉 Verified! Enrolled in "${batch['batch_name']}"'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid Batch Code! Teacher se code verify karein.')),
                    );
                  }
                }
              } catch (_) {}
            },
            child: const Text('Join Batch 🚀'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) return const SizedBox.shrink();

    // 🎓 STATE A: Jab user kisi Batch me enrolled ho chuka ho
    if (_enrolledBatchCode != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_coachingBanner != null && _coachingBanner!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  _coachingBanner!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'MY CLASSROOM • $_enrolledBatchCode',
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _openJoinBatchDialog,
                        child: const Text(
                          '+ Switch Code',
                          style: TextStyle(color: Color(0xFF2563EB), fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _coachingName ?? 'Classroom Hub',
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$_enrolledBatchName • 📍 $_coachingCity • $_availableMocksCount CBT Mocks',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (_ownerHandle != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreatorProfileScreen(
                                creatorHandle: _ownerHandle!,
                                isDarkMode: isDark,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Open Batch Tests & Notes 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 🔍 STATE B: DISCOVERY-FIRST PORTAL (Find Coaching, Teachers & Mocks)
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🎨 Header: Discovery Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                    : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Discover Bihar Coaching Hubs',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'EXPLORE',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Apne city ke offline coachings, top mentors aur mocks khojein',
                        style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 📋 Content: 3-Point Filter Highlights & Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3 Highlights Chips
                Row(
                  children: [
                    _buildFeatureChip('📍 38 Districts', isDark),
                    const SizedBox(width: 6),
                    _buildFeatureChip('👨‍🏫 Top Mentors', isDark),
                    const SizedBox(width: 6),
                    _buildFeatureChip('📝 Batch CBT Tests', isDark),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  'Patna, Gaya, Ara, Muzaffarpur ya apne district ke coaching centers dhundhein, study material access karein aur test series join karein.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.location_city_rounded, size: 16),
                        label: const Text('Discover Centers 🔍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CoachingDirectoryScreen(isDarkMode: isDark),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.vpn_key_rounded, size: 15),
                        label: const Text('Have Code?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB), width: 1.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: _openJoinBatchDialog,
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
  }

  Widget _buildFeatureChip(String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 0.8,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}
