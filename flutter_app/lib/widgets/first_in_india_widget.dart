import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // ✅ FIX: 'static const' added here
  static const String _websiteFullDataUrl = "https://www.mocktester.online/p/indias-first-in-news-2026.html";

  @override
  void initState() {
    super.initState();
    fetchFirstInIndia();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  // 📰 PUBLIC FETCH METHOD (Pull-to-Refresh Support)
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
    final String newsUrl = "https://raw.githubusercontent.com/zxcty54/quiz/refs/heads/main/app_alerts_news.json?t=$timestamp";

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
    } catch (e) {
      debugPrint("Error fetching Alert News: $e");
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
        padding: const EdgeInsets.symmetric(vertical: 24),
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

    // Total Items = News Count + 1 (Last Card for Website Redirection)
    final int totalCardCount = _alertNewsList.length + 1;

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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, size: 20, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 8),
                Text(
                  'First in India Express',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: widget.isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24), width: 0.8),
              ),
              child: Text(
                '${_alertNewsList.length} Active Alerts',
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // DYNAMIC EXPANDABLE CAROUSEL
        ExpandablePageView(
          controller: _pageController,
          itemCount: totalCardCount,
          onPageChanged: (index) {
            setState(() => _activeIndex = index);
          },
          itemBuilder: (context, index) {
            // IF LAST CARD ➔ SHOW WEBSITE LINK CARD
            if (index == _alertNewsList.length) {
              return _buildWebsiteRedirectLastCard();
            }
            // REGULAR NEWS CARDS
            return _buildAlertNewsCard(_alertNewsList[index]);
          },
        ),
        const SizedBox(height: 10),

        // INDICATOR DOTS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalCardCount, (index) {
            bool isActive = _activeIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 5,
              width: isActive ? 22 : 6,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFD97706)
                    : (widget.isDarkMode ? Colors.white24 : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  // 📇 REGULAR NEWS CARD
  Widget _buildAlertNewsCard(Map<String, dynamic> item) {
    final List bullets = (item['bullets'] as List?) ?? [];
    final String itemUrl = item['url'] ?? '';

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDarkMode ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. EXAM TAG & DATE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.isDarkMode ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  item['exam_tag'] ?? '🏆 First in India',
                  style: TextStyle(
                    color: widget.isDarkMode ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item['date'] != null)
                Text(
                  item['date'].toString(),
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. CATEGORY
          if (item['category'] != null && item['category'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                '📌 ${item['category']}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
            ),

          // 3. TITLE
          InkWell(
            onTap: () => _openUrl(itemUrl),
            child: Text(
              item['title'] ?? '',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                letterSpacing: -0.2,
                height: 1.28,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 4. BULLET POINTS
          Column(
            children: bullets.map((bullet) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        bullet.toString(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: widget.isDarkMode ? Colors.white70 : const Color(0xFF334155),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 🌐 LAST CARD: WEBSITE REDIRECTION BANNER
  Widget _buildWebsiteRedirectLastCard() {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? [const Color(0xFF78350F), const Color(0xFF451A03)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.language_rounded, size: 28, color: Color(0xFFD97706)),
          ),
          const SizedBox(height: 10),

          Text(
            'Explore Complete Monthly Data 🌐',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: widget.isDarkMode ? Colors.white : const Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Is mahine ke saare "First in India & World 2026" updates, archives aur PDF notes humare official website par milenge.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF92400E),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openUrl(_websiteFullDataUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Read Complete List on Website',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.open_in_new_rounded, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 📐 DYNAMIC EXPANDABLE PAGE VIEW HELPER
class ExpandablePageView extends StatefulWidget {
  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;

  const ExpandablePageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
  });

  @override
  State<ExpandablePageView> createState() => _ExpandablePageViewState();
}

class _ExpandablePageViewState extends State<ExpandablePageView> {
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
    widget.controller.addListener(_updatePage);
  }

  void _updatePage() {
    final newPage = widget.controller.page?.round() ?? 0;
    if (_currentPage != newPage && newPage < _heights.length) {
      setState(() {
        _currentPage = newPage;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updatePage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
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
            child: SizeReportingWidget(
              onSizeChange: (size) {
                if (index < _heights.length && _heights[index] != size.height) {
                  setState(() {
                    _heights[index] = size.height;
                  });
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

class SizeReportingWidget extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSizeChange;

  const SizeReportingWidget({
    super.key,
    required this.child,
    required this.onSizeChange,
  });

  @override
  State<SizeReportingWidget> createState() => _SizeReportingWidgetState();
}

class _SizeReportingWidgetState extends State<SizeReportingWidget> {
  Size _oldSize = Size.zero;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final newSize = context.size;
        if (newSize != null && _oldSize != newSize) {
          _oldSize = newSize;
          widget.onSizeChange(newSize);
        }
      }
    });
    return widget.child;
  }
}
