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
  bool _isTrapsExpanded = false;

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
        final Map<String, dynamic> report =
            raw is Map ? Map<String, dynamic>.from(raw) : {};

        String timeStr = 'Recently';
        if (res['analyzed_at'] != null) {
          final dt = DateTime.tryParse(res['analyzed_at'].toString())?.toLocal();
          if (dt != null) {
            timeStr =
                "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
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
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
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
                  Text("AI Diagnostic Engine Active",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor)),
                  const SizedBox(height: 2),
                  Text(
                      "Mocks attempt karein. Backend AI continuous pattern diagnosis calculate karega.",
                      style: TextStyle(fontSize: 11.5, color: subColor)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final meta = _insightData!['evidence_meta'] is Map
        ? Map<String, dynamic>.from(_insightData!['evidence_meta'])
        : {};
    final String badge =
        (meta['badge'] ?? _insightData!['mastery_badge'] ?? 'Developing').toString();
    final String confidenceLevel =
        (meta['confidence_level'] ?? meta['confidence'] ?? 'Medium').toString();
    final String confidenceReason =
        (meta['confidence_reason'] ?? 'Based on recent mock attempts').toString();

    final String headline = (_insightData!['ai_headline'] ?? '').toString();
    final String pattern = (_insightData!['behavioral_pattern'] ??
            _insightData!['candidate_behavior'] ??
            'Disciplined Solver')
        .toString();
    final String verdict = (_insightData!['summary_verdict'] ??
            _insightData!['seriousness_verdict'] ??
            '')
        .toString();

    final List<dynamic> subjects = _insightData!['subject_analysis'] is List
        ? _insightData!['subject_analysis']
        : [];
    final List<dynamic> trapsDetailed =
        _insightData!['critical_traps_detailed'] is List
            ? _insightData!['critical_traps_detailed']
            : [];
    final List<dynamic> progressDelta = _insightData!['progress_delta'] is List
        ? _insightData!['progress_delta']
        : [];

    // Filter delta with diff != 0 so zero noise stays hidden
    final activeDeltas = progressDelta.where((p) {
      if (p is! Map) return false;
      final num diff = num.tryParse((p['diff'] ?? 0).toString()) ?? 0;
      return diff != 0;
    }).toList();

    // Traps to show based on expanded toggle
    final List<dynamic> displayedTraps =
        _isTrapsExpanded ? trapsDetailed : trapsDetailed.take(2).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
          // 1. Header (Original Layout Restored)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    const Icon(Icons.psychology_rounded,
                        color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "AI Diagnostic\nEngine",
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.15,
                            color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge.toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Confidence: $confidenceLevel",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: subColor),
                      textAlign: TextAlign.end,
                    ),
                    Text(
                      confidenceReason,
                      style: TextStyle(
                          fontSize: 8.5, color: subColor.withOpacity(0.85)),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Pattern & Verdict Box (Original Style)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: textColor),
                    children: [
                      const TextSpan(
                        text: "⚡ Pattern: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: pattern,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
                if (headline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF1D4ED8)),
                  ),
                ],
                if (verdict.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    verdict,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                        height: 1.3),
                  ),
                ],
              ],
            ),
          ),

          // 3. Subject Chips (All Subjects Rendered, No Cut)
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: subjects.map((s) {
                if (s is! Map) return const SizedBox.shrink();
                final String name = (s['subject'] ?? '').toString();
                final int acc =
                    int.tryParse(s['accuracy_pct']?.toString() ?? '0') ?? 0;
                final bool isStrong = acc >= 65;

                final chipBg = isStrong
                    ? (isDark
                        ? const Color(0xFF14532D).withOpacity(0.4)
                        : const Color(0xFFDCFCE7))
                    : (isDark
                        ? const Color(0xFF713F12).withOpacity(0.4)
                        : const Color(0xFFFEF9C3));

                final chipText = isStrong
                    ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                    : (isDark ? const Color(0xFFFDE047) : const Color(0xFFA16207));

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: chipText.withOpacity(0.3)),
                  ),
                  child: Text(
                    "$name $acc%",
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: chipText),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),

          // 4. Critical Traps (Original Red Card Format Restored)
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded,
                  size: 15, color: Color(0xFFDC2626)),
              SizedBox(width: 4),
              Text(
                "Critical Traps",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (trapsDetailed.isNotEmpty) ...[
            ...displayedTraps.map((t) {
              if (t is! Map) return const SizedBox.shrink();
              final String subject = t['subject'] != null &&
                      t['subject'].toString().isNotEmpty
                  ? "[${t['subject']}] "
                  : "";
              final String topic = (t['topic'] ?? '').toString();
              final String subtopic = t['subtopic'] != null &&
                      t['subtopic'].toString().isNotEmpty &&
                      t['subtopic'].toString() != topic
                  ? " · ${t['subtopic']}"
                  : "";
              final String fullTitle = "$subject$topic$subtopic".trim();

              final int acc =
                  int.tryParse(t['accuracy_pct']?.toString() ?? '0') ?? 0;
              final int attempts =
                  int.tryParse(t['attempts']?.toString() ?? '0') ?? 0;
              final int errors =
                  int.tryParse(t['repeated_errors']?.toString() ?? '0') ?? 0;

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFDC2626).withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullTitle.isEmpty ? 'Topic Under Review' : fullTitle,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$acc% accuracy · $attempts questions attempted · $errors repeated errors",
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFF991B1B)),
                    ),
                  ],
                ),
              );
            }),

            // 🌟 Expandable Toggle
            if (trapsDetailed.length > 2) ...[
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isTrapsExpanded = !_isTrapsExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isTrapsExpanded
                            ? "Show less ↑"
                            : "View all (${trapsDetailed.length} traps) ↓",
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                "No critical recurring traps detected.",
                style: TextStyle(
                    fontSize: 11,
                    color: subColor,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],

          // 5. Since Last Analysis (Original Green Box Restored)
          if (activeDeltas.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132A1C) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.trending_up_rounded,
                          size: 14, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text("Since Last Analysis",
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...activeDeltas.map((p) {
                    final dynamic diffRaw = p['diff'] ?? 0;
                    final num diff = num.tryParse(diffRaw.toString()) ?? 0;
                    final bool isUp = diff >= 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (p['subject'] ?? '').toString(),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${p['from_pct']}% → ${p['to_pct']}%  ${isUp ? '↑$diff%' : '↓${diff.abs()}%'}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isUp
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
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

          const Divider(height: 16),

          // 6. Footer (Original Layout)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Updated: ${_lastUpdatedText ?? 'Recently'}",
                  style: TextStyle(fontSize: 10, color: subColor)),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 12, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "AI monitoring active",
                        style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF16A34A),
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
