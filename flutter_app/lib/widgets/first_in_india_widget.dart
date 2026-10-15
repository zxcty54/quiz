import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FirstInIndiaWidget extends StatefulWidget {
  final bool isDarkMode;
  const FirstInIndiaWidget({super.key, required this.isDarkMode});

  @override
  State<FirstInIndiaWidget> createState() => FirstInIndiaWidgetState();
}

class FirstInIndiaWidgetState extends State<FirstInIndiaWidget> {
  List<dynamic> _alertNewsList = [];
  bool _isLoading = true;
  int _activeIndex = 0;
  late final PageController _pageController;
  final Set<String> _bookmarkedIds = {};

  static const String _websiteFullDataUrl =
      "https://www.mocktester.online/p/indias-first-in-news-2026.html";
  static const String _savedVaultKey = 'saved_daily_bulletins';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadBookmarks();
    fetchFirstInIndia();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString(_savedVaultKey);
    if (savedJson != null) {
      try {
        final List decoded = jsonDecode(savedJson);
        if (mounted) {
          setState(() {
            _bookmarkedIds.addAll(
              decoded
                  .map((e) => (e['id'] ?? e['title'] ?? '').toString())
                  .where((t) => t.isNotEmpty),
            );
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _toggleBookmark(Map<String, dynamic> item) async {
    final String itemId = (item['id'] ?? item['title'] ?? '').toString();
    if (itemId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString(_savedVaultKey);
    List<dynamic> currentList = [];

    if (savedJson != null) {
      try {
        currentList = jsonDecode(savedJson);
      } catch (_) {}
    }

    final bool isSaved = _bookmarkedIds.contains(itemId);

    setState(() {
      if (isSaved) {
        _bookmarkedIds.remove(itemId);
        currentList.removeWhere((e) => (e['id'] ?? e['title'] ?? '') == itemId);
      } else {
        _bookmarkedIds.add(itemId);
        currentList.add(item);
      }
    });

    await prefs.setString(_savedVaultKey, jsonEncode(currentList));

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSaved ? "Vault se hata diya gaya" : "Vault me save ho gaya 📌"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareContent(Map<String, dynamic> item) {
    final String title = item['title'] ?? '';
    final String url = item['url'] ?? _websiteFullDataUrl;
    Share.share('🏆 *First in India Alert*\n\n*$title*\n\nRead more on MockTester: $url');
  }

  Future<void> _openUrl(String url) async {
    final target = url.trim().isNotEmpty ? url.trim() : _websiteFullDataUrl;
    final Uri uri = Uri.parse(target);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> fetchFirstInIndia({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String todayStr = DateTime.now().toIso8601String().split('T')[0];
    const String cacheDataKey = 'cached_app_alerts_news_json';
    const String cacheDateKey = 'cached_app_alerts_news_date';

    final String savedDate = prefs.getString(cacheDateKey) ?? '';
    if (!forceRefresh && savedDate == todayStr) {
      String? cachedJson = prefs.getString(cacheDataKey);
      if (cachedJson != null) {
        try {
          final data = jsonDecode(cachedJson);
          if (mounted) {
            setState(() {
              _alertNewsList = _extractList(data);
              _isLoading = false;
            });
            return;
          }
        } catch (_) {}
      }
    }

    final int ts = DateTime.now().millisecondsSinceEpoch;
    const String relativeFilePath = "app_alerts_news.json";

    final List<String> cdnEndpoints = [
      "https://cdn.statically.io/gh/zxcty54/content_base/main/$relativeFilePath?t=$ts",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/$relativeFilePath?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/$relativeFilePath?t=$ts",
      "https://raw.githack.com/zxcty54/content_base/main/$relativeFilePath",
      "https://raw.githubusercontent.com/zxcty54/content_base/main/$relativeFilePath?t=$ts",
    ];

    dynamic parsedData;
    String? rawJsonSuccess;

    for (final url in cdnEndpoints) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Cache-Control': 'no-cache',
            'User-Agent': 'MockTesterApp-Flutter',
          },
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          String rawBody = utf8.decode(res.bodyBytes).trim();
          if (rawBody.startsWith('\uFEFF')) rawBody = rawBody.substring(1).trim();

          if (!rawBody.startsWith('<') && !rawBody.startsWith('<!DOCTYPE')) {
            final decoded = jsonDecode(rawBody);
            if (decoded != null) {
              parsedData = decoded;
              rawJsonSuccess = rawBody;
              break;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (mounted) {
      if (parsedData != null) {
        setState(() {
          _alertNewsList = _extractList(parsedData);
          _isLoading = false;
        });

        if (rawJsonSuccess != null) {
          await prefs.setString(cacheDataKey, rawJsonSuccess);
          await prefs.setString(cacheDateKey, todayStr);
        }
      } else {
        String? oldCache = prefs.getString(cacheDataKey);
        if (oldCache != null) {
          try {
            final fallbackDecoded = jsonDecode(oldCache);
            setState(() {
              _alertNewsList = _extractList(fallbackDecoded);
            });
          } catch (_) {}
        }
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is Map && data.containsKey('alert_news')) {
      return data['alert_news'] as List;
    } else if (data is List) {
      return data;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;

    if (_isLoading) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: const CircularProgressIndicator.adaptive(),
      );
    }

    if (_alertNewsList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🏆 Top Header Section
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
                      color: const Color(0xFFF59E0B).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('🏆', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'First in India Express',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swipe_rounded, size: 12, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(
                      '${_activeIndex + 1}/${_alertNewsList.length}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 📇 Main Card Container with Swipeable PageView
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // 👈👉 SWIPEABLE CONTENT AREA
              SizedBox(
                height: 235,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _alertNewsList.length,
                  onPageChanged: (i) => setState(() => _activeIndex = i),
                  itemBuilder: (context, index) {
                    final item = _alertNewsList[index];
                    final String itemId = (item['id'] ?? item['title'] ?? '').toString();
                    final bool isSaved = _bookmarkedIds.contains(itemId);
                    final List bullets = (item['bullets'] as List?) ?? [];

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Tag + Bookmark + Share
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (item['exam_tag'] ?? 'STATIC GK / PYQ').toString().toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFD97706),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  size: 20,
                                  color: isSaved ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                ),
                                onPressed: () => _toggleBookmark(item),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 19,
                                  color: Color(0xFF94A3B8),
                                ),
                                onPressed: () => _shareContent(item),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Title
                          Text(
                            item['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Bullets
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: bullets.map((bullet) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4.5),
                                          child: Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            bullet.toString(),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.4,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? const Color(0xFFCBD5E1)
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),

              // Bottom Bar: Website Archive link + Smooth Navigation Arrows
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _openUrl(_websiteFullDataUrl),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.public_rounded, size: 14, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text(
                              'Full 2026 Archive',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                          color: _activeIndex > 0
                              ? (isDark ? Colors.white70 : const Color(0xFF334155))
                              : Colors.grey.withOpacity(0.3),
                          onPressed: _activeIndex > 0
                              ? () => _pageController.previousPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  )
                              : null,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          color: _activeIndex < _alertNewsList.length - 1
                              ? const Color(0xFF2563EB)
                              : Colors.grey.withOpacity(0.3),
                          onPressed: _activeIndex < _alertNewsList.length - 1
                              ? () => _pageController.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  )
                              : () => _pageController.animateToPage(
                                    0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
