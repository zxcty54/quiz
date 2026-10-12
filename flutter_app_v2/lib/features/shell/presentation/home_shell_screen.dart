// v1 source: flutter_app/lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

import 'package:mocktester_v2/core/models/question_model.dart';
import 'package:mocktester_v2/core/services/telemetry/telegram_tracker.dart';
import 'package:mocktester_v2/features/challenge/data/challenge_service.dart';
import 'package:mocktester_v2/features/ai/data/ai_explainer_service.dart';
import 'package:mocktester_v2/features/challenge/presentation/challenge_quiz_screen.dart';
import 'package:mocktester_v2/features/community/presentation/community_feed_screen.dart';
import 'package:mocktester_v2/features/creator/presentation/creator_auth_screen.dart';
import 'package:mocktester_v2/features/creator/presentation/creator_dashboard_screen.dart';
import 'package:mocktester_v2/features/learn/presentation/learn_hub_screen.dart';
import 'package:mocktester_v2/features/profile/presentation/profile_screen.dart';
import 'package:mocktester_v2/features/revision/presentation/revision_practice_screen.dart';
import 'package:mocktester_v2/features/sectional/presentation/sectional_cbt_screen.dart';
import 'package:mocktester_v2/features/home/presentation/tabs/home_tab.dart';
import 'package:mocktester_v2/features/revision/presentation/tabs/revision_tab.dart';
import 'package:mocktester_v2/features/sectional/presentation/tabs/sectional_tab.dart';

