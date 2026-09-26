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
          content: Text(isSaved ? "Removed from Vault" : "Saved to Vault 📌"),
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

    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 2.5),
        ),
      );
    }

    if (_alertNewsList.isEmpty) return const SizedBox.shrink();

    // 🎨 Ultra-clean Eye-Catching Shadows & Gradients
    final BoxDecoration cardDecoration = BoxDecoration(
      gradient: isDark
          ? const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFDF7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.08 : 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.35 : 0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🏆 Top Header with High Yield Badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text('🏆', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'First in India Express',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Direct Scoring 1-Liners for Exams',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // High Yield Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'HIGH YIELD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 📇 Main Focus Card
        Container(
          width: double.infinity,
          decoration: cardDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Top Glowing Amber Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 4.5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEA580C), Color(0xFFDC2626)],
                      ),
                    ),
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Content PageView
                    _ExpandablePageView(
                      controller: _pageController,
                      itemCount: _alertNewsList.length,
                      onPageChanged: (i) => setState(() => _activeIndex = i),
                      itemBuilder: (context, index) {
                        return _buildCardContent(_alertNewsList[index], isDark);
                      },
                    ),

                    // Bottom Navigation Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Previous Button
                          InkWell(
                            onTap: _activeIndex > 0
                                ? () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 13,
                                    color: _activeIndex > 0
                                        ? const Color(0xFFD97706)
                                        : Colors.grey.withOpacity(0.35),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Prev',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _activeIndex > 0
                                          ? const Color(0xFFD97706)
                                          : Colors.grey.withOpacity(0.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Dots + Counter Center
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              '${_activeIndex + 1} of ${_alertNewsList.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),

                          // Next Alert Button (Vibrant Pill)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (_activeIndex < _alertNewsList.length - 1) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  );
                                } else {
                                  _pageController.animateToPage(
                                    0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withOpacity(0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _activeIndex < _alertNewsList.length - 1 ? 'Next Alert' : 'First Alert',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Persistent Bottom Website Archive Link
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.3 : 0.4),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openUrl(_websiteFullDataUrl),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('🌐', style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Explore All 2026 Archives on Website',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFFD97706)),
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

  Widget _buildCardContent(Map<String, dynamic> item, bool isDark) {
    final List bullets = (item['bullets'] as List?) ?? [];
    final String itemId = (item['id'] ?? item['title'] ?? '').toString();
    final bool isSaved = _bookmarkedIds.contains(itemId);

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color bulletTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: Exam Tag Pill + Spacer + Bookmark/Share
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡ 🏆', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      item['exam_tag'] ?? 'First in India / Static GK',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bookmark
              InkWell(
                onTap: () => _toggleBookmark(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isSaved
                        ? const Color(0xFFF59E0B).withOpacity(0.2)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSaved ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 17,
                    color: isSaved ? const Color(0xFFD97706) : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Share
              InkWell(
                onTap: () => _shareContent(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    size: 17,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // News Heading
          Text(
            item['title'] ?? '',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: titleColor,
              height: 1.32,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 12),

          // High Contrast Bullets
          ...bullets.map((bullet) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bullet.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: bulletTextColor,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
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
