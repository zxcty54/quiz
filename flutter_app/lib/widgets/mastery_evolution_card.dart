import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MasteryEvolutionCard extends StatefulWidget {
  final bool isDarkMode;
  const MasteryEvolutionCard({super.key, required this.isDarkMode});

  @override
  State<MasteryEvolutionCard> createState() => _MasteryEvolutionCardState();
}

class _MasteryEvolutionCardState extends State<MasteryEvolutionCard> {
  Map<String, dynamic>? _insightData;
  bool _isLoading = true;
  String? _lastUpdatedText;

  @override
  void initState() {
    super.initState();
    _fetchSavedInsight();
  }

  Future<void> _fetchSavedInsight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final res = await Supabase.instance.client
          .from('user_ai_insights')
          .select('summary_report, analyzed_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted && res != null && res['summary_report'] != null) {
        final dynamic raw = res['summary_report'];
        final Map<String, dynamic> report = raw is Map ? Map<String, dynamic>.from(raw) : {};

        String timeStr = 'Recently';
        if (res['analyzed_at'] != null) {
          final dt = DateTime.tryParse(res['analyzed_at'].toString())?.toLocal();
          if (dt != null) {
            timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
          }
        }

        setState(() {
          _insightData = report;
          _lastUpdatedText = timeStr;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("Error fetching insights: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_isLoading) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_insightData == null || _insightData!.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Text("🤖", style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI Diagnostic Engine Active",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Tests attempt karein. Har 15-minute inactivity ke baad backend AI automatically behavioral diagnosis generate kar dega.",
                    style: TextStyle(fontSize: 11.5, color: subColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final String badge = _insightData!['mastery_badge'] ?? _insightData!['estimated_mastery_level'] ?? 'Developing';[cite: 2]
    final String behavior = _insightData!['candidate_behavior'] ?? 'Exam Aspirant';
    final String verdict = _insightData!['seriousness_verdict'] ?? _insightData!['summary'] ?? 'Consistent practice builds mastery.';[cite: 2]
    final List<dynamic> strengths = _insightData!['strengths'] ?? [];[cite: 2]
    final List<dynamic> traps = _insightData!['critical_traps'] ?? _insightData!['weaknesses'] ?? [];[cite: 2]
    final List<dynamic> prescriptions = _insightData!['tactical_prescription'] ?? _insightData!['action_prescription'] ?? [];[cite: 2]

    final bool isRushedOrCasual = behavior.toLowerCase().contains('rush') ||
        behavior.toLowerCase().contains('casual') ||
        behavior.toLowerCase().contains('flippant') ||
        behavior.toLowerCase().contains('time-pass');

    Color badgeColor = const Color(0xFF2563EB);
    if (badge.toLowerCase().contains('master')) {
      badgeColor = const Color(0xFF16A34A);
    } else if (badge.toLowerCase().contains('scholar')) {
      badgeColor = const Color(0xFF7C3AED);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRushedOrCasual ? Colors.amber.shade700.withOpacity(0.5) : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "AI Behavioral Diagnosis",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textColor),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Text(
                  badge.toUpperCase(),
                  style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Behavioral Alert Box
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isRushedOrCasual
                  ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB))
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isRushedOrCasual ? const Color(0xFFF59E0B) : borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isRushedOrCasual ? "⚠️ Pattern:" : "🎯 Pattern:",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (isRushedOrCasual ? Colors.red : const Color(0xFF2563EB)).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        behavior,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isRushedOrCasual ? Colors.red.shade700 : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  verdict,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Strengths & Pinpoint Traps
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Strengths
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text("Top Strengths", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),[cite: 2]
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (strengths.isEmpty)
                      Text("Need more data", style: TextStyle(fontSize: 11, color: subColor))
                    else
                      ...strengths.take(2).map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text("• $s", style: TextStyle(fontSize: 11.5, color: subColor)),
                          )),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Critical Traps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text("Critical Traps", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),[cite: 2]
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (traps.isEmpty)
                      Text("No major traps", style: TextStyle(fontSize: 11, color: subColor))
                    else
                      ...traps.take(2).map((t) {
                        String title = "";
                        String nature = "";
                        if (t is Map) {
                          title = t['subtopic'] ?? '';
                          nature = t['nature'] ?? '';
                        } else {
                          title = t.toString();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("• $title", style: TextStyle(fontSize: 11.5, color: subColor, fontWeight: FontWeight.w600)),
                              if (nature.isNotEmpty)
                                Text(
                                  "  ↳ $nature",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isRushedOrCasual ? Colors.amber.shade800 : Colors.red.shade400,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),

          // Tactical Prescription
          if (prescriptions.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.flash_on_rounded, size: 15, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  "Tactical Prescription",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...prescriptions.take(2).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    "🎯 $p",
                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                  ),
                )),
          ],

          const Divider(height: 18),

          // Read-only Footer: Last synced + Silent Cron Status (No Buttons)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Auto-synced: ${_lastUpdatedText ?? 'Recently'}",
                style: TextStyle(fontSize: 10.5, color: subColor),
              ),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text(
                    "Cron Active",
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
