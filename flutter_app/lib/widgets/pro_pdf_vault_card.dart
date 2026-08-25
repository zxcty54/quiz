import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ProPdfVaultCard extends StatefulWidget {
  final bool isDarkMode;
  final String? customWebsiteUrl;

  const ProPdfVaultCard({
    super.key,
    required this.isDarkMode,
    this.customWebsiteUrl,
  });

  @override
  State<ProPdfVaultCard> createState() => _ProPdfVaultCardState();
}

class _ProPdfVaultCardState extends State<ProPdfVaultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  static const String _defaultWebsiteUrl = "https://www.mocktester.online";
  static const String _booksJsonUrl =
      "https://raw.githubusercontent.com/zxcty54/quiz/main/books_database.json";

  final List<Map<String, dynamic>> _fallbackDocs = [
    {
      'title': 'M. Laxmikanth: Indian Polity (6th Edition)',
      'tag': '🏛️ STANDARD',
      'badge': 'ADDED TODAY',
      'meta': 'Civil Services • Hindi/En Edition',
      'color': 0xFF7C3AED,
      'url': 'https://www.mocktester.online',
    },
    {
      'title': 'NCERT Science & GK 1-Liner Crux',
      'tag': '🌿 NCERT CRUX',
      'badge': 'NEW ADDED',
      'meta': 'Class 8-12 • Complete Handnotes',
      'color': 0xFF059669,
      'url': 'https://www.mocktester.online',
    },
    {
      'title': 'BPSC & BSSC 3000+ TCS PYQ Formula Sheet',
      'tag': '🔥 PYQ SHEET',
      'badge': 'ADDED TODAY',
      'meta': 'State PCS • Quick Revision Chart',
      'color': 0xFFD97706,
      'url': 'https://www.mocktester.online',
    },
    {
      'title': 'General Science Physics & Chemistry Formula Sheet',
      'tag': '⚡ HIGH YIELD',
      'badge': 'NEW ADDED',
      'meta': 'Competitive Exams • All SI Units & Laws',
      'color': 0xFF2563EB,
      'url': 'https://www.mocktester.online',
    },
  ];

  List<Map<String, dynamic>> _displayDocs = [];

  @override
  void initState() {
    super.initState();
    _displayDocs = _fallbackDocs;

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _fetchLiveBooks();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveBooks() async {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await http
          .get(Uri.parse('$_booksJsonUrl?t=$ts'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        String body = utf8.decode(res.bodyBytes).trim();
        if (body.startsWith('\uFEFF')) body = body.substring(1).trim();

        final decoded = jsonDecode(body);
        if (decoded is List && decoded.isNotEmpty && mounted) {
          setState(() {
            _displayDocs = decoded.reversed.take(4).map<Map<String, dynamic>>((item) {
              final String board = (item['board'] ?? 'REFERENCE').toString().toUpperCase();
              final String cls = (item['class'] ?? 'Exam Notes').toString();
              final String lang = (item['lang'] ?? 'Hindi/En').toString();

              int colorVal = 0xFF2563EB;
              String tag = '⚡ HIGH YIELD';

              if (board.contains('NCERT')) {
                colorVal = 0xFF059669;
                tag = '🌿 NCERT CRUX';
              } else if (board.contains('PYQ')) {
                colorVal = 0xFFD97706;
                tag = '🔥 PYQ SHEET';
              } else if (board.contains('REFERENCE')) {
                colorVal = 0xFF7C3AED;
                tag = '🏛️ STANDARD';
              }

              return {
                'title': item['chapter'] ?? 'Study Material & Notes',
                'tag': tag,
                'badge': 'ADDED TODAY',
                'meta': '$cls • $lang Edition',
                'color': colorVal,
                'url': item['articleUrl'] ?? widget.customWebsiteUrl ?? _defaultWebsiteUrl,
              };
            }).toList();
          });
        }
      }
    } catch (_) {}
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
                          'Standard textbooks & curated test crux',
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
            ..._displayDocs.map((doc) {
              final Color accent = Color(doc['color'] as int);
              final String badgeText = doc['badge'] ?? 'NEW ADDED';
              final String docUrl = doc['url'] ?? _defaultWebsiteUrl;

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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
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
                                    doc['tag'],
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: accent,
                                      fontWeight: FontWeight.bold,
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
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
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
                    Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Open PDF Vault on Website',
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
