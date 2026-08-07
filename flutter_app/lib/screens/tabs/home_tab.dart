import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/home_widgets.dart';
import '../sprint_challenge_screen.dart';

class HomeTab extends StatefulWidget {
  final Map<String, dynamic> appConfig;
  final Map<String, dynamic> homeData;
  final Map<String, dynamic> subjectMapping;
  final bool isDarkMode;
  final String lastLearnTitle;
  final double lastLearnProgress;
  final String lastNextTopic;
  final bool hasLearningHistory;
  final Function(String, String) onTapUrl;
  final VoidCallback onNavigateToLearn;

  const HomeTab({
    super.key,
    required this.appConfig,
    required this.homeData,
    required this.subjectMapping,
    required this.isDarkMode,
    required this.lastLearnTitle,
    required this.lastLearnProgress,
    required this.lastNextTopic,
    required this.hasLearningHistory,
    required this.onTapUrl,
    required this.onNavigateToLearn,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<dynamic> _biharNewsList = [];
  List<dynamic> _nationalNewsList = [];
  bool _isLoadingNews = true;
  
  // TOGGLE STATE: 0 = Bihar, 1 = National
  int _selectedNewsTab = 0; 
  int _activeNewsIndex = 0;
  final PageController _newsPageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchDailyBulletins();
  }

  @override
  void dispose() {
    _newsPageController.dispose();
    super.dispose();
  }

  // 📰 FETCH BIHAR & NATIONAL NEWS WITH INSTANT NETWORK REFRESH
  Future<void> _fetchDailyBulletins({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    // CACHE KEYS
    const String cacheBiharData = 'cached_bihar_news_json';
    const String cacheNationalData = 'cached_national_news_json';
    const String cacheDate = 'cached_bulletin_date';

    final String savedDate = prefs.getString(cacheDate) ?? '';

    // Step 1: Check Local Storage (Skip if user pulled-to-refresh manually)
    if (!forceRefresh && savedDate == todayStr) {
      String? cachedBihar = prefs.getString(cacheBiharData);
      String? cachedNat = prefs.getString(cacheNationalData);

      if (cachedBihar != null && cachedNat != null) {
        try {
          final bData = jsonDecode(cachedBihar);
          final nData = jsonDecode(cachedNat);
          if (mounted) {
            setState(() {
              _biharNewsList = (bData is Map && bData.containsKey('news_cards')) ? bData['news_cards'] : [];
              _nationalNewsList = (nData is Map && nData.containsKey('news_cards')) ? nData['news_cards'] : [];
              _isLoadingNews = false;
            });
          }
          debugPrint("✅ News Loaded instantly from Local Cache!");
          return;
        } catch (_) {}
      }
    }

    // Step 2: Dynamic Network Fetch with Millisecond Timestamp
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String biharUrl = "https://raw.githubusercontent.com/zxcty54/quiz/main/bihar_news.json?t=$timestamp";
    final String nationalUrl = "https://raw.githubusercontent.com/zxcty54/quiz/main/national_news.json?t=$timestamp";

    try {
      final resBihar = await http.get(Uri.parse(biharUrl)).timeout(const Duration(seconds: 4));
      final resNational = await http.get(Uri.parse(nationalUrl)).timeout(const Duration(seconds: 4));

      if (resBihar.statusCode == 200 || resNational.statusCode == 200) {
        String bDecoded = resBihar.statusCode == 200 ? utf8.decode(resBihar.bodyBytes) : "{}";
        String nDecoded = resNational.statusCode == 200 ? utf8.decode(resNational.bodyBytes) : "{}";

        final bData = jsonDecode(bDecoded);
        final nData = jsonDecode(nDecoded);

        if (mounted) {
          setState(() {
            _biharNewsList = (bData is Map && bData.containsKey('news_cards')) ? bData['news_cards'] : [];
            _nationalNewsList = (nData is Map && nData.containsKey('news_cards')) ? nData['news_cards'] : [];
            _isLoadingNews = false;
          });
        }

        await prefs.setString(cacheBiharData, bDecoded);
        await prefs.setString(cacheNationalData, nDecoded);
        await prefs.setString(cacheDate, todayStr);
        debugPrint("✅ Fresh News Refetched and Cached!");
      } else {
        if (mounted) setState(() => _isLoadingNews = false);
      }
    } catch (e) {
      debugPrint("Error fetching Bulletins: $e");
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      onRefresh: () async {
        await _fetchDailyBulletins(forceRefresh: true);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TODAY TICKER
            if (widget.appConfig['today_update']?['show'] == true) ...[
              TodayUpdateTickerWidget(updateData: widget.appConfig['today_update'], onTapUrl: widget.onTapUrl),
              const SizedBox(height: 16),
            ],

            // 🛡️ 2. HERO TRUST BANNER
            _buildTrustHeroBanner(),
            const SizedBox(height: 18),

            // 📰 3. DAILY BULLETIN CAROUSEL WITH TOGGLE SWITCH
            _buildDailyBulletinSection(),
            const SizedBox(height: 18),

            // 👨‍🏫 4. LEARN PREVIEW CARD
            _buildLearnPreviewCard(context),
            const SizedBox(height: 18),

            // ⚔️ 5. SPEED RUN DUEL CARD
            _buildSpeedRunChallengeCard(context),
            const SizedBox(height: 18),

            // 6. DYNAMIC WEB HUB
            _buildDynamicWebHubSection(context),
            const SizedBox(height: 18),

            // 7. ELIGIBILITY CHECKER
            EligibilityCheckerWidget(isDarkMode: widget.isDarkMode, onTapUrl: widget.onTapUrl),
            const SizedBox(height: 18),

            // 📅 8. LAUNCH ROADMAP
            _buildLaunchRoadmapCard(),
            const SizedBox(height: 18),

            // 9. TELEGRAM COMMUNITY
            const TelegramCreatorWidget(),
          ],
        ),
      ),
    );
  }

