import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/widgets/app_global_feedback_dialog.dart';
import 'package:mocktester_v2/core/widgets/latex_text.dart';
import 'package:mocktester_v2/core/widgets/math_text.dart';
import 'package:mocktester_v2/core/widgets/report_error_dialog.dart';
import 'package:mocktester_v2/features/bihar_events/presentation/bihar_events_carousel_widget.dart';
import 'package:mocktester_v2/features/bihar_gk/presentation/know_your_bihar_widget.dart';
import 'package:mocktester_v2/features/bulletin/presentation/daily_bulletin_widget.dart';
import 'package:mocktester_v2/features/challenge/presentation/widgets/challenge_card_widget.dart';
import 'package:mocktester_v2/features/coaching/presentation/widgets/coaching_hub_card.dart';
import 'package:mocktester_v2/features/coaching/presentation/widgets/coaching_onboarding_cta_widget.dart';
import 'package:mocktester_v2/features/community/presentation/widgets/community_comments_sheet.dart';
import 'package:mocktester_v2/features/community/presentation/widgets/community_post_card.dart';
import 'package:mocktester_v2/features/creator/presentation/analytics/student_intelligence_sheet.dart';
import 'package:mocktester_v2/features/creator/presentation/widgets/batch_manager_modal.dart';
import 'package:mocktester_v2/features/first_in_india/presentation/first_in_india_widget.dart';
import 'package:mocktester_v2/features/hall_of_fame/presentation/hall_of_fame_carousel_widget.dart';
import 'package:mocktester_v2/features/home/presentation/widgets/home_widgets.dart';
import 'package:mocktester_v2/features/home/presentation/widgets/launch_roadmap_card.dart';
import 'package:mocktester_v2/features/home/presentation/widgets/trust_hero_banner.dart';
import 'package:mocktester_v2/features/jobs/presentation/latest_jobs_widget.dart';
import 'package:mocktester_v2/features/learn/presentation/widgets/duolingo_card.dart';
import 'package:mocktester_v2/features/learn/presentation/widgets/learn_chat_widgets.dart';
import 'package:mocktester_v2/features/pdf_vault/presentation/pro_pdf_vault_card.dart';
import 'package:mocktester_v2/features/profile/presentation/leaderboard/widgets/district_top_leaderboard_widget.dart';
import 'package:mocktester_v2/features/profile/presentation/widgets/donation_widget.dart';
import 'package:mocktester_v2/features/profile/presentation/widgets/mastery_evolution_card.dart';
import 'package:mocktester_v2/features/profile/presentation/widgets/selection_proof_system.dart';
import 'package:mocktester_v2/features/revision/presentation/widgets/revision_category_cards.dart';
import 'package:mocktester_v2/features/revision/presentation/widgets/revision_current_affairs.dart';
import 'package:mocktester_v2/features/revision/presentation/widgets/revision_hero_banner.dart';
import 'package:mocktester_v2/features/revision/presentation/widgets/revision_trick_box.dart';
import 'package:mocktester_v2/features/sectional/presentation/widgets/cbt_widgets.dart';

import 'package:mocktester_v2/tools/demo/demo_fixtures.dart';

/// Renders (almost) every reusable widget of the app with fixture data so the
/// tester can eyeball the whole UI without a working backend.
class DemoWidgetGalleryScreen extends StatefulWidget {
  const DemoWidgetGalleryScreen({super.key});

  @override
  State<DemoWidgetGalleryScreen> createState() =>
      _DemoWidgetGalleryScreenState();
}

