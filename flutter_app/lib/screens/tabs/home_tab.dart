import 'package:flutter/material.dart';
import '../../widgets/home_widgets.dart';
import '../../widgets/latest_jobs_widget.dart';
import '../../widgets/daily_bulletin_widget.dart';
import '../../widgets/first_in_india_widget.dart';
import '../../widgets/trust_hero_banner.dart';
import '../../widgets/launch_roadmap_card.dart';
import '../../widgets/pro_pdf_vault_card.dart'; // 👈 Pro PDF Vault Card Import
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
  // GlobalKeys for Pull-To-Refresh Trigger
  final GlobalKey<LatestJobsWidgetState> _jobsWidgetKey = GlobalKey<LatestJobsWidgetState>();
  final GlobalKey<DailyBulletinWidgetState> _bulletinWidgetKey = GlobalKey<DailyBulletinWidgetState>();
  final GlobalKey<FirstInIndiaWidgetState> _firstInIndiaWidgetKey = GlobalKey<FirstInIndiaWidgetState>();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      onRefresh: () async {
        // 🔄 REFRESH ALL THREE LIVE WIDGETS ON PULL
        await Future.wait<dynamic>([
          _bulletinWidgetKey.currentState?.fetchDailyBulletins(forceRefresh: true) ?? Future.value(),
          _jobsWidgetKey.currentState?.fetchLatestJobs() ?? Future.value(),
          _firstInIndiaWidgetKey.currentState?.fetchFirstInIndia(forceRefresh: true) ?? Future.value(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TODAY TICKER (Short Version)
            if (widget.appConfig['today_update']?['show'] == true) ...[
              TodayUpdateTickerWidget(
                updateData: widget.appConfig['today_update'],
                onTapUrl: widget.onTapUrl,
              ),
              const SizedBox(height: 16),
            ],

            // 🛡️ 2. HERO TRUST BANNER WIDGET
            TrustHeroBannerWidget(isDarkMode: widget.isDarkMode),
            const SizedBox(height: 18),
            
            // 👨‍🏫 3. LEARN PREVIEW CARD
            _buildLearnPreviewCard(context),
            const SizedBox(height: 18),

            // 📰 4. DAILY BULLETIN WIDGET
            DailyBulletinWidget(
              key: _bulletinWidgetKey,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            // 📢 5. LATEST JOBS WIDGET
            LatestJobsWidget(
              key: _jobsWidgetKey,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            // 🏆 6. FIRST IN INDIA EXPRESS WIDGET
            FirstInIndiaWidget(
              key: _firstInIndiaWidgetKey,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            // 📑 7. PRO STUDY MATERIAL & PDF VAULT CARD (Auto-rolling with live JSON push)
            ProPdfVaultCard(
              isDarkMode: widget.isDarkMode,
              customWebsiteUrl: "https://www.mocktester.online/p/free-pdf.html",
              dynamicPdfItems: widget.appConfig['pdf_vault_items'], // 👈 Connected with app_config.json
            ),
            const SizedBox(height: 18),

            // ⚔️ 8. SPEED RUN DUEL CARD
            _buildSpeedRunChallengeCard(context),
            const SizedBox(height: 18),

            // 🌐 9. DYNAMIC WEB HUB
            _buildDynamicWebHubSection(context),
            const SizedBox(height: 18),

            // 10. ELIGIBILITY CHECKER
            EligibilityCheckerWidget(isDarkMode: widget.isDarkMode, onTapUrl: widget.onTapUrl),
            const SizedBox(height: 18),

            // 📅 11. LAUNCH ROADMAP WIDGET
            LaunchRoadmapCardWidget(
              appConfig: widget.appConfig,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            // 12. TELEGRAM COMMUNITY
            const TelegramCreatorWidget(),
          ],
        ),
      ),
    );
  }

  // 👨‍🏫 LEARN PREVIEW CARD
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

  // ⚔️ LIVE DUEL SPRINT CARD
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
}