  // 🛡️ 1. HERO BANNER
  Widget _buildTrustHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFF312E81), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                ),
                child: const Row(
                  children: [
                    Text('🛡️ ', style: TextStyle(fontSize: 10)),
                    Text(
                      'STUDENT-FIRST INITIATIVE',
                      style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'BPSC • BSSC • SSC',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Mehnga Subscription Kyun?\n',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                TextSpan(
                  text: 'Padhai Pe Sabka Haq Hai! 🎓',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% Free & Latest CBT Pattern Exam Mocks',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📰 2. DAILY BULLETIN SECTION WITH DYNAMIC EXPANDABLE HEIGHT
  Widget _buildDailyBulletinSection() {
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

    final activeList = _selectedNewsTab == 0 ? _biharNewsList : _nationalNewsList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // HEADER ROW WITH TOGGLE BUTTON
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

            // TOGGLE SWITCH
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
                  _buildNewsToggleChip('📍 Bihar', 0),
                  _buildNewsToggleChip('🇮🇳 National', 1),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // CAROUSEL VIEW
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
          // DYNAMIC HEIGHT PAGE VIEW (NO EXTRA WHITE SPACE AT BOTTOM)
          ExpandablePageView(
            controller: _newsPageController,
            itemCount: activeList.length,
            onPageChanged: (index) {
              setState(() => _activeNewsIndex = index);
            },
            itemBuilder: (context, index) {
              return _buildUltraPremiumNewsCard(activeList[index]);
            },
          ),
          const SizedBox(height: 8),

          // INDICATOR DOTS
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

  // 🔘 TOGGLE CHIP BUTTON
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

  // 📇 NEWS CARD ITEM (NO BULLET PADDING & ZERO SCROLLING)
  Widget _buildUltraPremiumNewsCard(Map<String, dynamic> news) {
    final List bullets = (news['bullets'] as List?) ?? [];

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
        mainAxisSize: MainAxisSize.min, // 🌟 Container adapts to content size
        children: [
          // 1. TAG & DATE ROW
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
                ],
              )
            ],
          ),

          const SizedBox(height: 8),

          // 2. NEWS TITLE
          Text(
            news['title'] ?? '',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: widget.isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              letterSpacing: -0.2,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 8),

          // 3. BULLETS (ZERO INNER PADDING & NO SCROLL)
          Column(
            children: bullets.map((bullet) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
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
                        style: TextStyle(
                          fontSize: 12,
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

  // 👨‍🏫 3. LEARN PREVIEW CARD
  Widget _buildLearnPreviewCard(BuildContext context) {
    int percentDisplay = (widget.lastLearnProgress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? [const Color(0xFF064E3B), const Color(0xFF022C22)]
              : [const Color(0xFF047857), const Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.hasLearningHistory ? 'CONTINUE LEARNING' : 'INTERACTIVE LEARNING',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '👨‍🏫 Aman Sir + 👦 Raju',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.lastLearnTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.lastNextTopic,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chapter Progress',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$percentDisplay% Completed',
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: widget.lastLearnProgress,
                  minHeight: 7,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onNavigateToLearn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF065F46),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 20, color: Color(0xFF047857)),
                  const SizedBox(width: 8),
                  Text(
                    widget.hasLearningHistory ? 'Resume Learning →' : 'Start Learning →',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ⚔️ 4. LIVE DUEL SPRINT CARD
  Widget _buildSpeedRunChallengeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFF9A3412)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Text('⚔️ ', style: TextStyle(fontSize: 11)),
                    Text(
                      'LIVE DUEL SPRINT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 12, color: Colors.amberAccent),
                    SizedBox(width: 4),
                    Text(
                      '5 Mins • 10 Levels',
                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Challenge Your Friend 🎯',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '10 High-yield concepts solve karo, result dost ko WhatsApp par bhejo aur dekho kon jeet-ta hai!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SprintChallengeScreen(
                      subjectMapping: widget.subjectMapping,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFC2410C),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFEA580C)),
                  SizedBox(width: 6),
                  Text(
                    'Start Challenge Sprint 🚀',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicWebHubSection(BuildContext context) {
    final List webHubList = (widget.homeData['web_hub'] as List?) ?? [];

    if (webHubList.isEmpty) return const SizedBox.shrink();

    return Column(
      children: webHubList.map<Widget>((hubItem) {
        final String title = hubItem['title'] ?? 'Section';
        final String buttonText = hubItem['button_text'] ?? 'Explore →';
        final String buttonUrl = hubItem['button_url'] ?? 'https://www.mocktester.online';
        final List items = (hubItem['items'] as List?) ?? [];

        Color cardThemeColor = const Color(0xFF2563EB);
        try {
          if (hubItem['color'] != null) {
            cardThemeColor = Color(int.parse(hubItem['color']));
          }
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cardThemeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'UPDATED',
                      style: TextStyle(
                        color: cardThemeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...items.map((itemText) {
                return InkWell(
                  onTap: () => widget.onTapUrl(itemText.toString(), buttonUrl),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_right_rounded, color: cardThemeColor, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            itemText.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded, size: 13, color: cardThemeColor.withOpacity(0.6)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => widget.onTapUrl(title, buttonUrl),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cardThemeColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(buttonText, style: TextStyle(color: cardThemeColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 📅 5. LAUNCH ROADMAP CARD
  Widget _buildLaunchRoadmapCard() {
    final List roadmapList = widget.appConfig['launch_roadmap'] ?? [
      {"text": "🔥 Coming Tomorrow: BSSC Inter Level Top 100 Qs", "color": "0xFFFF4757"},
      {"text": "✅ Just Added: Current Affairs Bulletin 2026", "color": "0xFF059669"},
      {"text": "📌 Next Week: BPSC Mains Answer Writing Practice", "color": "0xFF2563EB"}
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.rocket_launch_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              Text(
                'Launch Roadmap & Live Updates',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...roadmapList.map((item) {
            final String text = item['text'] ?? '';
            Color textColor = const Color(0xFF2563EB);
            try {
              if (item['color'] != null) textColor = Color(int.parse(item['color']));
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF0F172A).withOpacity(0.5)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: textColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
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

// 🌟 EXPANDABLE PAGE VIEW HELPER
// Measures and resizes the viewport to match the active page height dynamically
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
      _heights.isEmpty ? 200 : _heights[_currentPage];

  @override
  void initState() {
    super.initState();
    _heights = List.filled(widget.itemCount, 0.0);
    widget.controller.addListener(_updatePage);
  }

  void _updatePage() {
    final newPage = widget.controller.page?.round() ?? 0;
    if (_currentPage != newPage) {
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
    return TweenAnimationBuilder<double>(
      curve: Curves.easeInOutCubic,
      duration: const Duration(milliseconds: 200),
      tween: Tween<double>(begin: _currentHeight, end: _currentHeight),
      builder: (context, height, child) {
        return SizedBox(
          height: height == 0 ? null : height,
          child: child,
        );
      },
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
                if (_heights[index] != size.height) {
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

// 📏 SIZE REPORTING HELPER
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
