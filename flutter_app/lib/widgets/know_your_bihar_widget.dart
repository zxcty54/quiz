import 'package:flutter/material.dart';
import '../models/bpsc_daily_card_model.dart';
import '../services/bpsc_rotation_service.dart';

class KnowYourBiharWidget extends StatefulWidget {
  final bool isDarkMode;

  const KnowYourBiharWidget({super.key, required this.isDarkMode});

  @override
  State<KnowYourBiharWidget> createState() => _KnowYourBiharWidgetState();
}

class _KnowYourBiharWidgetState extends State<KnowYourBiharWidget> {
  BpscDailyPayload? _payload;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDailyTopic();
  }

  Future<void> _fetchDailyTopic() async {
    try {
      final payload = await BpscRotationService.fetchTodayPayload();
      if (mounted) {
        setState(() {
          _payload = payload;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDetailModal(BuildContext context, BpscDailyPayload payload) {
    final isDark = widget.isDarkMode;
    final card = payload.card;
    final themeColor = Color(payload.config.colorSeed);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Top Status Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(payload.config.emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        '${payload.config.cycleDay} • ${payload.config.domain}',
                        style: TextStyle(
                          color: themeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  card.district != null ? '📍 ${card.district}' : 'BIHAR SPECIAL',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Main Entity Title
            Text(
              card.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              card.category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 12),

            // Summary Callout Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                card.summary,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Complete Fact Points
            if (card.bulletPoints.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 17, color: themeColor),
                  const SizedBox(width: 6),
                  Text(
                    'Subject Insights & High-Yield Data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: card.bulletPoints.map((pt) {
                    final split = pt.split(': ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  if (split.length > 1) ...[
                                    TextSpan(
                                      text: '${split[0]}: ',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    TextSpan(
                                      text: split.sublist(1).join(': '),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ] else ...[
                                    TextSpan(
                                      text: pt,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // BPSC Direct PYQ Box
            if (card.pyqFacts.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(
                    'Direct BPSC PYQ Triggers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                children: card.pyqFacts.map((pyq) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pyq['topic']!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pyq['detail']!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _payload == null) {
      return const SizedBox.shrink();
    }

    final isDark = widget.isDarkMode;
    final payload = _payload!;
    final card = payload.card;
    final themeColor = Color(payload.config.colorSeed);

    final List<String> frontHighlights = card.bulletPoints.take(2).toList();
    final Map<String, String>? frontPyq = card.pyqFacts.isNotEmpty ? card.pyqFacts.first : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // 🏺 Authentic Heritage Arch Silhouette Motif
            Positioned(
              right: -25,
              bottom: -25,
              child: Opacity(
                opacity: isDark ? 0.03 : 0.04,
                child: Icon(
                  Icons.temple_buddhist_rounded,
                  size: 140,
                  color: themeColor,
                ),
              ),
            ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openDetailModal(context, payload),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. TOP HEADER: Master Track Identifier
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(payload.config.emoji, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 5),
                                Text(
                                  '${payload.config.cycleDay} • ${payload.config.domain}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: themeColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DAILY DOSSIER',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. HERO TITLE & LOCATION PILL
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  card.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (card.district != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.place_rounded, size: 12, color: Color(0xFFD97706)),
                                  const SizedBox(width: 3),
                                  Text(
                                    card.district!,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3. CORE HIGHLIGHT STRIP (Structured key facts)
                      if (frontHighlights.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: frontHighlights.map((pt) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, size: 13.5, color: themeColor),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        pt,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // 4. BPSC PYQ DIRECT TRIGGER BOX
                      if (frontPyq != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🎯 ', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'PYQ: ',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                                        ),
                                      ),
                                      TextSpan(
                                        text: frontPyq['detail'] ?? frontPyq['topic'] ?? '',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // 5. ACTION STRIP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.touch_app_rounded, size: 14, color: themeColor),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to read full dossier',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: themeColor,
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: themeColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
