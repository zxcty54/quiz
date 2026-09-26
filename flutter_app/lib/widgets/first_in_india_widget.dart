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
    final String url = item['url'] ?? 'https://www.mocktester.online';
    Share.share('🏆 *First in India Alert*\n\n*$title*\n\nRead more: $url');
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url);
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
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF0C1322),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B), strokeWidth: 2.5),
        ),
      );
    }

    if (_alertNewsList.isEmpty) return const SizedBox.shrink();

    const cardBg = Color(0xFF0C1322);
    const borderColor = Color(0xFF1E293B);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 🌈 Top Glowing Yellow Accent Strip[cite: 1]
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
                // 📄 Auto-Sizing Cards (No Inner Scroll)
                _ExpandablePageView(
                  controller: _pageController,
                  itemCount: _alertNewsList.length,
                  onPageChanged: (i) => setState(() => _activeIndex = i),
                  itemBuilder: (context, index) {
                    final item = _alertNewsList[index];
                    return _buildCardContent(item);
                  },
                ),

                // 🔘 Bottom Navigation Action Bar[cite: 1]
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous Button[cite: 1]
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
                                color: _activeIndex > 0 ? const Color(0xFF64748B) : Colors.white12,
                              ),
                              Text(
                                'Previous',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _activeIndex > 0 ? const Color(0xFF64748B) : Colors.white12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Counter Subtext[cite: 1]
                      Text(
                        'Alert ${_activeIndex + 1} of ${_alertNewsList.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),

                      // Next Alert Button[cite: 1]
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(Map<String, dynamic> item) {
    final List bullets = (item['bullets'] as List?) ?? [];
    final String itemUrl = item['url'] ?? '';
    final String itemId = (item['id'] ?? item['title'] ?? '').toString();
    final bool isSaved = _bookmarkedIds.contains(itemId);

    final String location = (item['location'] ?? item['category'] ?? 'National').toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TOP ROW: Tag Pill + Location + Bookmark + Share[cite: 1]
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨ 🏆', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      item['exam_tag'] ?? 'First in India',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Location Pill[cite: 1]
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFE11D48)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bookmark Button[cite: 1]
              InkWell(
                onTap: () => _toggleBookmark(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isSaved
                        ? const Color(0xFFF59E0B).withOpacity(0.2)
                        : const Color(0xFF1E293B).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSaved ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 16,
                    color: isSaved ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Share Button[cite: 1]
              InkWell(
                onTap: () => _shareContent(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155), width: 1),
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. MAIN TITLE[cite: 1]
          InkWell(
            onTap: () => _openUrl(itemUrl),
            child: Text(
              item['title'] ?? '',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. CYAN CHECK BULLETS (Direct Clean Points)[cite: 1]
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
                      color: Color(0xFF06B6D4), // Cyan color from screenshot[cite: 1]
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet.toString(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFCBD5E1),
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

// 📐 Smooth Auto-Sizing PageView (Calculates exact height per card)
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
