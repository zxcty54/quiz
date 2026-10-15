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
  State<ProPdfVaultCard> createState() => ProPdfVaultCardState();
}

class ProPdfVaultCardState extends State<ProPdfVaultCard> {
  static const String _defaultWebsiteUrl = "https://www.mocktester.online";

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  List<Map<String, dynamic>> _allLiveDocs = [];

  @override
  void initState() {
    super.initState();
    fetchLiveBooks();
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

      int colorVal = 0xFF2563EB; // Royal Blue
      String tag = 'HIGH YIELD';

      if (board.contains('NCERT')) {
        colorVal = 0xFF059669; // Emerald Green
        tag = 'NCERT CRUX';
      } else if (board.contains('PYQ')) {
        colorVal = 0xFFD97706; // Amber
        tag = 'PYQ SHEET';
      } else if (board.contains('REFERENCE')) {
        colorVal = 0xFF1D4ED8; // Cobalt Blue
        tag = 'STANDARD NOTES';
      }

      return {
        'id': item['id'] ?? 0,
        'title': chapter,
        'tag': item['tag'] ?? tag,
        'badge': item['badge'] ?? 'PDF',
        'meta': item['meta'] ?? '$cls • $lang Edition',
        'color': item['color'] != null ? (int.tryParse(item['color'].toString()) ?? colorVal) : colorVal,
        'url': item['articleUrl'] ?? item['url'] ?? widget.customWebsiteUrl ?? _defaultWebsiteUrl,
      };
    }
    return {
      'id': 0,
      'title': item.toString(),
      'tag': 'FREE PDF',
      'badge': 'PDF',
      'meta': 'Online Notes',
      'color': 0xFF2563EB,
      'url': widget.customWebsiteUrl ?? _defaultWebsiteUrl,
    };
  }

  Future<void> fetchLiveBooks() async {
    final int ts = DateTime.now().millisecondsSinceEpoch;

    final List<String> endpoints = [
      "https://cdn.statically.io/gh/zxcty54/content_base/main/books_database.json?t=$ts",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/books_database.json?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/books_database.json?t=$ts",
      "https://raw.githubusercontent.com/zxcty54/content_base/main/books_database.json?t=$ts",
    ];

    for (final url in endpoints) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: const {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          String body = utf8.decode(res.bodyBytes).trim();
          if (body.startsWith('\uFEFF')) body = body.substring(1).trim();

          final dynamic decoded = jsonDecode(body);
          List<dynamic> rawList = [];

          if (decoded is List) {
            rawList = decoded;
          } else if (decoded is Map) {
            for (final val in decoded.values) {
              if (val is List) {
                rawList = val;
                break;
              }
            }
          }

          if (rawList.isNotEmpty && mounted) {
            List<Map<String, dynamic>> parsedDocs = rawList.map<Map<String, dynamic>>((item) {
              return _formatItem(item);
            }).toList();

            parsedDocs.sort((a, b) {
              final num idA = num.tryParse(a['id']?.toString() ?? '0') ?? 0;
              final num idB = num.tryParse(b['id']?.toString() ?? '0') ?? 0;
              return idB.compareTo(idA);
            });

            setState(() {
              _allLiveDocs = parsedDocs;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getVisibleDocs() {
    if (_searchQuery.isEmpty) {
      return _allLiveDocs.take(4).toList();
    }

    return _allLiveDocs.where((doc) {
      final title = (doc['title'] ?? '').toString().toLowerCase();
      final meta = (doc['meta'] ?? '').toString().toLowerCase();
      final tag = (doc['tag'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || meta.contains(q) || tag.contains(q);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 📚 Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Study Material & PDF Vault',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '100% FREE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 📇 Main Container Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔍 Clean Search Box
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: itemBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 13, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search NCERT, PYQ, formulas, notes...',
                      hintStyle: TextStyle(fontSize: 12.5, color: subTextColor),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF2563EB)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),

                const SizedBox(height: 12),

                // 📋 PDF Document List
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  )
                else if (visibleDocs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Koi notes ya PDF nahi mila.',
                        style: TextStyle(fontSize: 12.5, color: subTextColor),
                      ),
                    ),
                  )
                else
                  ...visibleDocs.map((doc) {
                    final Color accent = Color(doc['color'] as int);
                    final String docUrl = doc['url'] ?? _defaultWebsiteUrl;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Material(
                        color: itemBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _launchUrl(docUrl),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Document Icon Pill
                                Container(
                                  width: 38,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.description_rounded, size: 20, color: accent),
                                ),
                                const SizedBox(width: 12),

                                // Title & Meta
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: accent.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              doc['tag'],
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: accent,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        doc['title'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
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

                                // Read Action Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Open',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.arrow_forward_rounded, size: 12, color: subTextColor),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 6),

                // 🌐 Bottom CTA Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text(
                      'Browse Full E-Library & Vault',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _launchUrl(widget.customWebsiteUrl ?? _defaultWebsiteUrl),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
