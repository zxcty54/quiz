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
                  Text("AI Diagnostic Engine Active", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                  const SizedBox(height: 2),
                  Text("Tests attempt karein. Har 15-min inactivity ke baad backend AI automatically diagnosis calculate kar dega.", style: TextStyle(fontSize: 11.5, color: subColor)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Evidence & Metadata parsing
    final meta = _insightData!['evidence_meta'] is Map ? Map<String, dynamic>.from(_insightData!['evidence_meta']) : {};
    final String badge = meta['badge'] ?? _insightData!['mastery_badge'] ?? _insightData!['estimated_mastery_level'] ?? 'Developing';
    final int totalAnalyzed = meta['total_attempts_analyzed'] ?? 0;
    final String confidence = meta['confidence'] ?? 'Medium';

    // Behavioral Pattern & Verdict
    final String pattern = _insightData!['behavioral_pattern'] ?? _insightData!['candidate_behavior'] ?? 'Exam Aspirant';
    final String verdict = _insightData!['summary_verdict'] ?? _insightData!['seriousness_verdict'] ?? _insightData!['summary'] ?? '';

    // Data-backed Subtopics
    final Map<String, dynamic>? weakArea = _insightData!['top_weak_area'] is Map ? Map<String, dynamic>.from(_insightData!['top_weak_area']) : null;
    final Map<String, dynamic>? strongArea = _insightData!['top_strong_area'] is Map ? Map<String, dynamic>.from(_insightData!['top_strong_area']) : null;

    // Fallback support for older schema
    final List<dynamic> oldTraps = _insightData!['critical_traps'] ?? _insightData!['weaknesses'] ?? [];
    final List<dynamic> oldStrengths = _insightData!['strengths'] ?? [];
    final List<dynamic> prescriptions = _insightData!['tactical_prescription'] ?? _insightData!['action_prescription'] ?? [];

    final bool isRushed = pattern.toLowerCase().contains('rush') || 
                          pattern.toLowerCase().contains('fast') || 
                          pattern.toLowerCase().contains('casual') || 
                          pattern.toLowerCase().contains('flippant');

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
        border: Border.all(color: isRushed ? Colors.amber.shade700.withOpacity(0.5) : borderColor),
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
          // 1. Header: Icon + Title + Status Badge & Tiny Evidence Line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Text("AI Diagnostic Engine", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textColor)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withOpacity(0.4)),
                    ),
                    child: Text(badge.toUpperCase(), style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    totalAnalyzed > 0 ? "Based on $totalAnalyzed recent attempts · Conf: $confidence" : "Confidence: $confidence",
                    style: TextStyle(fontSize: 9.5, color: subColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Behavioral Pattern Alert Box
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isRushed
                  ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB))
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isRushed ? const Color(0xFFF59E0B) : borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isRushed ? "⚠️ Pattern:" : "🎯 Pattern:",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (isRushed ? Colors.red : const Color(0xFF2563EB)).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pattern,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isRushed ? Colors.red.shade700 : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                if (verdict.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    verdict,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Data-Backed Detailed Diagnostics (Weak Area)
          if (weakArea != null && weakArea['subtopic'] != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${weakArea['subtopic']}: Weak area",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${weakArea['attempts'] ?? 0} attempts · ${weakArea['correct'] ?? 0} correct · ${weakArea['accuracy_pct'] ?? 0}% accuracy",
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  if ((weakArea['median_sec'] ?? 0) > 0)
                    Text("Median response time: ${weakArea['median_sec']} sec", style: TextStyle(fontSize: 11, color: subColor)),
                  if (weakArea['pattern_note'] != null && weakArea['pattern_note'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text("↳ ${weakArea['pattern_note']}", style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ] else if (oldTraps.isNotEmpty) ...[
            // Fallback for older traps
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                    SizedBox(width: 4),
                    Text("Critical Traps", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ],
                ),
                const SizedBox(height: 4),
                ...oldTraps.take(2).map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text("• ${t is Map ? t['subtopic'] ?? '' : t}", style: TextStyle(fontSize: 11.5, color: subColor)),
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ],

          // 4. Strong Hold Area
          if (strongArea != null && strongArea['subtopic'] != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                  const SizedBox(width: 5),
                  Text(
                    "Strong Hold: ${strongArea['subtopic']} (${strongArea['accuracy_pct'] ?? 0}% acc)",
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          ] else if (oldStrengths.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                  const SizedBox(width: 5),
                  Text(
                    "Strong Hold: ${oldStrengths.first}",
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          ],

          // 5. Tactical Prescription
          if (prescriptions.isNotEmpty) ...[
            const Divider(height: 18),
            Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text("Tactical Prescription", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 6),
            ...prescriptions.take(2).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text("🎯 $p", style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))),
                )),
          ],

          const Divider(height: 16),

          // 6. Footer (Read-only status)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Auto-synced: ${_lastUpdatedText ?? 'Recently'}", style: TextStyle(fontSize: 10, color: subColor)),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text("Cron Active", style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
