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
          content: Text(isSaved ? "Removed from Saved Vault" : "Saved to Vault 📌"),
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
    final bool isDark = widget.isDarkMode;

    final Color cardBg = isDark ? const Color(0xFF0C1322) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final Color actionBtnBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final Color actionBtnBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final Color sectionHeaderColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 2.5),
        ),
      );
    }

    if (_alertNewsList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🏆 1. TITLE HEADER & HIGH YIELD TAG (Container ke upar)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'First in India',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: sectionHeaderColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              // ⚡ HIGH YIELD TAG
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.6),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFD97706)),
                    SizedBox(width: 3),
                    Text(
                      'HIGH YIELD',
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 📇 2. MAIN CARD CONTAINER
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Top Accent Line[cite: 1, 2]
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                      ),
                    ),
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cards PageView
                    _ExpandablePageView(
                      controller: _pageController,
                      itemCount: _alertNewsList.length,
                      onPageChanged: (i) => setState(() => _activeIndex = i),
                      itemBuilder: (context, index) {
                        final item = _alertNewsList[index];
                        return _buildCardContent(item, isDark, actionBtnBg, actionBtnBorder);
                      },
                    ),

                    // Navigation Row: Previous • Alert X of Y • Next Alert[cite: 2]
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: _activeIndex > 0
                                ? () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    size: 18,
                                    color: _activeIndex > 0
                                        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                        : Colors.grey.withOpacity(0.3),
                                  ),
                                  Text(
                                    'Previous',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _activeIndex > 0
                                          ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                          : Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            'Alert ${_activeIndex + 1} of ${_alertNewsList.length}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _activeIndex < _alertNewsList.length - 1
                                ? () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : () {
                                    _pageController.animateToPage(
                                      0,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _activeIndex < _alertNewsList.length - 1 ? 'Next\nAlert' : 'First\nAlert',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, height: 1.1),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.black),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🌐 PERSISTENT WEBSITE ARCHIVE FOOTER
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B).withOpacity(0.55)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openUrl(_websiteFullDataUrl),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('🌐', style: TextStyle(fontSize: 13)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Read Full 2026 Monthly Archives on Website',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFFD97706)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContent(
    Map<String, dynamic> item,
    bool isDark,
    Color actionBtnBg,
    Color actionBtnBorder,
  ) {
    final List bullets = (item['bullets'] as List?) ?? [];
    final String itemId = (item['id'] ?? item['title'] ?? '').toString();
    final bool isSaved = _bookmarkedIds.contains(itemId);

    final bool hasLocation = item.containsKey('location') && (item['location'] ?? '').toString().isNotEmpty;
    final String secondaryTag = hasLocation
        ? item['location'].toString()
        : (item['category'] ?? 'General GK').toString();

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color bulletTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pills + Actions[cite: 2]
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFF59E0B).withOpacity(0.12) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.5 : 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨ 🏆', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      item['exam_tag'] ?? 'Static GK',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Secondary Tag (Pin sirf tab jab actual location ho)
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      hasLocation ? Icons.location_on_outlined : Icons.category_outlined,
                      size: 14,
                      color: hasLocation ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        secondaryTag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bookmark[cite: 2]
              InkWell(
                onTap: () => _toggleBookmark(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isSaved ? const Color(0xFFF59E0B).withOpacity(0.15) : actionBtnBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSaved ? const Color(0xFFF59E0B) : actionBtnBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 16,
                    color: isSaved
                        ? const Color(0xFFD97706)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Share[cite: 2]
              InkWell(
                onTap: () => _shareContent(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: actionBtnBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: actionBtnBorder, width: 1),
                  ),
                  child: Icon(
                    Icons.share_outlined,
                    size: 16,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title[cite: 2]
          Text(
            item['title'] ?? '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),

          // Bullets[cite: 2]
          ...bullets.map((bullet) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet.toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: bulletTextColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ExpandablePageView extends StatefulWidget {
  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;

  const _ExpandablePageView({
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
  });

  @override
  State<_ExpandablePageView> createState() => _ExpandablePageViewState();
}

class _ExpandablePageViewState extends State<_ExpandablePageView> {
  late List<double> _heights;
  int _currentPage = 0;

  double get _currentHeight =>
      (_heights.isEmpty || _currentPage >= _heights.length || _heights[_currentPage] == 0)
          ? 220
          : _heights[_currentPage];

  @override
  void initState() {
    super.initState();
    _heights = List.filled(widget.itemCount, 0.0);
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    final page = widget.controller.page?.round() ?? 0;
    if (_currentPage != page && page < _heights.length) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: _currentHeight,
      child: PageView.builder(
        controller: widget.controller,
        itemCount: widget.itemCount,
        onPageChanged: widget.onPageChanged,
        itemBuilder: (context, index) {
          return OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.topCenter,
            child: _ItemHeightNotifier(
              onHeightChange: (h) {
                if (index < _heights.length && _heights[index] != h) {
                  setState(() => _heights[index] = h);
                }
              },
              child: widget.itemBuilder(context, index),
            ),
          );
        },
      ),
    );
  }
}

class _ItemHeightNotifier extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeightChange;

  const _ItemHeightNotifier({required this.child, required this.onHeightChange});

  @override
  State<_ItemHeightNotifier> createState() => _ItemHeightNotifierState();
}

class _ItemHeightNotifierState extends State<_ItemHeightNotifier> {
  double _lastH = 0.0;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final h = box.size.height;
          if (_lastH != h) {
            _lastH = h;
            widget.onHeightChange(h);
          }
        }
      }
    });
    return widget.child;
  }
}
