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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 🛡️ Fallback Data (Instant Rendering)
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

  List<Map<String, dynamic>> _allLiveDocs = [];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _fetchLiveBooks();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _searchController.dispose();
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
            _allLiveDocs = decoded.reversed.map<Map<String, dynamic>>((item) {
              final String board = (item['board'] ?? 'REFERENCE').toString().toUpperCase();
              final String cls = (item['class'] ?? 'Exam Notes').toString();
              final String lang = (item['lang'] ?? 'Hindi/En').toString();
              final String chapter = (item['chapter'] ?? 'Study Material & Notes').toString();

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
    final visibleDocs = _getVisibleDocs();

    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
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
            // 📚 HEADER
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
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Search standard books & handwritten notes',
                          style: TextStyle(fontSize: 11, color: subTextColor),
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

            // 🔍 SEARCH INPUT BOX
            TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search book (e.g. Laxmikanth, NCERT, History)...',
                hintStyle: TextStyle(fontSize: 12, color: subTextColor),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF2563EB)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
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
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

            const SizedBox(height: 10),

            // 📋 SEARCH RESULTS / LATEST BOOKS LIST
            if (visibleDocs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Koi book nahi mili. Dusra naam search karein!',
                    style: TextStyle(fontSize: 11.5, color: subTextColor),
                  ),
                ),
              )
            else
              ...visibleDocs.map((doc) {
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
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          // PDF Icon
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

                          // Book Info
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
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  doc['meta'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 9.5, color: subTextColor),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 6),
                          const Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 4),

            // 🌐 DIRECT FULL LIBRARY LINK
            InkWell(
              onTap: () => _launchUrl(widget.customWebsiteUrl ?? _defaultWebsiteUrl),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                    Icon(Icons.library_books_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Browse Full E-Library & Vault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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
