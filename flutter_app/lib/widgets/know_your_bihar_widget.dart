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
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${payload.config.cycleDay} • ${payload.config.domain}',
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  card.district != null ? '📍 ${card.district}' : 'BPSC & BIHAR SI',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              card.title,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.summary,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
            const Divider(height: 26),

            // Subject Insights
            if (card.bulletPoints.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded, size: 17, color: themeColor),
                  const SizedBox(width: 6),
                  Text(
                    'Subject Profile & Insights',
                    style: TextStyle(
                      fontSize: 13.5,
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
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: card.bulletPoints.map((pt) {
                    final split = pt.split(': ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor)),
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
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      ),
                                    ),
                                  ] else ...[
                                    TextSpan(
                                      text: pt,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
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
              const SizedBox(height: 16),
            ],

            // BPSC Direct PYQs
            if (card.pyqFacts.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(
                    'BPSC Direct PYQ Triggers',
                    style: TextStyle(
                      fontSize: 13.5,
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
                            fontSize: 12,
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : const Color(0xFF1E293B).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -15,
              child: Text(
                payload.config.defaultWatermark,
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : themeColor.withValues(alpha: 0.04),
                  letterSpacing: 2,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Text(payload.config.emoji, style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                Text(
                                  '${payload.config.cycleDay} • ${payload.config.domain}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: themeColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Know Your Bihar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: isDark ? Colors.white38 : Colors.grey.shade400),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        card.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
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
