import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

import '../models/question_model.dart';
import '../services/telegram_tracker.dart';
import '../services/challenge_service.dart';
import '../services/ai_explainer_service.dart';
import 'challenge_quiz_screen.dart';
import 'community_feed_screen.dart';
import 'creator_auth_screen.dart';
import 'creator_dashboard_screen.dart';
import 'learn_hub_screen.dart';
import 'profile_screen.dart';
import 'revision_practice_screen.dart';
import 'sectional_cbt_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/revision_tab.dart';
import 'tabs/sectional_tab.dart';

// 🛠️ Aspirant Utility Tools Imports
import '../widgets/exam_photo_resizer_screen.dart';
import '../widgets/exam_doc_merger_screen.dart';

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

    try {
      final String configStr = await rootBundle.loadString('assets/data/app_config.json');
      _appConfig = jsonDecode(configStr);
      AiExplainerService.updateModelFromConfig(_appConfig);
    } catch (e) {
      debugPrint("Error loading app_config.json: $e");
    }

    try {
      final String homeStr = await rootBundle.loadString('assets/data/home_data.json');
      _homeData = jsonDecode(homeStr);
    } catch (e) {
      debugPrint("Error loading home_data.json: $e");
    }

    final prefs = await SharedPreferences.getInstance();

    String? cachedMapping = prefs.getString('cached_subject_mapping_json');
    if (cachedMapping != null && cachedMapping.isNotEmpty) {
      try {
        _subjectMapping = Map<String, dynamic>.from(jsonDecode(cachedMapping));
      } catch (_) {}
    }
    if (_subjectMapping.isEmpty) {
      try {
        final String subjectStr = await rootBundle.loadString('assets/data/subject_mapping.json');
        _subjectMapping = Map<String, dynamic>.from(jsonDecode(subjectStr));
      } catch (e) {
        debugPrint("Error loading subject_mapping.json: $e");
      }
    }

    String? persistentSectional = prefs.getString('persistent_sectional_data_json');
    if (persistentSectional != null && persistentSectional.isNotEmpty) {
      try {
        _sectionalData = Map<String, dynamic>.from(jsonDecode(persistentSectional));
      } catch (_) {}
    }
    if (_sectionalData.isEmpty) {
      try {
        final String sectionalStr = await rootBundle.loadString('assets/data/sectional_data.json');
        _sectionalData = Map<String, dynamic>.from(jsonDecode(sectionalStr));
      } catch (e) {
        debugPrint("Error loading sectional_data.json: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingConfig = false;
      });
    }

    _fetchLiveAppConfig();
    _fetchSectionalDataLive();
    _fetchSubjectMappingLive();
  }

  Future<dynamic> _fetchRobustJson(String path) async {
    String cleanPath = path.trim();
    cleanPath = cleanPath
        .replaceAll('https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/', '')
        .replaceAll('https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/', '')
        .replaceAll('https://raw.githubusercontent.com/zxcty54/content_base/main/', '')
        .replaceAll('https://raw.githubusercontent.com/zxcty54/content_base/refs/heads/main/', '')
        .replaceAll('https://cdn.statically.io/gh/zxcty54/content_base/main/', '')
        .replaceAll('https://raw.githack.com/zxcty54/content_base/main/', '')
        .replaceAll('https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/', '')
        .replaceAll('https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/', '')
        .replaceAll('https://raw.githubusercontent.com/zxcty54/quiz/main/', '')
        .replaceAll('https://raw.githubusercontent.com/zxcty54/quiz/refs/heads/main/', '')
        .replaceAll('https://cdn.statically.io/gh/zxcty54/quiz/main/', '')
        .replaceAll('https://raw.githack.com/zxcty54/quiz/main/', '');

    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    if (cleanPath.contains('?')) cleanPath = cleanPath.split('?').first;

    final int ts = DateTime.now().millisecondsSinceEpoch;
    String encodedPath = Uri.encodeFull(cleanPath);

    final String apiUrl = "https://api.github.com/repos/zxcty54/content_base/contents/$encodedPath?ref=main&t=$ts";
    try {
      final apiRes = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3.raw',
          'User-Agent': 'MockTesterApp-Flutter',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 4));

      if (apiRes.statusCode == 200) {
        String rawBody = utf8.decode(apiRes.bodyBytes).trim();
        if (rawBody.startsWith('\uFEFF')) rawBody = rawBody.substring(1).trim();
        rawBody = rawBody.replaceAll(r'```json', '').replaceAll(r'```', '').trim();
        if (!rawBody.startsWith('<') && !rawBody.startsWith('<!DOCTYPE')) {
          final dynamic parsed = jsonDecode(rawBody);
          if (parsed != null) return parsed;
        }
      }
    } catch (_) {}

    List<String> mirrorUrls = [
      "https://raw.githack.com/zxcty54/content_base/main/$encodedPath",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/$encodedPath?t=$ts",
      "https://cdn.statically.io/gh/zxcty54/content_base/main/$encodedPath",
      "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/$encodedPath?t=$ts",
      "https://raw.githubusercontent.com/zxcty54/content_base/main/$encodedPath?t=$ts",
    ];

    for (String url in mirrorUrls) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          String rawBody = utf8.decode(res.bodyBytes).trim();
          if (rawBody.startsWith('\uFEFF')) rawBody = rawBody.substring(1).trim();
          rawBody = rawBody.replaceAll(r'```json', '').replaceAll(r'```', '').trim();
          if (!rawBody.startsWith('<') && !rawBody.startsWith('<!DOCTYPE')) {
            final dynamic parsed = jsonDecode(rawBody);
            if (parsed != null) return parsed;
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> _fetchLiveAppConfig() async {
    final data = await _fetchRobustJson("app_config.json");
    if (data != null && data is Map && mounted) {
      setState(() {
        _appConfig = Map<String, dynamic>.from(data);
      });
      AiExplainerService.updateModelFromConfig(_appConfig);
    }
  }

  Future<void> _fetchSectionalDataLive() async {
    final data = await _fetchRobustJson("sectional_data.json");
    if (data != null && data is Map && mounted) {
      setState(() {
        _sectionalData = Map<String, dynamic>.from(data);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('persistent_sectional_data_json', jsonEncode(data));
    }
  }

  Future<void> _fetchSubjectMappingLive() async {
    final data = await _fetchRobustJson("subject_mapping.json");
    if (data != null && data is Map && mounted) {
      setState(() {
        _subjectMapping = Map<String, dynamic>.from(data);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_subject_mapping_json', jsonEncode(data));
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
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('cached_subject_mapping_json');
              await prefs.remove('cached_sectional_data_json');
              await prefs.remove('persistent_subject_mapping_json');
              await prefs.remove('persistent_sectional_data_json');

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
            icon: const Icon(Icons.school_rounded, color: Color(0xFF2563EB)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LearnHubScreen()),
              ).then((_) => _loadRealtimeProgress());
            },
          ),
        ],
      ),
      // 🌟 ROYAL BLUE THEMED DRAWER
      drawer: Drawer(
        backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        child: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            final prefs = snapshot.data;
            final String userName = prefs?.getString('user_name') ?? 'Aspirant';
            final String userEmail = prefs?.getString('user_email') ?? '';
            final String userMobile = prefs?.getString('user_mobile') ?? '';

            String subtitleText = 'BPSC / BSSC Aspirant';
            if (userEmail.isNotEmpty && userMobile.isNotEmpty) {
              subtitleText = '$userEmail • $userMobile';
            } else if (userEmail.isNotEmpty) {
              subtitleText = userEmail;
            } else if (userMobile.isNotEmpty) {
              subtitleText = userMobile;
            }

            return Column(
              children: [
                // 💙 1. Royal Blue Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 30),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.28)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('⚡', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 5),
                            Text(
                              'ASPIRANT ACCESS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 📜 2. Navigation Actions List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    children: [
                      _buildDrawerTile(
                        icon: Icons.dashboard_customize_rounded,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Creator Studio & Analytics',
                        subtitle: 'Dashboard, Quizzes, Notes & Mock Builder',
                        onTap: () {
                          Navigator.pop(context);
                          _openCreatorStudio();
                        },
                      ),

                      const SizedBox(height: 8),

                      // 🛠️ Aspirant Utility Tools Section
                      Container(
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.03)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isDarkMode
                                ? Colors.white.withOpacity(0.06)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            leading: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB45309).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.handyman_rounded, color: Color(0xFFB45309), size: 18),
                            ),
                            title: const Text(
                              'Aspirant Utility Tools',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            children: [
                              _buildSubDrawerTile(
                                icon: Icons.photo_size_select_large_rounded,
                                iconColor: const Color(0xFFB45309),
                                title: 'Photo & Sign Resizer',
                                subtitle: 'BPSC, BSSC, Police (<20KB / 50KB)',
                                badge: 'READY',
                                badgeColor: const Color(0xFF16A34A),
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
                              _buildSubDrawerTile(
                                icon: Icons.picture_as_pdf_rounded,
                                iconColor: const Color(0xFF2563EB),
                                title: 'Doc & ID Card Merger',
                                subtitle: 'ID Card Front/Back • 1-Doc PDF',
                                badge: 'NEW',
                                badgeColor: const Color(0xFF2563EB),
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
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      _buildDrawerTile(
                        icon: Icons.dynamic_feed_rounded,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Community Feed',
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentBottomIndex = 3);
                        },
                      ),
                      _buildDrawerTile(
                        icon: Icons.school_rounded,
                        iconColor: const Color(0xFF059669),
                        title: 'Learn Hub',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LearnHubScreen()),
                          ).then((_) => _loadRealtimeProgress());
                        },
                      ),
                      _buildDrawerTile(
                        icon: Icons.person_rounded,
                        iconColor: const Color(0xFF4F46E5),
                        title: 'My Profile',
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentBottomIndex = 4);
                        },
                      ),
                      _buildDrawerTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: Colors.grey,
                        title: 'Privacy Policy',
                        onTap: () {
                          Navigator.pop(context);
                          _openWebsiteUrl('Privacy Policy', 'https://www.mocktester.online/p/privacy.html');
                        },
                      ),
                    ],
                  ),
                ),

                // ⚠️ 3. Disclaimer Footer
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'MockTester is an independent prep platform and is NOT affiliated with any government entity.',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            height: 1.35,
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
      // 🌟 ROYAL BLUE HIGHLIGHTED BOTTOM NAVIGATION BAR
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: _isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          height: 66,
          elevation: 0,
          backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFF2563EB).withOpacity(0.14),
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          selectedIndex: _currentBottomIndex,
          onDestinationSelected: (idx) {
            setState(() => _currentBottomIndex = idx);
            if (idx == 0) _loadRealtimeProgress();
            if (idx == 1) _fetchSubjectMappingLive();
            if (idx == 2) _fetchSectionalDataLive();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF2563EB)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB)),
              label: 'Revision',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded, color: Color(0xFF2563EB)),
              label: 'Sectional',
            ),
            NavigationDestination(
              icon: Icon(Icons.dynamic_feed_outlined),
              selectedIcon: Icon(Icons.dynamic_feed_rounded, color: Color(0xFF2563EB)),
              label: 'Community',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF2563EB)),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // 🛠️ Drawer Item Helpers
  Widget _buildDrawerTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 13,
        color: _isDarkMode ? Colors.white38 : Colors.black26,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSubDrawerTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 20, right: 14),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 10.5,
          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          badge,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            color: badgeColor,
          ),
        ),
      ),
      onTap: onTap,
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
