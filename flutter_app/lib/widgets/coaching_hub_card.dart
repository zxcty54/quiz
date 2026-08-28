import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
            Text('🏫 ', style: TextStyle(fontSize: 20)),
            Text('Join Coaching Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Batch Code shared by your Coaching / Teacher:',
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
                        content: Text('🎉 Joined "${batch['batch_name']}"!'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid Batch Code! Please verify with coaching.')),
                    );
                  }
                }
              } catch (_) {}
            },
            child: const Text('Enroll Now 🚀'),
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

    // 🎓 STATE A: Enrolled in a Coaching Batch
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
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 12,
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
                  height: 110,
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
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'MY COACHING • $_enrolledBatchCode',
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _openJoinBatchDialog,
                        child: const Text(
                          '+ Switch Code',
                          style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _coachingName ?? 'Classroom Hub',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_enrolledBatchName • $_availableMocksCount Scheduled CBT Mocks',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
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
                      child: const Text('Open Batch Classroom & Mocks 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 🏫 STATE B: Default / Not Enrolled Yet
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join Your Coaching Hub 🏫',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Have a class batch code? Access private CBT mocks & class ranks.',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.vpn_key_outlined, size: 14),
                  label: const Text('Enter Batch Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _openJoinBatchDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
