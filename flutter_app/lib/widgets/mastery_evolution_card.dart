import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MasteryEvolutionCard extends StatefulWidget {
  final bool isDarkMode;
  const MasteryEvolutionCard({super.key, required this.isDarkMode});

  @override
  State<MasteryEvolutionCard> createState() => _MasteryEvolutionCardState();
}

class _MasteryEvolutionCardState extends State<MasteryEvolutionCard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _insightData;
  bool _isLoading = true;
  String? _lastUpdatedText;
  bool _isTrapsExpanded = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fetchSavedInsight();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

    // 🌟 1. Premium Pulsing Empty State
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
            ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFF2563EB),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI Cognitive Engine Active",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Mocks attempt karein. Backend AI continuous patterns aur learning curves diagnose karega.",
                    style: TextStyle(fontSize: 11.5, color: subColor, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Safe Data Extraction
    final meta = _insightData!['evidence_meta'] is Map
        ? Map<String, dynamic>.from(_insightData!['evidence_meta'])
        : {};
    final String badge =
        (meta['badge'] ?? _insightData!['mastery_badge'] ?? 'Developing').toString();
    final String confidenceLevel =
        (meta['confidence_level'] ?? meta['confidence'] ?? 'Medium').toString();
    final String confidenceReason =
        (meta['confidence_reason'] ?? 'Based on recent mock attempts').toString();

    final String pattern = (_insightData!['behavioral_pattern'] ??
            _insightData!['candidate_behavior'] ??
            'Exam Aspirant')
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
    final List<dynamic> prescriptions =
        _insightData!['tactical_prescription'] is List
            ? _insightData!['tactical_prescription']
            : [];

    final visibleTraps =
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
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ Header: Badge & Confidence
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
                        "AI Diagnostic Engine",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: textColor,
                        ),
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
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
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
                        color: subColor,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    Text(
                      confidenceReason,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: subColor.withOpacity(0.85),
                      ),
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

          // ⚡ Behavioral Telemetry Pattern
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
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
                if (verdict.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    verdict,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 📚 Subject Chips (Full Wrap, No Truncation)
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
                      color: chipText,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),

          // ⚠️ Critical Traps Monitor (Expandable + Soft Tone)
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFEA580C)),
              SizedBox(width: 4),
              Text(
                "Critical Traps (Focus Areas)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (trapsDetailed.isNotEmpty) ...[
            ...visibleTraps.map((t) {
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

              // Soft Color Hierarchy: Severe errors get deeper rose/crimson, moderate get warm amber
              final isSevere = errors >= 3;
              final trapBorderColor = isSevere
                  ? const Color(0xFFE11D48).withOpacity(0.25)
                  : const Color(0xFFEA580C).withOpacity(0.25);
              final trapBgColor = isSevere
                  ? const Color(0xFFE11D48).withOpacity(0.05)
                  : const Color(0xFFEA580C).withOpacity(0.05);
              final trapTextColor = isSevere
                  ? (isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C))
                  : (isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C));

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: trapBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: trapBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullTitle.isEmpty ? 'Topic Under Review' : fullTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$acc% accuracy · $attempts questions attempted · $errors repeated errors",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: trapTextColor,
                      ),
                    ),
                  ],
                ),
              );
            }),

            // "View all / Show less" toggle
            if (trapsDetailed.length > 2) ...[
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isTrapsExpanded = !_isTrapsExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
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
                          color: Color(0xFF2563EB),
                        ),
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
                "No critical recurring traps detected. Good consistency!",
                style: TextStyle(
                  fontSize: 11,
                  color: subColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // 📊 Progress Journey with Visual Animated Mini-Bars
          if (progressDelta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.trending_up_rounded,
                              size: 15, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            "Progress Journey",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Start → Current",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...progressDelta.map((p) {
                    if (p is! Map) return const SizedBox.shrink();
                    final num fromPct =
                        num.tryParse(p['from_pct']?.toString() ?? '0') ?? 0;
                    final num toPct =
                        num.tryParse(p['to_pct']?.toString() ?? '0') ?? 0;
                    final num diff = num.tryParse(p['diff']?.toString() ?? '') ??
                        (toPct - fromPct);

                    final bool isUp = diff > 0;
                    final bool isDown = diff < 0;

                    String badgeText = "• 0%";
                    Color badgeColor = subColor;
                    if (isUp) {
                      badgeText = "↑ +$diff%";
                      badgeColor = const Color(0xFF059669);
                    } else if (isDown) {
                      badgeText = "↓ ${diff.abs()}%";
                      badgeColor = const Color(0xFFDC2626);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  (p['subject'] ?? '').toString(),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    "$fromPct% → $toPct%",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: subColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Visual Animated Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              child: Stack(
                                children: [
                                  Container(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                  // Baseline marker
                                  FractionallySizedBox(
                                    widthFactor: (fromPct / 100).clamp(0.0, 1.0),
                                    child: Container(
                                      color: subColor.withOpacity(0.3),
                                    ),
                                  ),
                                  // Live animated bar
                                  TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    tween: Tween<double>(
                                      begin: 0.0,
                                      end: (toPct / 100).clamp(0.0, 1.0),
                                    ),
                                    builder: (context, val, _) {
                                      return FractionallySizedBox(
                                        widthFactor: val,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isUp
                                                  ? [
                                                      const Color(0xFF34D399),
                                                      const Color(0xFF059669)
                                                    ]
                                                  : [
                                                      const Color(0xFFF87171),
                                                      const Color(0xFFDC2626)
                                                    ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
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

          // 🎯 Tactical Prescription
          if (prescriptions.isNotEmpty) ...[
            const Divider(height: 18),
            Row(
              children: const [
                Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Text(
                  "Tactical Prescription",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...prescriptions.take(2).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    "🎯 ${p.toString()}",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E40AF),
                    ),
                  ),
                )),
          ],

          const Divider(height: 16),

          // ⚡ Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Updated: ${_lastUpdatedText ?? 'Recently'}",
                style: TextStyle(fontSize: 10, color: subColor),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 12, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "AI monitoring active",
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
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
