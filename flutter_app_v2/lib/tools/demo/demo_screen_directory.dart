import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/theme/theme_controller.dart';
import 'package:mocktester_v2/features/ai/presentation/ai_chat_screen.dart';
import 'package:mocktester_v2/features/ai/presentation/ai_doubt_screen.dart';
import 'package:mocktester_v2/features/challenge/presentation/challenge_quiz_screen.dart';
import 'package:mocktester_v2/features/challenge/presentation/challenge_result_screen.dart';
import 'package:mocktester_v2/features/challenge/presentation/sprint_challenge_screen.dart';
import 'package:mocktester_v2/features/coaching/presentation/coaching_directory_screen.dart';
import 'package:mocktester_v2/features/community/presentation/community_feed_screen.dart';
import 'package:mocktester_v2/features/creator/presentation/admin/admin_control_hub_screen.dart';
import 'package:mocktester_v2/features/creator/presentation/creator_auth_screen.dart';
import 'package:mocktester_v2/features/creator/presentation/creator_dashboard_screen.dart';
import 'package:mocktester_v2/features/creator/presentation/mock_builder/creator_mock_builder_screen.dart';
import 'package:mocktester_v2/features/creator/presentation/profile/creator_profile_screen.dart';
import 'package:mocktester_v2/features/learn/presentation/learn_chat_screen.dart';
import 'package:mocktester_v2/features/learn/presentation/learn_hub_screen.dart';
import 'package:mocktester_v2/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:mocktester_v2/features/onboarding/presentation/splash_screen.dart';
import 'package:mocktester_v2/features/profile/presentation/leaderboard/district_leaderboard_screen.dart';
import 'package:mocktester_v2/features/profile/presentation/profile_screen.dart';
import 'package:mocktester_v2/features/profile/presentation/saved_questions_screen.dart';
import 'package:mocktester_v2/features/profile/presentation/wrong_questions_screen.dart';
import 'package:mocktester_v2/features/current_affairs/presentation/saved_current_affairs_screen.dart';
import 'package:mocktester_v2/features/quiz/presentation/chapter_select_screen.dart';
import 'package:mocktester_v2/features/quiz/presentation/quiz_screen.dart';
import 'package:mocktester_v2/features/quiz/presentation/subject_directory_screen.dart';
import 'package:mocktester_v2/features/revision/presentation/revision_practice_screen.dart';
import 'package:mocktester_v2/features/revision/presentation/tabs/revision_tab.dart';
import 'package:mocktester_v2/features/sectional/presentation/batch_classroom_screen.dart';
import 'package:mocktester_v2/features/sectional/presentation/sectional_cbt_screen.dart';
import 'package:mocktester_v2/features/sectional/presentation/student_cbt_report_screen.dart';
import 'package:mocktester_v2/features/sectional/presentation/tabs/sectional_tab.dart';
import 'package:mocktester_v2/features/shell/presentation/home_shell_screen.dart';
import 'package:mocktester_v2/features/home/presentation/tabs/home_tab.dart';
import 'package:mocktester_v2/features/tools/presentation/exam_doc_merger_screen.dart';
import 'package:mocktester_v2/features/tools/presentation/exam_photo_resizer_screen.dart';

import 'package:mocktester_v2/tools/demo/demo_fixtures.dart';

