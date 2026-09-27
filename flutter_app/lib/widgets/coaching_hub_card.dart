import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          .select('''
            batch_name,
            batch_code,
            coachings (
              name,
              banner_url,
              owner_name,
              district,
              city
            ),
            batch_tests (
              id,
              is_live
            )
          ''')
          .eq('batch_code', batchCode)
          .maybeSingle();

      if (batchRes != null && mounted) {
        final coaching = batchRes['coachings'] as Map<String, dynamic>?;
        final rawTests = (batchRes['batch_tests'] as List?) ?? [];
        final liveTests = rawTests.where((t) => t['is_live'] != false).toList();

        setState(() {
          _enrolledBatchCode = batchCode;
          _enrolledBatchName = batchRes['batch_name']?.toString();
          _coachingName = coaching?['name']?.toString() ?? 'Classroom Batch';
          _coachingBanner = coaching?['banner_url']?.toString();
          _ownerHandle = coaching?['owner_name']?.toString();
          _coachingCity = coaching?['district']?.toString() ?? coaching?['city']?.toString() ?? 'Bihar';
          _availableMocksCount = liveTests.length;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  void _openAccessCodeDialog() {
    final isDark = widget.isDarkMode;
    final dialogBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white70 : const Color(0xFF64748B);

    final codeCtrl = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.token_rounded, color: Color(0xFFF59E0B), size: 22),
              const SizedBox(width: 8),
              Text(
                'Institutional Access Pass',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the Batch Access Code provided on your admission receipt or enrollment card:',
                style: TextStyle(fontSize: 12, color: textMuted, height: 1.35),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. PATNA100',
                  hintStyle: TextStyle(color: textMuted.withOpacity(0.6), fontSize: 12),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste_rounded, size: 18, color: Color(0xFF2563EB)),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        codeCtrl.text = data!.text!.trim().toUpperCase();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isVerifying
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (code.isEmpty) return;

                      setDialogState(() => isVerifying = true);

                      try {
                        final batch = await Supabase.instance.client
                            .from('batches')
                            .select('batch_name, batch_code')
                            .eq('batch_code', code)
                            .maybeSingle();

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (batch != null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('user_enrolled_batch_code', code);
                          await loadEnrolledBatchData();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Access Granted: "${batch['batch_name']}" activated'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid Batch Code. Please verify with your institute.'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                          }
                        }
                      } catch (_) {
                        setDialogState(() => isVerifying = false);
                      }
                    },
              child: isVerifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify & Activate', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final metricBoxBg = isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC);
    final metricBoxBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    if (_isLoading) return const SizedBox.shrink();

    // =========================================================================
    // 🎓 STATE A: ENROLLED CLASSROOM PASS
    // =========================================================================
    if (_enrolledBatchCode != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF10B981).withOpacity(isDark ? 0.4 : 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF022C22), const Color(0xFF064E3B)]
                        : [const Color(0xFF064E3B), const Color(0xFF047857)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'AUTHORIZED CLASSROOM PASS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _openAccessCodeDialog,
                      child: const Text(
                        'Change Batch Token 🔑',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              if (_coachingBanner != null && _coachingBanner!.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: Image.network(
                    _coachingBanner!,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _coachingName ?? 'Classroom Hub',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_enrolledBatchName • 📍 $_coachingCity',
                                style: TextStyle(fontSize: 12, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25)),
                          ),
                          child: const Column(
                            children: [
                              Text('4', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2563EB))),
                              Text('CBT Mocks', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 20),
                        label: const Text('Open Test Series & Handouts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        onPressed: () {
                          if (_ownerHandle != null && _ownerHandle!.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreatorProfileScreen(
                                  creatorHandle: _ownerHandle!,
                                  isDarkMode: widget.isDarkMode,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    Divider(height: 1, color: cardBorder),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CoachingDirectoryScreen(isDarkMode: widget.isDarkMode),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.travel_explore_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Explore Participating Institutes & Statewide Mocks →',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // =========================================================================
    // 🔍 STATE B: DISCOVERY-FIRST PORTAL
    // =========================================================================
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                    : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hub_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'STATEWIDE INSTITUTIONAL NETWORK',
                            style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DIGITAL CLASSROOM',
                        style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Access Bihar’s Top Offline Institutes on Your Device',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connecting 38 districts: Experience institute-grade CBT assessments and classroom materials wherever you are.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: metricBoxBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: metricBoxBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _InstitutionalMetric(
                          icon: Icons.quiz_outlined,
                          label: 'CBT Mocks',
                          isDark: isDark,
                        ),
                      ),
                      _MetricDivider(color: metricBoxBorder),
                      Expanded(
                        child: _InstitutionalMetric(
                          icon: Icons.insights_rounded,
                          label: 'State Rank',
                          isDark: isDark,
                        ),
                      ),
                      _MetricDivider(color: metricBoxBorder),
                      Expanded(
                        child: _InstitutionalMetric(
                          icon: Icons.description_outlined,
                          label: 'Handouts',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.token_rounded, size: 16),
                        label: const Text('Enter Access Code 🔑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: _openAccessCodeDialog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.explore_outlined, size: 16),
                        label: const Text('Explore Institutes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CoachingDirectoryScreen(isDarkMode: widget.isDarkMode),
                            ),
                          );
                        },
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
}

class _InstitutionalMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _InstitutionalMetric({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF2563EB)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  final Color color;
  const _MetricDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: color,
    );
  }
}