// 🛠️ Aspirant Utility Tools Imports
import 'package:mocktester_v2/features/tools/presentation/exam_photo_resizer_screen.dart';
import 'package:mocktester_v2/features/tools/presentation/exam_doc_merger_screen.dart';
import 'package:mocktester_v2/core/config/remote_config_service.dart';
import 'package:mocktester_v2/core/network/json_fetcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentBottomIndex = 0;
  bool _isDarkMode = false;
  bool _isHindi = true;

  Map<String, dynamic> _appConfig = {};
  Map<String, dynamic> _homeData = {};
  Map<String, dynamic> _subjectMapping = {};
  Map<String, dynamic> _sectionalData = {};

  String _lastLearnTitle = "Cell Biology & Organelles";
  double _lastLearnProgress = 0.0;
  String _lastNextTopic = "Start learning now";
  bool _hasLearningHistory = false;
  bool _isLoadingConfig = true;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TelegramTracker.initSession();
    _loadAllConfigs();
    _initChallengeDeepLinks();
    AiExplainerService.syncBatchMasteryEvolution();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initChallengeDeepLinks() {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleIncomingChallengeUri(uri),
      onError: (err) => debugPrint("DeepLink stream error: $err"),
    );

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingChallengeUri(uri);
    }).catchError((err) => debugPrint("DeepLink initial error: $err"));
  }

  Future<void> _handleIncomingChallengeUri(Uri uri) async {
    final uriStr = uri.toString();
    if (uriStr.contains('challenge') || uriStr.contains('duel')) {
      final code = uri.queryParameters['code'];
      final challengerName = uri.queryParameters['by'] ?? 'Dost';
      final challengerScore = int.tryParse(uri.queryParameters['score'] ?? '0') ?? 0;

      if (code != null && code.isNotEmpty) {
        final questions = await ChallengeService.loadQuestionsFromCode(code);
        if (questions.isNotEmpty && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChallengeQuizScreen(
                questions: questions,
                challengeCode: code,
                challengerName: challengerName,
                challengerScore: challengerScore,
                isDarkMode: _isDarkMode,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRealtimeProgress();
      _fetchLiveAppConfig();
      _fetchSectionalDataLive();
      _fetchSubjectMappingLive();
      AiExplainerService.syncBatchMasteryEvolution();
    }
  }

  Future<void> _loadAllConfigs() async {
    await _loadRealtimeProgress();

    // Cache-first (instant paint), then live refresh in the background.
    final RemoteConfigBundle bundle = await RemoteConfigService.instance.loadLocal();

    if (mounted) {
      setState(() {
        _appConfig = bundle.appConfig;
        _homeData = bundle.homeData;
        _subjectMapping = bundle.subjectMapping;
        _sectionalData = bundle.sectionalData;
        _isLoadingConfig = false;
      });
    }

    _fetchLiveAppConfig();
    _fetchSectionalDataLive();
    _fetchSubjectMappingLive();
  }

  /// Thin delegate — the multi-mirror logic now lives in core/network.
  Future<dynamic> _fetchRobustJson(String path) =>
      JsonFetcher.instance.fetchRobust(path);

  Future<void> _fetchLiveAppConfig() async {
    final Map<String, dynamic>? config =
        await RemoteConfigService.instance.refreshAppConfig();
    if (config != null && mounted) {
      setState(() => _appConfig = config);
    }
  }

  Future<void> _fetchSectionalDataLive() async {
    final Map<String, dynamic>? data =
        await RemoteConfigService.instance.refreshSectionalData();
    if (data != null && mounted) {
      setState(() => _sectionalData = data);
    }
  }

  Future<void> _fetchSubjectMappingLive() async {
    final Map<String, dynamic>? data =
        await RemoteConfigService.instance.refreshSubjectMapping();
    if (data != null && mounted) {
      setState(() => _subjectMapping = data);
    }
  }

  Future<void> _loadRealtimeProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasLearningHistory = prefs.getBool('has_learning_history') ?? false;
        _lastLearnTitle = prefs.getString('last_learn_title') ?? "Cell Biology & Organelles";
        _lastLearnProgress = prefs.getDouble('last_learn_progress') ?? 0.0;
        _lastNextTopic = prefs.getString('last_next_topic') ?? "Start learning now";
      });
    }
  }

  void _openCreatorStudio() async {
    final prefs = await SharedPreferences.getInstance();
    final String? loggedInHandle = prefs.getString('logged_in_creator_handle');

    if (!mounted) return;

    if (loggedInHandle != null && loggedInHandle.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatorDashboardScreen(
            creatorHandle: loggedInHandle,
            isDarkMode: _isDarkMode,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatorAuthScreen(isDarkMode: _isDarkMode),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfig) {
      return Scaffold(
        appBar: AppBar(title: const Text('MockTester')),
        body: _buildSkeletonLoading(),
      );
    }

    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'MockTester',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
            tooltip: "Instant Force Update",
            onPressed: () async {
              await RemoteConfigService.instance.purgeAndRefresh();

              await _fetchLiveAppConfig();
              await _fetchSectionalDataLive();
              await _fetchSubjectMappingLive();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚡ All Cache Purged! 100% Live JSON Fetched.'),
                    backgroundColor: Color(0xFF16A34A),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.school_rounded, color: Color(0xFF075E54)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LearnHubScreen()),
              ).then((_) => _loadRealtimeProgress());
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            final prefs = snapshot.data;
            final String userName = prefs?.getString('user_name') ?? 'Aspirant';
            final String userEmail = prefs?.getString('user_email') ?? '';
            final String userMobile = prefs?.getString('user_mobile') ?? '';

            String subtitleText = 'MockTester Aspirant';
            if (userEmail.isNotEmpty && userMobile.isNotEmpty) {
              subtitleText = '$userEmail • $userMobile';
            } else if (userEmail.isNotEmpty) {
              subtitleText = userEmail;
            } else if (userMobile.isNotEmpty) {
              subtitleText = userMobile;
            }

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      UserAccountsDrawerHeader(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        accountName: Text(
                          userName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        accountEmail: Text(
                          subtitleText,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        currentAccountPicture: const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF2563EB), size: 36),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF2563EB)),
                        title: const Text('Creator Studio & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Dashboard, Quizzes, Notes & Mock Builder'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.pop(context);
                          _openCreatorStudio();
                        },
                      ),
                      const Divider(),

                      // 🛠️ Aspirant Utility Tools Section
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: const Icon(Icons.handyman_rounded, color: Color(0xFFB45309)),
                          title: const Text(
                            'Aspirant Utility Tools',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.only(left: 32, right: 16),
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB45309).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.photo_size_select_large_rounded,
                                  size: 18,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                              title: const Text(
                                'Photo & Sign Resizer',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              subtitle: const Text(
                                'BPSC, BSSC, Police (<20KB / 50KB)',
                                style: TextStyle(fontSize: 11),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'READY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExamPhotoResizerScreen(isDark: _isDarkMode),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.only(left: 32, right: 16),
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              title: const Text(
                                'Doc & ID Card Merger',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              subtitle: const Text(
                                'ID Card Front/Back • 1-Doc PDF (<100KB)',
                                style: TextStyle(fontSize: 11),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExamDocMergerScreen(isDark: _isDarkMode),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.dynamic_feed_rounded, color: Color(0xFF2563EB)),
                        title: const Text('Community Feed'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentBottomIndex = 3);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: const Text('Learn Hub'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LearnHubScreen()),
                          ).then((_) => _loadRealtimeProgress());
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('My Profile'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentBottomIndex = 4);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: Colors.grey),
                        title: const Text('Privacy Policy', style: TextStyle(fontSize: 13.5)),
                        onTap: () {
                          Navigator.pop(context);
                          _openWebsiteUrl('Privacy Policy', 'https://www.mocktester.online/p/privacy.html');
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Disclaimer: MockTester is an independent educational prep platform and is NOT affiliated with, endorsed by, or representing any government entity (BPSC, SSC, etc.).',
                          style: TextStyle(
                            fontSize: 10,
                            color: _isDarkMode ? Colors.white60 : Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: IndexedStack(
        index: _currentBottomIndex,
        children: [
          HomeTab(
            appConfig: _appConfig,
            homeData: _homeData,
            subjectMapping: _subjectMapping,
            isDarkMode: _isDarkMode,
            lastLearnTitle: _lastLearnTitle,
            lastLearnProgress: _lastLearnProgress,
            lastNextTopic: _lastNextTopic,
            hasLearningHistory: _hasLearningHistory,
            onTapUrl: _openWebsiteUrl,
            onNavigateToLearn: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LearnHubScreen()),
              ).then((_) => _loadRealtimeProgress());
            },
          ),
          RevisionTab(
            key: ValueKey('rev_${_subjectMapping.keys.length}'),
            subjectMapping: _subjectMapping,
            onLaunchPractice: _launchRevisionPractice,
          ),
          SectionalTab(
            key: ValueKey('sec_${_sectionalData.keys.join('_')}'),
            sectionalData: _sectionalData,
            isDarkMode: _isDarkMode,
            onLaunchCbtMock: _launchCbtMock,
          ),
          CommunityFeedScreen(isDarkMode: _isDarkMode),
          ProfileScreen(
            isHindi: _isHindi,
            isDarkMode: _isDarkMode,
            onHindiChanged: (v) => setState(() => _isHindi = v),
            onDarkModeChanged: (v) => setState(() => _isDarkMode = v),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentBottomIndex = idx);
          if (idx == 0) _loadRealtimeProgress();
          if (idx == 1) _fetchSubjectMappingLive();
          if (idx == 2) _fetchSectionalDataLive();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Revision'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Sectional'),
          NavigationDestination(icon: Icon(Icons.dynamic_feed_outlined), selectedIcon: Icon(Icons.dynamic_feed_rounded), label: 'Community'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _openWebsiteUrl(String linkTitle, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _launchCbtMock(BuildContext context, String title, String path) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );

    Set<String> candidatePaths = {path};

    if (path.contains('bssc_cgl/aptitude')) candidatePaths.add(path.replaceAll('bssc_cgl/aptitude', 'bssc_cgl_aptitude'));
    if (path.contains('bssc_cgl/reasoning')) candidatePaths.add(path.replaceAll('bssc_cgl/reasoning', 'bssc_cgl_reasoning'));
    if (path.contains('bssc_inter/gk')) candidatePaths.add(path.replaceAll('bssc_inter/gk', 'bssc_inter_aptitude'));
    if (path.contains('bssc_inter/aptitude')) candidatePaths.add(path.replaceAll('bssc_inter/aptitude', 'bssc_inter_aptitude'));
    if (path.contains('bssc_inter/reasoning')) candidatePaths.add(path.replaceAll('bssc_inter/reasoning', 'bssc_inter_reasoning'));
    if (path.contains('ssc/general')) candidatePaths.add(path.replaceAll('ssc/general', 'aptitude'));
    if (path.contains('bihar_amin')) candidatePaths.add(path.replaceAll('bihar_amin', 'bihar-amin'));
    if (path.contains('bihar-amin')) candidatePaths.add(path.replaceAll('bihar-amin', 'bihar_amin'));

    List<String> expandedPaths = [];
    for (String p in candidatePaths) {
      expandedPaths.add(p);
      final reg = RegExp(r'set_?0?(\d+)\.json');
      final match = reg.firstMatch(p);
      if (match != null) {
        final numStr = match.group(1)!;
        final intNum = int.tryParse(numStr) ?? 1;
        final padded = intNum.toString().padLeft(2, '0');
        final base = p.substring(0, match.start);
        expandedPaths.add('${base}set$intNum.json');
        expandedPaths.add('${base}set_$padded.json');
        expandedPaths.add('${base}set_$intNum.json');
        expandedPaths.add('${base}set$padded.json');
      }
    }

    dynamic data;
    String finalSubFolder = path;
    for (String tryPath in expandedPaths.toSet()) {
      data = await _fetchRobustJson(tryPath);
      if (data != null) {
        finalSubFolder = tryPath;
        break;
      }
    }

    if (context.mounted) Navigator.pop(context);

    if (data != null) {
      List<dynamic>? rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList = data['questions'] ?? data['data'] ?? data['items'];
      }

      if (rawList != null && rawList.isNotEmpty) {
        try {
          List<Question> qList = [];
          for (var item in rawList) {
            if (item is Map) {
              qList.add(Question.fromJson(Map<String, dynamic>.from(item)));
            }
          }

          if (context.mounted && qList.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => SectionalCbtScreen(
                  testTitle: title,
                  questions: qList,
                  subFolder: finalSubFolder,
                ),
              ),
            );
            return;
          }
        } catch (e) {
          debugPrint("Question parse error: $e");
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ "$title" load nahi ho paya. Path check karein: $path'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _launchRevisionPractice(BuildContext context, String title, String path) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );

    final data = await _fetchRobustJson(path);
    if (context.mounted) Navigator.pop(context);

    if (data != null) {
      List<dynamic>? rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList = data['questions'] ?? data['data'] ?? data['items'];
      }

      if (rawList != null && rawList.isNotEmpty) {
        try {
          List<Question> qList = [];
          for (var item in rawList) {
            if (item is Map) {
              try {
                qList.add(Question.fromJson(Map<String, dynamic>.from(item)));
              } catch (_) {}
            }
          }

          if (context.mounted && qList.isNotEmpty) {
            String cleanKeyPath = path.split('?').first.replaceAll('/', '_').replaceAll('.', '_');
            final String progKey = 'rev_prog_$cleanKeyPath';

            final prefs = await SharedPreferences.getInstance();
            final int savedIndex = prefs.getInt(progKey) ?? 0;

            if (savedIndex > 0 && savedIndex < qList.length && context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Text('⚡ ', style: TextStyle(fontSize: 18)),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'Aapne pichli baar ${savedIndex + 1}/${qList.length} questions attempt kiye the. Kahan se continue karna hai?',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1), height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await prefs.remove(progKey);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => RevisionPracticeScreen(
                                testTitle: title,
                                questions: qList,
                                initialIndex: 0,
                                storageKey: progKey,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Restart (Q.1) 🔄', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => RevisionPracticeScreen(
                              testTitle: title,
                              questions: qList,
                              initialIndex: savedIndex,
                              storageKey: progKey,
                            ),
                          ),
                        );
                      },
                      child: Text('Resume (Q.${savedIndex + 1}) ▶', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              return;
            }

            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => RevisionPracticeScreen(
                    testTitle: title,
                    questions: qList,
                    initialIndex: 0,
                    storageKey: progKey,
                  ),
                ),
              );
            }
            return;
          }
        } catch (e) {
          debugPrint("Revision parse error: $e");
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test questions load nahi ho paye. Internet check karein.')),
      );
    }
  }
}
