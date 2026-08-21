import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProPdfVaultCard extends StatefulWidget {
  final bool isDarkMode;
  final String? customWebsiteUrl;
  final List<dynamic>? dynamicPdfItems;

  const ProPdfVaultCard({
    super.key,
    required this.isDarkMode,
    this.customWebsiteUrl,
    this.dynamicPdfItems,
  });

  @override
  State<ProPdfVaultCard> createState() => _ProPdfVaultCardState();
}

class _ProPdfVaultCardState extends State<ProPdfVaultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  static const String _defaultWebsiteUrl = "https://t.me/MockTester_Online";

  // 📝 6 DEFAULT HIGH-VALUE ITEMS (Static Clean List)
  final List<Map<String, dynamic>> _fallbackDocs = [
    {
      'title': 'NCERT Science & GK 1-Liner Crux',
      'tag': '🔥 MOST READ',
      'badge': 'ADDED TODAY',
      'meta': '128 Pages • Complete Handnotes',
      'reads': '18.4k reads',
      'color': 0xFF2563EB,
      'url': 'https://t.me/MockTester_Online',
    },
    {
      'title': 'BPSC & BSSC 3000+ TCS PYQ Formula Sheet',
      'tag': '⚡ HIGH YIELD',
      'badge': 'NEW ADDED',
      'meta': '64 Pages • Quick Revision Chart',
      'reads': '12.1k reads',
      'color': 0xFFD97706,
      'url': 'https://t.me/MockTester_Online',
    },
    {
      'title': '2026 Monthly Current Affairs Magazine (Aug Edition)',
      'tag': '📌 LATEST',
      'badge': 'ADDED TODAY',
      'meta': 'Full Edition • Bihar & National',
      'reads': '9.8k reads',
      'color': 0xFF059669,
      'url': 'https://t.me/MockTester_Online',
    },
    {
      'title': 'Indian Polity 100 Landmark Articles & Amendments',
      'tag': '📜 CRUCIAL',
      'badge': 'NEW ADDED',
      'meta': '48 Pages • Table Summary',
      'reads': '14.2k reads',
      'color': 0xFF7C3AED,
      'url': 'https://t.me/MockTester_Online',
    },
    {
      'title': 'Modern Indian History: Timeline & Governor Generals',
      'tag': '🗺️ MAP CRUX',
      'badge': 'ADDED TODAY',
      'meta': '52 Pages • Exam Ready Notes',
      'reads': '8.6k reads',
      'color': 0xFFDC2626,
      'url': 'https://t.me/MockTester_Online',
    },
    {
      'title': 'General Science Physics & Chemistry Formula Sheet',
      'tag': '⚡ FORMULA',
      'badge': 'NEW ADDED',
      'meta': '36 Pages • All SI Units & Laws',
      'reads': '11.5k reads',
      'color': 0xFF0284C7,
      'url': 'https://t.me/MockTester_Online',
    },
  ];

  List<Map<String, dynamic>> _getDocList() {
    if (widget.dynamicPdfItems != null && widget.dynamicPdfItems!.isNotEmpty) {
      return widget.dynamicPdfItems!.map<Map<String, dynamic>>((item) {
        if (item is Map) {
          return {
            'title': item['title'] ?? 'PDF Document',
            'tag': item['tag'] ?? '🔥 POPULAR',
            'badge': item['badge'] ?? 'NEW ADDED',
            'meta': item['meta'] ?? 'Free E-Book',
            'reads': item['reads'] ?? '10k+ reads',
            'color': item['color'] != null
                ? int.tryParse(item['color'].toString()) ?? 0xFF2563EB
                : 0xFF2563EB,
            'url': item['url'] ?? _defaultWebsiteUrl,
          };
        }
        return {
          'title': item.toString(),
          'tag': 'FREE PDF',
          'badge': 'NEW',
          'meta': 'Online Notes',
          'reads': '5k+ reads',
          'color': 0xFF2563EB,
          'url': _defaultWebsiteUrl,
        };
      }).toList();
    }
    return _fallbackDocs;
  }

  @override
  void initState() {
    super.initState();
    // 💡 Smooth Blinking Badge Animation
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String targetUrl) async {
    final Uri uri = Uri.parse(targetUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Link open nahi ho paya!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final docs = _getDocList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🏆 1. HEADER SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('📚', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study Material & PDF Vault',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Handwritten notes & curated test crux',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '100% FREE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 📋 2. STATIC DIRECT LIST (Zero Scroll Inside)
            ...docs.map((doc) {
              final Color accent = Color(doc['color'] as int);
              final String badgeText = doc['badge'] ?? 'NEW ADDED';
              final String docUrl = doc['url'] ?? (widget.customWebsiteUrl ?? _defaultWebsiteUrl);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () => _launchUrl(docUrl),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 📄 PDF Icon Box
                        Container(
                          width: 36,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accent.withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(height: 1),
                              Text(
                                'PDF',
                                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: accent),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // 📝 Item Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  // ✨ Blinking Pulse Tag
                                  FadeTransition(
                                    opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_blinkController),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: const TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    doc['reads'],
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                doc['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                doc['meta'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),
                        const Icon(Icons.download_for_offline_rounded, size: 22, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 4),

            // 🚀 3. DIRECT ACTION BUTTON
            InkWell(
              onTap: () => _launchUrl(widget.customWebsiteUrl ?? _defaultWebsiteUrl),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_open_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Instant PDF Vault Access (Free Download)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 13),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
