import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  State<ProPdfVaultCard> createState() => ProPdfVaultCardState();
}

class ProPdfVaultCardState extends State<ProPdfVaultCard> {
  static const String _defaultWebsiteUrl = "https://www.mocktester.online";

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 🛡️ Fallback Data
  final List<Map<String, dynamic>> _fallbackDocs = [
    {
      'title': 'M. Laxmikanth: Indian Polity (6th Edition)',
      'tag': '🏛️ STANDARD',
      'badge': 'UPDATED',
      'meta': 'Civil Services • Hindi/En Edition',
      'color': 0xFF7C3AED,
      'url': 'https://www.mocktester.online',
    },
    {
      'title': 'NCERT Science & GK 1-Liner Crux',
      'tag': '🌿 NCERT CRUX',
      'badge': 'POPULAR',
      'meta': 'Class 8-12 • Complete Handnotes',
      'color': 0xFF059669,
      'url': 'https://www.mocktester.online',
    },
    {
      'title': 'BPSC & BSSC 3000+ TCS PYQ Formula Sheet',
      'tag': '🔥 PYQ SHEET',
      'badge': 'HOT',
      'meta': 'State PCS • Quick Revision Chart',
      'color': 0xFFD97706,
      'url': 'https://www.mocktester.online',
    },
    {
      'title': 'General Science Physics & Chemistry Formula Sheet',
      'tag': '⚡ HIGH YIELD',
      'badge': 'NEW',
      'meta': 'Competitive Exams • All SI Units & Laws',
      'color': 0xFF2563EB,
      'url': 'https://www.mocktester.online',
    },
  ];

  List<Map<String, dynamic>> _allLiveDocs = [];

  @override
  void initState() {
    super.initState();
    if (widget.dynamicPdfItems != null && widget.dynamicPdfItems!.isNotEmpty) {
      _allLiveDocs = widget.dynamicPdfItems!.reversed.map<Map<String, dynamic>>((item) {
        return _formatItem(item);
      }).toList();
    } else {
      fetchLiveBooks();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _formatItem(dynamic item) {
    if (item is Map) {
      final String board = (item['board'] ?? 'REFERENCE').toString().toUpperCase();
      final String cls = (item['class'] ?? 'Exam Notes').toString();
      final String lang = (item['lang'] ?? 'Hindi/En').toString();
      final String chapter = (item['chapter'] ?? item['title'] ?? 'Study Material & Notes').toString();

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
        'title': chapter,
        'tag': item['tag'] ?? tag,
        'badge': item['badge'] ?? 'NEW',
        'meta': item['meta'] ?? '$cls • $lang Edition',
        'color': item['color'] != null ? (int.tryParse(item['color'].toString()) ?? colorVal) : colorVal,
        'url': item['articleUrl'] ?? item['url'] ?? widget.customWebsiteUrl ?? _defaultWebsiteUrl,
      };
    }
    return {
      'title': item.toString(),
      'tag': 'FREE PDF',
      'badge': 'NEW',
      'meta': 'Online Notes',
      'color': 0xFF2563EB,
      'url': widget.customWebsiteUrl ?? _defaultWebsiteUrl,
    };
  }

  // 🔄 Public Live Fetch with Anti-Cache & CDN Fallbacks
  Future<void> fetchLiveBooks() async {
    final int ts = DateTime.now().millisecondsSinceEpoch;

    final List<String> endpoints = [
      "https://raw.githubusercontent.com/zxcty54/content_base/main/books_database.json?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/books_database.json?t=$ts",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/books_database.json?t=$ts",
    ];

    for (final url in endpoints) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: const {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 7));

        if (res.statusCode == 200) {
          String body = utf8.decode(res.bodyBytes).trim();
          if (body.startsWith('\uFEFF')) body = body.substring(1).trim();

          final decoded = jsonDecode(body);
          List<dynamic> rawList = [];

          if (decoded is List) {
            rawList = decoded;
          } else if (decoded is Map && decoded['books'] is List) {
            rawList = decoded['books'];
          }

          if (rawList.isNotEmpty && mounted) {
            setState(() {
              _allLiveDocs = rawList.reversed.map<Map<String, dynamic>>((item) {
                return _formatItem(item);
              }).toList();
            });
            return;
          }
        }
      } catch (_) {
        continue;
      }
    }
  }

  List<Map<String, dynamic>> _getVisibleDocs() {
    final sourceList = _allLiveDocs.isNotEmpty ? _allLiveDocs : _fallbackDocs;

    if (_searchQuery.isEmpty) {
      return sourceList.take(4).toList();
    }

    return sourceList.where((doc) {
      final title = (doc['title'] ?? '').toString().toLowerCase();
      final meta = (doc['meta'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || meta.contains(q);
    }).take(6).toList();
  }

  Future<void> _launchUrl(String targetUrl) async {
    final Uri uri = Uri.parse(targetUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $uri';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('⚠️ Link open nahi ho saka.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final visibleDocs = _getVisibleDocs();

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final itemBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📚 Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study Material & PDF Vault',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Standard notes & formula sheets',
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '100% FREE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 🔍 Search Bar
            TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13.5, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search books, notes, subjects...',
                hintStyle: TextStyle(fontSize: 13, color: subTextColor),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: itemBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),

            const SizedBox(height: 12),

            // 📋 Document List
            if (visibleDocs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Koi document nahi mila.',
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
                ),
              )
            else
              ...visibleDocs.map((doc) {
                final Color accent = Color(doc['color'] as int);
                final String badgeText = (doc['badge'] ?? 'NEW').toString().toUpperCase();
                final String docUrl = doc['url'] ?? _defaultWebsiteUrl;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Material(
                    color: itemBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _launchUrl(docUrl),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 44,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFFDC2626)),
                                  const SizedBox(height: 1),
                                  Text(
                                    'PDF',
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: accent),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          badgeText,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        doc['tag'],
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doc['title'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    doc['meta'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: subTextColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: subTextColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 6),

            // 🌐 Bottom CTA Button
            Material(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => _launchUrl(widget.customWebsiteUrl ?? _defaultWebsiteUrl),
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Browse Full E-Library & Vault',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