/// Every screen of the app, openable with fixture data.
///
/// This is the fastest way to verify that a refactor did not break a route:
/// tap through the list and check each screen renders and behaves.
class DemoScreenDirectoryScreen extends StatelessWidget {
  const DemoScreenDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final List<_ScreenEntry> entries = <_ScreenEntry>[
      _ScreenEntry('HomeShellScreen (bottom-nav root)', Icons.home_max, () => const HomeScreen(), 'Live: loads remote config + bulletin widgets'),
      _ScreenEntry('OnboardingWelcomeScreen', Icons.rocket_launch, () => const OnboardingWelcomeScreen(), 'First-run flow, saves name + district'),
      _ScreenEntry('SplashScreen (legacy route)', Icons.water_drop, () => const SplashScreen(), 'Kept for compatibility, opens HomeShellScreen'),
      _ScreenEntry('HomeTab', Icons.dashboard, () => Scaffold(body: HomeTab(
            appConfig: DemoFixtures.appConfig,
            homeData: DemoFixtures.homeData,
            subjectMapping: DemoFixtures.subjectMapping,
            isDarkMode: dark,
            lastLearnTitle: 'Cell Biology',
            lastLearnProgress: 0.4,
            lastNextTopic: 'Human Eye',
            hasLearningHistory: true,
            onTapUrl: (String a, String b) {},
            onNavigateToLearn: () {},
          )), 'Home tab isolated from the shell'),
      _ScreenEntry('RevisionTab', Icons.menu_book, () => Scaffold(body: RevisionTab(
            subjectMapping: DemoFixtures.subjectMapping,
            onLaunchPractice: (BuildContext c, String t, String p) {},
          )), 'Chapterwise revision hub'),
      _ScreenEntry('SectionalTab', Icons.assignment, () => Scaffold(body: SectionalTab(
            sectionalData: DemoFixtures.sectionalData,
            isDarkMode: dark,
            onLaunchCbtMock: (BuildContext c, String t, String p) {},
          )), 'Exam-wise sectional panels'),
      _ScreenEntry('SectionalCbtScreen (exam engine)', Icons.timer, () => SectionalCbtScreen(
            testTitle: 'Demo CBT — 3 Questions',
            questions: DemoFixtures.questions,
            subFolder: 'demo/set1.json',
          ), 'Timer, palette, bookmark, report-error, AI explanation'),
      _ScreenEntry('QuizScreen (offline loader)', Icons.quiz, () => const QuizScreen(
            title: 'Demo Quiz (network)',
            jsonPath: 'static/physics/light.json',
          ), 'Loads via the shared JsonFetcher'),
      _ScreenEntry('RevisionPracticeScreen', Icons.school, () => RevisionPracticeScreen(
            testTitle: 'Demo Revision',
            questions: DemoFixtures.questions,
            storageKey: 'demo_rev_progress',
          ), 'Resume + explanation cards'),
      _ScreenEntry('LearnHubScreen', Icons.psychology, () => const LearnHubScreen(), 'Subject list (remote learn_data.json)'),
      _ScreenEntry('LearnChatScreen', Icons.chat, () => const LearnChatScreen(
            jsonUrl: 'learn/biology/cell.json',
            chapterTitle: 'Cell Biology',
          ), 'Duolingo-style card flow'),
      _ScreenEntry('AiDoubtScreen (Groq + RAG)', Icons.smart_toy, () => AiDoubtScreen(isDarkMode: dark), 'Uses GROQ_API_KEY when provided'),
      _ScreenEntry('AiChatScreen (on-device LLM)', Icons.memory, () => AiChatScreen(isDarkMode: dark), 'GGUF picker; engine adapter optional'),
      _ScreenEntry('ChallengeQuizScreen', Icons.flash_on, () => ChallengeQuizScreen(
            questions: DemoFixtures.rawQuestions,
            challengeCode: 'DEMO-1234',
            challengerName: 'Demo Challenger',
            challengerScore: 2,
            isDarkMode: dark,
          ), 'Duel mode from a shared code'),
      _ScreenEntry('ChallengeResultScreen', Icons.emoji_events, () => ChallengeResultScreen(
            challengerName: 'Demo Challenger',
            challengerScore: 2,
            myScore: 3,
            totalTimeTaken: 96,
            challengeCode: 'DEMO-1234',
            isDarkMode: dark,
          ), 'Needs Supabase for the leaderboard insert'),
      _ScreenEntry('SprintChallengeScreen', Icons.speed, () => SprintChallengeScreen(
            subjectMapping: DemoFixtures.subjectMapping,
            roomSets: '1-2',
          ), '10-question sprint from CDN JSON'),
      _ScreenEntry('ChapterSelectScreen', Icons.list_alt, () => ChapterSelectScreen(
            categoryTitle: 'Demo Category',
            chapterMapping: DemoFixtures.chapterMapping,
          ), 'Legacy chapter picker'),
      _ScreenEntry('SubjectDirectoryScreen', Icons.folder_open, () => SubjectDirectoryScreen(
            title: 'Demo Directory',
            icon: '📚',
            accentColor: const Color(0xFF2563EB),
            subSections: const <Map<String, dynamic>>[
              <String, dynamic>{'key': 'phy_mapping', 'title': 'Physics'},
              <String, dynamic>{'key': 'bio_mapping', 'title': 'Biology'},
            ],
            subjectMapping: DemoFixtures.subjectMapping,
            onLaunchPractice: (BuildContext c, String t, String p) {},
          ), 'Searchable chapter directory'),
      _ScreenEntry('ProfileScreen', Icons.person, () => ProfileScreen(
            isHindi: true,
            isDarkMode: dark,
            onHindiChanged: (bool v) {},
            onDarkModeChanged: (bool v) => ThemeController.setDark(v),
          ), 'Progress, saved vault, theme toggle'),
      _ScreenEntry('SavedQuestionsScreen', Icons.bookmark, () => SavedQuestionsScreen(isDarkMode: dark), 'Bookmarked questions'),
      _ScreenEntry('WrongQuestionsScreen', Icons.error_outline, () => const WrongQuestionsScreen(), 'Wrong-question vault + mastery ladder'),
      _ScreenEntry('SavedCurrentAffairsScreen', Icons.newspaper, () => const SavedCurrentAffairsScreen(), 'Bookmarked current affairs'),
      _ScreenEntry('DistrictLeaderboardScreen', Icons.leaderboard, () => DistrictLeaderboardScreen(isDarkMode: dark), 'Supabase district ranking'),
      _ScreenEntry('CommunityFeedScreen', Icons.groups, () => CommunityFeedScreen(isDarkMode: dark), 'Posts, polls, comments'),
      _ScreenEntry('CoachingDirectoryScreen', Icons.apartment, () => CoachingDirectoryScreen(isDarkMode: dark), 'Approved coaching list'),
      _ScreenEntry('CreatorAuthScreen', Icons.storefront, () => CreatorAuthScreen(isDarkMode: dark), 'Creator login / onboarding'),
      _ScreenEntry('CreatorDashboardScreen', Icons.dashboard_customize, () => CreatorDashboardScreen(creatorHandle: 'demo', isDarkMode: dark), 'Studio hub'),
      _ScreenEntry('CreatorMockBuilderScreen', Icons.build, () => CreatorMockBuilderScreen(creatorHandle: 'demo', isDarkMode: dark), 'AI-assisted paper builder'),
      _ScreenEntry('CreatorProfileScreen', Icons.badge, () => CreatorProfileScreen(creatorHandle: 'demo', isDarkMode: dark), 'Public coaching profile'),
      _ScreenEntry('AdminControlHubScreen', Icons.admin_panel_settings, () => AdminControlHubScreen(isDarkMode: dark), 'Approval tools'),
      _ScreenEntry('BatchClassroomScreen', Icons.class_, () => BatchClassroomScreen(
            batchData: DemoFixtures.batchData,
            isDarkMode: dark,
          ), 'Batch tests list'),
      _ScreenEntry('StudentCbtReportScreen', Icons.assessment, () => const StudentCbtReportScreen(
            studentName: 'Demo Aspirant',
            testTitle: 'Demo Batch Test 1',
            score: 1,
            responseBreakdown: <dynamic>[],
          ), 'Per-student analytics report'),
      _ScreenEntry('ExamPhotoResizerScreen', Icons.photo_size_select_large, () => const ExamPhotoResizerScreen(isDark: false), 'Utility: resize to exam specs'),
      _ScreenEntry('ExamDocMergerScreen', Icons.merge_type, () => const ExamDocMergerScreen(isDark: false), 'Utility: merge documents to PDF'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Directory'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${entries.length} screens • tap to open with fixtures',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final _ScreenEntry entry = entries[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(entry.icon, size: 20),
              ),
              title: Text(
                entry.name,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(entry.note, style: const TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => entry.builder()),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScreenEntry {
  const _ScreenEntry(this.name, this.icon, this.builder, this.note);

  final String name;
  final IconData icon;
  final Widget Function() builder;
  final String note;
}
