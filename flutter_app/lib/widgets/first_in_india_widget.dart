import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🏆 FirstInIndiaWidget V2 (Enhanced Flashcards UI/UX + Live Vault Bookmark Sync)
class FirstInIndiaWidget extends StatefulWidget {
  final bool isDarkMode;
  const FirstInIndiaWidget({super.key, required this.isDarkMode});

  @override
  State<FirstInIndiaWidget> createState() => FirstInIndiaWidgetState(); // 👈 Public State return
}

// 👈 Class se '_' hata diya gaya hai taaki home_tab.dart ki GlobalKey compile ho sake
class FirstInIndiaWidgetState extends State<FirstInIndiaWidget> {
  List<dynamic> _alertNewsList = [];
  bool _isLoading = true;
  int _activeIndex = 0;
  final PageController _pageController = PageController();
  final Set<String> _bookmarkedIds = {};

  static const String _websiteFullDataUrl =
      "https://www.mocktester.online/p/indias-first-in-news-2026.html";
  static const String _savedVaultKey = 'saved_daily_bulletins';

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    fetchFirstInIndia();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 💾 Saved vault se status load karna
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString(_savedVaultKey);
    if (savedJson != null) {
      try {
        final List decoded = jsonDecode(savedJson);
        if (mounted) {
          setState(() {
            _bookmarkedIds.addAll(
              decoded.map((e) => (e['title'] ?? '').toString()).where((t) => t.isNotEmpty),
            );
          });
        }
      } catch (_) {}
    }
  }

  // 🔖 Vault me save / remove karna
  Future<void> _toggleBookmark(Map<String, dynamic> item) async {
    final String itemId = (item['title'] ?? '').toString();
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
        currentList.removeWhere((e) => (e['title'] ?? '') == itemId);
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
          content: Text(isSaved ? "Removed from Saved Vault" : "Saved to Vault 📌"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // 🔄 Public method for Pull-to-Refresh from home_tab.dart
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

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String newsUrl =
        "https://raw.githubusercontent.com/zxcty54/content_base/main/app_alerts_news.json?t=$timestamp";

    try {
      final res = await http.get(Uri.parse(newsUrl)).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        String decoded = utf8.decode(res.bodyBytes);
        final data = jsonDecode(decoded);

        if (mounted) {
          setState(() {
            _alertNewsList = _extractList(data);
            _isLoading = false;
          });
        }

        await prefs.setString(cacheDataKey, decoded);
        await prefs.setString(cacheDateKey, todayStr);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    if (_isLoading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 2.5),
        ),
      );
    }

    if (_alertNewsList.isEmpty) return const SizedBox.shrink();

    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🏆 HEADER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, size: 20, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First in India Express',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Daily 1-Liner Exam Flashcards',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24), width: 0.8),
              ),
              child: Text(
                '${_activeIndex + 1}/${_alertNewsList.length}',
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 🏷️ QUICK TOPIC SELECTOR CHIPS
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_alertNewsList.length, (idx) {
              final isSelected = _activeIndex == idx;
              final item = _alertNewsList[idx];
              final String label = (item['category'] ?? 'Alert').toString().split(' ').first;

              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: InkWell(
                  onTap: () {
                    _pageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD97706)
                          : (isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${idx + 1} $label',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),

        // 📄 SWIPEABLE FLASHCARD PAGEVIEW
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _alertNewsList.length,
            onPageChanged: (i) => setState(() => _activeIndex = i),
            itemBuilder: (context, index) {
              final item = _alertNewsList[index];
              return _buildCardItem(item, isDark, cardBg, borderColor, textColor);
            },
          ),
        ),
        const SizedBox(height: 10),

        // 🌐 PERSISTENT FOOTER: Opens full archives
        InkWell(
          onTap: () => _openUrl(_websiteFullDataUrl),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155).withOpacity(0.4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('🌐', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 8),
                    Text(
                      'Read All 120+ First in India Archives',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFD97706)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardItem(
    Map<String, dynamic> item,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
  ) {
    final List bullets = (item['bullets'] as List?) ?? [];
    final String itemUrl = item['url'] ?? _websiteFullDataUrl;
    final String itemId = (item['title'] ?? '').toString();
    final bool isSaved = _bookmarkedIds.contains(itemId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag, Date & Bookmark Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item['exam_tag'] ?? '🏆 First in India',
                  style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: [
                  Text(
                    item['date'] ?? '',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _toggleBookmark(item),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 20,
                        color: isSaved ? const Color(0xFFD97706) : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          InkWell(
            onTap: () => _openUrl(itemUrl),
            child: Text(
              item['title'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textColor, height: 1.25),
            ),
          ),
          const SizedBox(height: 8),

          // Bullets
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: bullets.length,
              itemBuilder: (ctx, idx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bullets[idx].toString(),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
