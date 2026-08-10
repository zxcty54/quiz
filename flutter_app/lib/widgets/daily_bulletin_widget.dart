import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DailyBulletinWidget extends StatefulWidget {
  final bool isDarkMode;
  const DailyBulletinWidget({super.key, required this.isDarkMode});

  @override
  State<DailyBulletinWidget> createState() => DailyBulletinWidgetState();
}

class DailyBulletinWidgetState extends State<DailyBulletinWidget> {
  List<dynamic> _allNewsList = [];
  List<dynamic> _savedNewsList = [];
  bool _isLoadingNews = true;

  int _selectedNewsTab = 0; // 0 = Bihar, 1 = National
  int _activeNewsIndex = 0;
  final PageController _newsPageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadSavedNews();
    fetchDailyBulletins();
  }

  @override
  void dispose() {
    _newsPageController.dispose();
    super.dispose();
  }

  // 💾 LOAD SAVED BULLETINS FROM LOCAL STORAGE
  Future<void> _loadSavedNews() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('saved_daily_bulletins');
    if (savedJson != null) {
      try {
        if (mounted) {
          setState(() {
            _savedNewsList = jsonDecode(savedJson);
          });
        }
      } catch (e) {
        debugPrint("Error loading saved bulletins: $e");
      }
    }
  }

  // 📌 TOGGLE SAVE / UNSAVE BULLETIN
  Future<void> _toggleSaveNews(Map<String, dynamic> news) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      bool isAlreadySaved = _savedNewsList.any((item) => item['title'] == news['title']);

      if (isAlreadySaved) {
        _savedNewsList.removeWhere((item) => item['title'] == news['title']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Removed from Saved Current Affairs"),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        _savedNewsList.add(news);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved to Current Affairs! 📌"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });

    await prefs.setString('saved_daily_bulletins', jsonEncode(_savedNewsList));
  }

  // 📰 PUBLIC FETCH METHOD (Pull-to-Refresh ke liye)
  Future<void> fetchDailyBulletins({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String todayStr = DateTime.now().toIso8601String().split('T')[0];

    const String cacheNewsData = 'cached_final_news_single_json';
    const String cacheDate = 'cached_bulletin_date';

    final String savedDate = prefs.getString(cacheDate) ?? '';

    if (!forceRefresh && savedDate == todayStr) {
      String? cachedJson = prefs.getString(cacheNewsData);
      if (cachedJson != null) {
        try {
          final data = jsonDecode(cachedJson);
          if (mounted) {
            setState(() {
              _allNewsList = _parseNewsList(data);
              _isLoadingNews = false;
            });
            return;
          }
        } catch (_) {}
      }
    }

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String newsUrl = "https://raw.githubusercontent.com/zxcty54/quiz/main/finalnews.json?t=$timestamp";

    try {
      final res = await http.get(Uri.parse(newsUrl)).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        String decoded = utf8.decode(res.bodyBytes);
        final data = jsonDecode(decoded);

        if (mounted) {
          setState(() {
            _allNewsList = _parseNewsList(data);
            _isLoadingNews = false;
          });
        }

        await prefs.setString(cacheNewsData, decoded);
        await prefs.setString(cacheDate, todayStr);
      } else {
        if (mounted) setState(() => _isLoadingNews = false);
      }
    } catch (e) {
      debugPrint("Error fetching Bulletins: $e");
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }

  List<dynamic> _parseNewsList(dynamic data) {
    if (data is List) {
      return data;
    } else if (data is Map) {
      if (data.containsKey('bihar_news') || data.containsKey('national_news')) {
        List combined = [];
        if (data['bihar_news'] is List) combined.addAll(data['bihar_news']);
        if (data['national_news'] is List) combined.addAll(data['national_news']);
        return combined;
      } else if (data.containsKey('news')) {
        return data['news'] as List;
      }
    }
    return [];
  }

  // 🔍 AUTO FILTER BIHAR VS NATIONAL
  List<dynamic> get _biharNewsList {
    return _allNewsList.where((news) {
      if (news is! Map) return false;
      final id = (news['id'] ?? '').toString().toLowerCase();
      final tag = (news['exam_tag'] ?? '').toString().toLowerCase();
      final title = (news['title'] ?? '').toString().toLowerCase();
      final cat = (news['category'] ?? '').toString().toLowerCase();

      return id.startsWith('bih') ||
          tag.contains('bpsc') ||
          tag.contains('bssc') ||
          tag.contains('bihar') ||
          title.contains('bihar') ||
          cat.contains('bihar');
    }).toList();
  }

  List<dynamic> get _nationalNewsList {
    final biharSet = _biharNewsList.toSet();
    return _allNewsList.where((news) => !biharSet.contains(news)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingNews) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2.5),
              ),
              SizedBox(height: 8),
              Text(
                "Loading Live Bulletin...",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    final biharList = _biharNewsList;
    final nationalList = _nationalNewsList;
    final activeList = _selectedNewsTab == 0 ? biharList : nationalList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.newspaper_rounded, size: 20, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Bulletin',
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
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  _buildNewsToggleChip('📍 Bihar (${biharList.length})', 0),
                  _buildNewsToggleChip('🇮🇳 National (${nationalList.length})', 1),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (activeList.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text("No High-Yield Updates Today", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          )
        else ...[
          SizedBox(
            height: 210,
            child: PageView.builder(
              controller: _newsPageController,
              itemCount: activeList.length,
              onPageChanged: (index) {
                setState(() => _activeNewsIndex = index);
              },
              itemBuilder: (context, index) {
                return _buildUltraPremiumNewsCard(activeList[index]);
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(activeList.length, (index) {
              bool isActive = _activeNewsIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                width: isActive ? 22 : 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF4F46E5)
                      : (widget.isDarkMode ? Colors.white24 : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildNewsToggleChip(String label, int index) {
    bool isSelected = _selectedNewsTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedNewsTab != index) {
          setState(() {
            _selectedNewsTab = index;
            _activeNewsIndex = 0;
          });
          if (_newsPageController.hasClients) {
            _newsPageController.jumpToPage(0);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B)),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildUltraPremiumNewsCard(Map<String, dynamic> news) {
    final List bullets = (news['bullets'] as List?) ?? [];
    bool isSaved = _savedNewsList.any((item) => item['title'] == news['title']);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.isDarkMode ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  news['exam_tag'] ?? '🎯 Exam Special',
                  style: TextStyle(
                    color: widget.isDarkMode ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    news['date'] ?? '',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _toggleSaveNews(news),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 20,
                        color: isSaved
                            ? const Color(0xFFF59E0B)
                            : (widget.isDarkMode ? Colors.white60 : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            news['title'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: widget.isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              letterSpacing: -0.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Column(
            children: bullets.take(3).map((bullet) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.arrow_right_rounded,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        bullet.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: widget.isDarkMode ? Colors.white70 : const Color(0xFF334155),
                          height: 1.25,
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
}