class _DemoWidgetGalleryScreenState extends State<DemoWidgetGalleryScreen> {
  bool _dark = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<_GalleryEntry> entries = _entries(_dark)
        .where((_GalleryEntry e) =>
            _query.isEmpty ||
            e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Gallery'),
        actions: <Widget>[
          IconButton(
            tooltip: _dark ? 'Light preview' : 'Dark preview',
            icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _dark = !_dark),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (String value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Filter widgets…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        itemBuilder: (BuildContext context, int index) {
          final _GalleryEntry entry = entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.widgets_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${entries.length - index} left',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                entry.builder(context),
                const Divider(height: 26),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_GalleryEntry> _entries(bool dark) => <_GalleryEntry>[
        _GalleryEntry(
          'TodayUpdateTickerWidget',
          (_) => TodayUpdateTickerWidget(
            updateData: DemoFixtures.appConfig['today_update']
                as Map<String, dynamic>,
            onTapUrl: (String a, String b) {},
          ),
        ),
        _GalleryEntry(
          'TrustHeroBannerWidget',
          (_) => TrustHeroBannerWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'LaunchRoadmapCardWidget',
          (_) => LaunchRoadmapCardWidget(
            appConfig: DemoFixtures.appConfig,
            isDarkMode: dark,
          ),
        ),
        _GalleryEntry(
          'EligibilityCheckerWidget',
          (_) => EligibilityCheckerWidget(
            isDarkMode: dark,
            onTapUrl: (String a, String b) {},
          ),
        ),
        _GalleryEntry(
          'TelegramCreatorWidget',
          (_) => const TelegramCreatorWidget(),
        ),
        _GalleryEntry(
          'CoachingHubCard',
          (_) => CoachingHubCard(isDarkMode: dark),
        ),
        _GalleryEntry(
          'CoachingOnboardingCtaWidget',
          (_) => CoachingOnboardingCtaWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'DistrictTopLeaderboardWidget',
          (_) => DistrictTopLeaderboardWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'ProPdfVaultCard',
          (_) => ProPdfVaultCard(isDarkMode: dark),
        ),
        _GalleryEntry(
          'HallOfFameCarouselWidget',
          (_) => HallOfFameCarouselWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'FirstInIndiaWidget',
          (_) => FirstInIndiaWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'DailyBulletinWidget',
          (_) => DailyBulletinWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'LatestJobsWidget',
          (_) => LatestJobsWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'KnowYourBiharWidget',
          (_) => KnowYourBiharWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'BiharEventsCarouselWidget',
          (_) => BiharEventsCarouselWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'ChallengeCardWidget',
          (_) => ChallengeCardWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'MasteryEvolutionCard',
          (_) => MasteryEvolutionCard(isDarkMode: dark),
        ),
        _GalleryEntry(
          'DonationWidget',
          (_) => DonationWidget(isDarkMode: dark),
        ),
        _GalleryEntry(
          'RevisionHeroBanner',
          (_) => RevisionHeroBanner(isDark: dark, isLoading: false),
        ),
        _GalleryEntry(
          'RevisionSegmentedCard',
          (_) => RevisionSegmentedCard(
            title: 'General Science',
            badgeText: '🔥 Demo badge',
            icon: '🔬',
            color: const Color(0xFF2563EB),
            isDark: dark,
            isLoading: false,
            selectedIndex: 0,
            onPillSelected: (int i) {},
            subjects: const <Map<String, String>>[
              <String, String>{'title': '⚡ Physics', 'key': 'phy_mapping'},
              <String, String>{'title': '🧬 Biology', 'key': 'bio_mapping'},
            ],
            liveMapping: DemoFixtures.subjectMapping,
            onLaunchPractice: (BuildContext c, String t, String p) {},
          ),
        ),
        _GalleryEntry(
          'RevisionDirectCard',
          (_) => RevisionDirectCard(
            title: 'Quantitative Aptitude',
            badgeText: '🎯 Demo badge',
            headerLabel: 'Chapters',
            icon: '📐',
            mappingKey: 'aptitude_mapping',
            fallbackKey: 'aptitude_mapping',
            brandColor: const Color(0xFF6366F1),
            isDark: dark,
            isLoading: false,
            liveMapping: DemoFixtures.subjectMapping,
            onLaunchPractice: (BuildContext c, String t, String p) {},
          ),
        ),
        _GalleryEntry(
          'RevisionCurrentAffairsCard',
          (_) => RevisionCurrentAffairsCard(isDark: dark),
        ),
        _GalleryEntry(
          'RevisionTrickSubmitBox',
          (_) => const RevisionTrickSubmitBox(
            testTitle: 'Demo Test',
            qIndex: 0,
            questionSnippet: 'Demo question snippet',
          ),
        ),
        _GalleryEntry(
          'DuolingoCard',
          (_) => DuolingoCard(
            payload: DemoFixtures.duolingoPayload,
            isDarkMode: dark,
          ),
        ),
        _GalleryEntry(
          'IntroCardWidget',
          (_) => IntroCardWidget(card: DemoFixtures.introCard),
        ),
        _GalleryEntry(
          'QuizCard',
          (_) => QuizCard(card: DemoFixtures.quizCard),
        ),
        _GalleryEntry(
          'ModernChatCard',
          (_) => ModernChatCard(
            card: DemoFixtures.chatCard,
            characters: DemoFixtures.characters,
            visibleCount: 5,
            isTyping: false,
            scrollController: ScrollController(),
          ),
        ),
        _GalleryEntry(
          'LearnCardRenderer',
          (_) => LearnCardRenderer(
            card: DemoFixtures.chatCard,
            characters: DemoFixtures.characters,
            visibleCount: 5,
            isTyping: false,
            scrollController: ScrollController(),
          ),
        ),
        _GalleryEntry(
          'InteractiveWordText',
          (_) => InteractiveWordText(
            rawText: 'Tap any difficult word — it explains itself. '
                'Photosynthesis is a great example.',
            baseStyle: const TextStyle(fontSize: 15),
          ),
        ),
        _GalleryEntry('BouncingTypingDots', (_) => const BouncingTypingDots()),
        _GalleryEntry(
          'CbtPieChartCard',
          (_) => const CbtPieChartCard(correct: 12, wrong: 4, skipped: 2),
        ),
        _GalleryEntry(
          'AiExplanationButton',
          (_) => const AiExplanationButton(
            question: 'Which Article gives the Right to Constitutional Remedies?',
            options: <String>['Article 19', 'Article 21', 'Article 32'],
            correctAnswer: 'Article 32',
          ),
        ),
        _GalleryEntry(
          'WikiContributionBox',
          (_) => const WikiContributionBox(
            subFolder: 'demo/set1.json',
            qIndex: 0,
            questionSnippet: 'Demo snippet for wiki contribution',
          ),
        ),
        _GalleryEntry(
          'CommunityPostCard',
          (_) => CommunityPostCard(
            post: DemoFixtures.communityPost,
            currentLoggedInHandle: 'demo',
            isLiked: false,
            isSaved: false,
            selectedPollIndex: null,
            isDarkMode: dark,
            onOpenComments: () {},
            onLikeToggle: (bool v) {},
            onBookmarkToggle: (bool v) {},
            onPollVote: (int i) {},
          ),
        ),
        _GalleryEntry(
          'StarSelectionCard',
          (_) => StarSelectionCard(
            data: const <String, dynamic>{
              'student_name': 'Demo Topper',
              'post_cleared': 'BPSC 69th — SDM',
              'target_exam': 'BPSC CCE',
              'testimonial_text':
                  'Demo testimonial rendered by StarSelectionCard.',
              'is_verified': true,
            },
            isDarkMode: dark,
          ),
        ),
        _GalleryEntry(
          'AppGlobalFeedbackCard',
          (_) => AppGlobalFeedbackCard(isDarkMode: dark),
        ),
        _GalleryEntry(
          'LatexText',
          (_) => const LatexText(r'The area of a circle is $A = \pi r^2$.'),
        ),
        _GalleryEntry(
          'MathFormattedText',
          (_) => const MathFormattedText(
            text: r'$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$',
          ),
        ),
        _GalleryEntry(
          'EventGoingButton',
          (_) => const EventGoingButton(
            eventId: 'demo-event-1',
            eventEndDate: '2026-12-31',
            isDark: false,
          ),
        ),
        _GalleryEntry(
          'EventCommunityUpdatesWidget',
          (_) => const EventCommunityUpdatesWidget(
            eventId: 'demo-event-1',
            eventEndDate: '2026-12-31',
            isDark: false,
          ),
        ),
        _GalleryEntry(
          'Buttons: dialogs & sheets',
          (BuildContext context) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ReportErrorDialog(
                    fileName: 'demo/set1.json',
                    questionIndex: 0,
                    questionSnippet: 'Demo question snippet for the report flow',
                  ),
                ),
                child: const Text('ReportErrorDialog'),
              ),
              FilledButton.tonal(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AppGlobalFeedbackDialog(isDarkMode: dark),
                ),
                child: const Text('AppGlobalFeedbackDialog'),
              ),
              FilledButton.tonal(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CommunityCommentsSheet(
                    postId: 1,
                    post: DemoFixtures.communityPost,
                    currentLoggedInHandle: 'demo',
                    customUserName: 'Demo Aspirant',
                    isDarkMode: dark,
                    buildRichTextContent: (String text,
                            {double fontSize = 14}) =>
                        Text(text, style: TextStyle(fontSize: fontSize)),
                    onCommentAdded: () {},
                  ),
                ),
                child: const Text('CommunityCommentsSheet'),
              ),
              FilledButton.tonal(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => StudentIntelligenceSheet(
                    batches: const <dynamic>[],
                    rawSubmissions: const <dynamic>[],
                    batchTests: const <dynamic>[],
                    isDarkMode: dark,
                  ),
                ),
                child: const Text('StudentIntelligenceSheet'),
              ),
              FilledButton.tonal(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BatchManagerModal(
                    batches: const <dynamic>[],
                    coachingId: 'demo-coaching',
                    isDarkMode: dark,
                    onRefresh: () {},
                  ),
                ),
                child: const Text('BatchManagerModal'),
              ),
            ],
          ),
        ),
      ];
}

class _GalleryEntry {
  const _GalleryEntry(this.name, this.builder);

  final String name;
  final Widget Function(BuildContext context) builder;
}
