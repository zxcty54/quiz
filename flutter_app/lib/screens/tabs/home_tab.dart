import 'package:flutter/material.dart';
import '../../widgets/home_widgets.dart';
import '../sprint_challenge_screen.dart';

class HomeTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (appConfig['today_update']?['show'] == true) ...[
            TodayUpdateTickerWidget(updateData: appConfig['today_update'], onTapUrl: onTapUrl),
            const SizedBox(height: 16),
          ],
          _buildTrustHeroBanner(),
          const SizedBox(height: 16),
          _buildLearnPreviewCard(context),
          const SizedBox(height: 16),
          _buildSpeedRunChallengeCard(context),
          const SizedBox(height: 16),
          _buildDynamicWebHubSection(context),
          const SizedBox(height: 16),
          EligibilityCheckerWidget(isDarkMode: isDarkMode, onTapUrl: onTapUrl),
          const SizedBox(height: 16),
          _buildLaunchRoadmapCard(),
          const SizedBox(height: 16),
          const TelegramCreatorWidget(),
        ],
      ),
    );
  }

  Widget _buildTrustHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111827) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.shade400, borderRadius: BorderRadius.circular(20)),
                child: const Text('🛡️ STUDENT-FIRST INITIATIVE', style: TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              const Text('BPSC • BSSC • SSC', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Mehnga Subscription Kyun?\nPadhai Pe Sabka Haq Hai!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.35)),
          const SizedBox(height: 8),
          const Text('Paid Apps Repeat Old Questions. MockTester Tests What Came Yesterday.\n100% Free & Latest CBT Pattern Mocks.', style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildLearnPreviewCard(BuildContext context) {
    int percentDisplay = (lastLearnProgress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode ? [const Color(0xFF0F766E), const Color(0xFF115E59)] : [const Color(0xFF0F766E), const Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.shade400, borderRadius: BorderRadius.circular(20)),
                child: Text(hasLearningHistory ? 'CONTINUE LEARNING' : 'INTERACTIVE LEARNING (NEW)', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Text('👨‍🏫 Aman Sir + 👦 Raju', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(lastLearnTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(lastNextTopic, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chapter Progress', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text('$percentDisplay% Completed', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: lastLearnProgress, minHeight: 6, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNavigateToLearn,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F766E)),
              child: Text(hasLearningHistory ? 'Resume Learning →' : 'Start Learning →', style: const TextStyle(fontWeight: FontWeight.bold)),
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
        gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFC2410C)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Text('⚔️ LIVE DUEL SPRINT', style: TextStyle(color: Color(0xFFEA580C), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Text('⏱️ 5 Mins • 10 Levels', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Challenge Your Friend 🎯', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('10 High-yield concepts solve karo aur dost ko WhatsApp/Telegram par challenge karo!', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SprintChallengeScreen(subjectMapping: subjectMapping)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFEA580C)),
              child: const Text('Start Challenge Sprint 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicWebHubSection(BuildContext context) {
    final List webHubList = (homeData['web_hub'] as List?) ?? [];
    if (webHubList.isEmpty) return const SizedBox.shrink();

    return Column(
      children: webHubList.map<Widget>((hubItem) {
        final String title = hubItem['title'] ?? 'Section';
        final String buttonText = hubItem['button_text'] ?? 'Explore →';
        final String buttonUrl = hubItem['button_url'] ?? 'https://www.mocktester.online';
        final List items = (hubItem['items'] as List?) ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...items.map((itemText) => InkWell(
                    onTap: () => onTapUrl(itemText.toString(), buttonUrl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(children: [const Icon(Icons.arrow_right_rounded, size: 20), Expanded(child: Text(itemText.toString(), style: const TextStyle(fontSize: 13)))]),
                    ),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => onTapUrl(title, buttonUrl), child: Text(buttonText)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLaunchRoadmapCard() {
    final List roadmapList = appConfig['launch_roadmap'] ?? [
      {"text": "🔥 Coming Tomorrow: BSSC Inter Level Top 100 Qs", "color": "0xFFFF4757"},
      {"text": "✅ Just Added: Current Affairs Bulletin 2026", "color": "0xFF059669"}
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📅 Launch Roadmap & Live Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...roadmapList.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Text(item['text'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                )),
          ],
        ),
      ),
    );
  }
}
