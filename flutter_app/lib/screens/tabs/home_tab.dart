import 'package:flutter/material.dart';
import '../../widgets/home_widgets.dart';
import '../../widgets/latest_jobs_widget.dart';
import '../../widgets/daily_bulletin_widget.dart';
import '../../widgets/first_in_india_widget.dart';
import '../../widgets/coaching_hub_card.dart';
import '../../widgets/hall_of_fame_carousel_widget.dart';
import '../../widgets/bihar_events_carousel_widget.dart'; 
import '../../widgets/know_your_bihar_widget.dart';
import '../../widgets/district_top_leaderboard_widget.dart';
import '../../widgets/challenge_card_widget.dart';
import '../../widgets/home_greeting_header.dart';
import '../../widgets/promo_banner_carousel.dart';

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
  final GlobalKey<LatestJobsWidgetState> _jobsWidgetKey = GlobalKey<LatestJobsWidgetState>();
  final GlobalKey<DailyBulletinWidgetState> _bulletinWidgetKey = GlobalKey<DailyBulletinWidgetState>();
  final GlobalKey<FirstInIndiaWidgetState> _firstInIndiaWidgetKey = GlobalKey<FirstInIndiaWidgetState>();
  final GlobalKey<CoachingHubCardState> _coachingHubKey = GlobalKey<CoachingHubCardState>();
  final GlobalKey<HallOfFameCarouselWidgetState> _hallOfFameKey = GlobalKey<HallOfFameCarouselWidgetState>();

  int _greetingReloadToken = 0;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      onRefresh: () async {
        setState(() => _greetingReloadToken++);
        await Future.wait<dynamic>([
          _bulletinWidgetKey.currentState?.fetchDailyBulletins(forceRefresh: true) ?? Future.value(),
          _jobsWidgetKey.currentState?.fetchLatestJobs(refresh: true) ?? Future.value(),
          _firstInIndiaWidgetKey.currentState?.fetchFirstInIndia(forceRefresh: true) ?? Future.value(),
          _coachingHubKey.currentState?.loadEnrolledBatchData() ?? Future.value(),
          _hallOfFameKey.currentState?.fetchHallOfFame() ?? Future.value(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. PERSONAL HEADER (naam, aaj ka goal, streak, kamzor topic)
            HomeGreetingHeader(isDarkMode: widget.isDarkMode, reloadToken: _greetingReloadToken),
            const SizedBox(height: 16),

            // 0.5 LIVE PROMO BANNERS (naya exam / naya mock) —
            // ye live app_config.json ke promo_banners se bante hain.
            // Naya banner = wahan entry jodo, app rebuild nahi hoga.
            PromoBannerCarousel(
              banners: (widget.appConfig['promo_banners'] as List?) ?? const [],
              isDarkMode: widget.isDarkMode,
              onTapUrl: widget.onTapUrl,
            ),

            // 1. TODAY TICKER
            if (widget.appConfig['today_update']?['show'] == true) ...[
              TodayUpdateTickerWidget(
                updateData: widget.appConfig['today_update'],
                onTapUrl: widget.onTapUrl,
              ),
              const SizedBox(height: 16),
            ],

            // 2. CONTINUE LEARNING
            _buildLearnPreviewCard(context),
            const SizedBox(height: 18),

            // 3. MY COACHING / DISCOVER COACHING
            // (code dalne par widget apne aap joined coaching ka card ban jata hai)
            CoachingHubCard(
              key: _coachingHubKey,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            // 4. DAILY CHALLENGE
            ChallengeCardWidget(isDarkMode: widget.isDarkMode),
            const SizedBox(height: 18),

            // 5. DISTRICT LEADERBOARD
            DistrictTopLeaderboardWidget(isDarkMode: widget.isDarkMode),
            const SizedBox(height: 18),

            // 6. AAJ KI PADHAI
            DailyBulletinWidget(
              key: _bulletinWidgetKey,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            FirstInIndiaWidget(
              key: _firstInIndiaWidgetKey,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            KnowYourBiharWidget(
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            // 7. LATEST JOBS
            LatestJobsWidget(
              key: _jobsWidgetKey,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            // 8. EVENTS
            BiharEventsCarouselWidget(
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 18),

            // 9. UTILITIES
            EligibilityCheckerWidget(
              isDarkMode: widget.isDarkMode,
              onTapUrl: widget.onTapUrl,
            ),
            const SizedBox(height: 18),

            _buildDynamicWebHubSection(context),
            const SizedBox(height: 18),

            // 10. SOCIAL PROOF
            HallOfFameCarouselWidget(
              key: _hallOfFameKey,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnPreviewCard(BuildContext context) {
    final percentDisplay = (widget.lastLearnProgress * 100).toInt();
    final isDark = widget.isDarkMode;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const royal = Color(0xFF1E40AF);
    final goalProgress = widget.lastLearnProgress.clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.055),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upar wali royal-blue patti — course header jaisi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF172554), Color(0xFF1E40AF), Color(0xFF2563EB)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book_rounded, size: 20, color: royal),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.hasLearningHistory ? 'CONTINUE LEARNING' : 'INTERACTIVE LEARNING',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Do chhote avatar ghare — dono ki pehchan
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 19,
                                  height: 19,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.3),
                                  ),
                                  child: const Text('A', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                ),
                                Positioned(
                                  left: 13,
                                  child: Container(
                                    width: 19,
                                    height: 19,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF38BDF8),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.3),
                                    ),
                                    child: const Text('R', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 21),
                            const Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Aman Sir',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                    TextSpan(
                                      text: ' + ',
                                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: 'Raju Sir',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                    TextSpan(
                                      text: ' ke saath',
                                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            value: goalProgress,
                            strokeWidth: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                          ),
                        ),
                        Text(
                          '$percentDisplay%',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Neeche ka hissa — chapter, next topic, progress, button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lastLearnTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.25,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(color: royal, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NEXT TOPIC',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.lastNextTopic,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.playlist_play_rounded, size: 19, color: muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chapter Progress',
                        style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$percentDisplay% Completed',
                        style: const TextStyle(color: royal, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: goalProgress,
                      minHeight: 8,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 47,
                          child: ElevatedButton(
                            onPressed: widget.onNavigateToLearn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: royal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle_fill_rounded, size: 19, color: Colors.white),
                                const SizedBox(width: 7),
                                Text(
                                  widget.hasLearningHistory ? 'Resume Learning' : 'Start Learning',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                        height: 47,
                        child: OutlinedButton(
                          onPressed: widget.onNavigateToLearn,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: royal,
                            side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFBFDBFE), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.library_books_rounded, size: 17),
                              SizedBox(width: 6),
                              Text('Chapters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                            ],
                          ),
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
