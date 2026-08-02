import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  bool _isLoadingNews = true;

  @override
  void initState() {
    super.initState();
    _fetchBiharNews();
  }

  // 📰 FETCH LIVE BIHAR NEWS FROM JSDELIVR CDN
  Future<void> _fetchBiharNews() async {
    const String newsUrl = "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/bihar_news.json";
    try {
      final res = await http.get(Uri.parse(newsUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (mounted) {
          setState(() {
            _biharNewsList = data is List ? data : [data];
            _isLoadingNews = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingNews = false);
      }
    } catch (e) {
      debugPrint("Error fetching Bihar News via CDN: $e");
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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

          // 2. TRUST HERO BANNER
          _buildTrustHeroBanner(),
          const SizedBox(height: 16),

          // 📰 3. DAILY BIHAR SPECIAL BULLETIN (LIVE VIA CDN)
          _buildBiharNewsSection(),
          const SizedBox(height: 16),

          // 4. LEARN PREVIEW CARD
          _buildLearnPreviewCard(context),
          const SizedBox(height: 16),

          // ⚡ 5. SPEED RUN DUEL CARD
          _buildSpeedRunChallengeCard(context),
          const SizedBox(height: 16),

          // 6. DYNAMIC WEB HUB
          _buildDynamicWebHubSection(context),
          const SizedBox(height: 16),

          // 7. ELIGIBILITY CHECKER
          EligibilityCheckerWidget(isDarkMode: widget.isDarkMode, onTapUrl: widget.onTapUrl),
          const SizedBox(height: 16),

          // 8. LAUNCH ROADMAP
          _buildLaunchRoadmapCard(),
          const SizedBox(height: 16),

          // 9. TELEGRAM COMMUNITY
          const TelegramCreatorWidget(),
        ],
      ),
    );
  }

  // 📰 BIHAR NEWS WIDGET SECTION
  Widget _buildBiharNewsSection() {
    if (_isLoadingNews) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
      );
    }

    if (_biharNewsList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📰 Daily Bihar Special Bulletin',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'LIVE UPDATE',
                style: TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._biharNewsList.map((news) => _buildNewsCard(news)),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> news) {
    final List bullets = (news['bullets'] as List?) ?? [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  news['exam_tag'] ?? '🎯 BPSC Special',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.amberAccent),
                  const SizedBox(width: 4),
                  Text(
                    news['date'] ?? '',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            news['title'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.35),
          ),
          const SizedBox(height: 10),
          ...bullets.map((bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔹 ', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                    Expanded(
                      child: Text(
                        bullet.toString(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTrustHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF111827) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Text('🛡️ ', style: TextStyle(fontSize: 11)),
                    Text(
                      'STUDENT-FIRST INITIATIVE',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BPSC • BSSC • SSC',
                style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
              )
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Mehnga Subscription Kyun?\nPadhai Pe Sabka Haq Hai!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paid Apps Repeat Old Questions. MockTester Tests What Came Yesterday.\n100% Free & Latest CBT Pattern Mocks.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnPreviewCard(BuildContext context) {
    int percentDisplay = (widget.lastLearnProgress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? [const Color(0xFF0F766E), const Color(0xFF115E59)]
              : [const Color(0xFF0F766E), const Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text('🧬 ', style: TextStyle(fontSize: 12)),
                    Text(
                      widget.hasLearningHistory ? 'CONTINUE LEARNING' : 'INTERACTIVE LEARNING (NEW)',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '👨‍🏫 Aman Sir + 👦 Raju',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.lastLearnTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.lastNextTopic,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chapter Progress',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$percentDisplay% Completed',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: widget.lastLearnProgress,
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onNavigateToLearn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F766E),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    widget.hasLearningHistory ? 'Resume Learning →' : 'Start Learning →',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedRunChallengeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Text('⚔️ ', style: TextStyle(fontSize: 12)),
                    Text(
                      'LIVE DUEL SPRINT',
                      style: TextStyle(
                        color: Color(0xFFEA580C),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '⏱️ 5 Mins • 10 Levels',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              )
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Challenge Your Friend 🎯',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '10 High-yield concepts solve karo, result dost ko WhatsApp/Telegram par bhejo aur dekho kon jeet-ta hai!',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 14),
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
                foregroundColor: const Color(0xFFEA580C),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Start Challenge Sprint 🚀',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
            color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDarkMode ? Colors.blueGrey.shade700 : cardThemeColor.withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: cardThemeColor.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
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
                      color: cardThemeColor.withOpacity(0.1),
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

  Widget _buildLaunchRoadmapCard() {
    final List roadmapList = widget.appConfig['launch_roadmap'] ?? [
      {"text": "🔥 Coming Tomorrow: BSSC Inter Level Top 100 Qs", "color": "0xFFFF4757"},
      {"text": "✅ Just Added: Current Affairs Bulletin 2026", "color": "0xFF059669"},
      {"text": "📌 Next Week: BPSC Mains Answer Writing Practice", "color": "0xFF2563EB"}
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📅 Launch Roadmap & Live Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...roadmapList.map((item) {
              final String text = item['text'] ?? '';
              Color textColor = const Color(0xFF2563EB);
              try {
                if (item['color'] != null) textColor = Color(int.parse(item['color']));
              } catch (_) {}

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(text, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
              );
            }),
          ],
        ),
      ),
    );
  }
}
