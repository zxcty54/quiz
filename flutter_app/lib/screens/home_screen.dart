import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'notifications_screen.dart';
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
  int _unreadNotifications = 0;
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
      _loadUnreadNotifications();
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final creatorHandle = prefs.getString('logged_in_creator_handle');
      final userId = prefs.getString('user_id') ?? 'user';
      final handle = (creatorHandle != null && creatorHandle.trim().isNotEmpty)
          ? creatorHandle.trim()
          : userId.trim();

      final rows = await Supabase.instance.client
          .from('user_notifications')
          .select('id')
          .eq('user_handle', handle)
          .eq('is_read', false)
          .limit(100);

      if (mounted) setState(() => _unreadNotifications = rows.length);
    } catch (_) {
      // user_notifications table/SQL na hone par silent fail
    }
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(isDarkMode: _isDarkMode),
      ),
    ).then((_) => _loadUnreadNotifications());
  }

  Future<void> _loadAllConfigs() async {
    Timer(const Duration(seconds: 6), () {
      if (mounted && _isLoadingConfig) {
        setState(() => _isLoadingConfig = false);
      }
    });

    final prefs = await SharedPreferences.getInstance();

    // 🌓 Sync persistent theme state from SharedPreferences
    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
        _isHindi = prefs.getBool('is_hindi') ?? true;
      });
    }

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
      "https://cdn.statically.io/gh/zxcty54/content_base/main/$encodedPath",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/$encodedPath?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/$encodedPath?t=$ts",
      "https://raw.githack.com/zxcty54/content_base/main/$encodedPath",
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
        backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          title: _brandAppBarTitle(),
        ),
        body: _buildSkeletonLoading(),
      );
    }

    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: _brandAppBarTitle(),
        backgroundColor: cardColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: _isDarkMode ? Colors.white : const Color(0xFF334155),
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: -6,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      // 🚪 MODERN ROYAL BLUE DRAWER
      drawer: Drawer(
        width: 320,
        backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
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
                      // 💙 DRAWER HERO HEADER (Deep Slate to Royal Blue)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          MediaQuery.of(context).padding.top + 20,
                          16,
                          20,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E40AF), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const _BrandMark(size: 36),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MockTester',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      Text(
                                        'BPSC • BSSC • Bihar Police',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 49,
                                      height: 49,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
                                      ),
                                      child: Text(
                                        _drawerInitials(userName),
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 1,
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitleText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'ASPIRANT',
                                    style: TextStyle(color: Color(0xFF451A03), fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 10, color: Color(0xFFFDE68A)),
                                      SizedBox(width: 3),
                                      Text('PADHAI MODE ON', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      _drawerSection('EXPLORE'),
                      _drawerTile(
                        icon: Icons.dashboard_customize_rounded,
                        color: const Color(0xFF1D4ED8),
                        title: 'Creator Studio',
                        subtitle: 'Dashboard, quizzes, notes & builder',
                        onTap: () {
                          Navigator.pop(context);
                          _openCreatorStudio();
                        },
                      ),
                      _drawerTile(
                        icon: Icons.dynamic_feed_rounded,
                        color: const Color(0xFF2563EB),
                        title: 'Community Feed',
                        subtitle: 'Doubts, posts aur doston ki help',
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentBottomIndex = 3);
                        },
                      ),
                      _drawerTile(
                        icon: Icons.school_rounded,
                        color: const Color(0xFF059669),
                        title: 'Learn Hub',
                        subtitle: 'Subjects aur chapters padho',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LearnHubScreen()),
                          ).then((_) => _loadRealtimeProgress());
                        },
                      ),
                      _drawerTile(
                        icon: Icons.person_rounded,
                        color: const Color(0xFF0284C7),
                        title: 'My Profile',
                        subtitle: 'Progress, settings aur account',
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentBottomIndex = 4);
                        },
                      ),

                      _drawerSection('ASPIRANT TOOLS'),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.handyman_rounded, size: 19, color: Colors.white),
                            ),
                            title: Text(
                              'Utility Tools',
                              style: TextStyle(
                                color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: Text(
                              'Form bharne wale kaam ke tools',
                              style: TextStyle(
                                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            children: [
                              _drawerTile(
                                indent: true,
                                icon: Icons.photo_size_select_large_rounded,
                                color: const Color(0xFFD97706),
                                title: 'Photo & Sign Resizer',
                                subtitle: 'BPSC • BSSC • Police size ready',
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
                              _drawerTile(
                                indent: true,
                                icon: Icons.picture_as_pdf_rounded,
                                color: const Color(0xFF2563EB),
                                title: 'Doc & ID Card Merger',
                                subtitle: 'Front/back mila kar ek PDF',
                                badge: 'NEW',
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
                      ),

                      _drawerSection('SUPPORT'),
                      _drawerTile(
                        icon: Icons.privacy_tip_rounded,
                        color: const Color(0xFF64748B),
                        title: 'Privacy Policy',
                        subtitle: 'App ke niyam aur jaankari',
                        onTap: () {
                          Navigator.pop(context);
                          _openWebsiteUrl('Privacy Policy', 'https://www.mocktester.online/p/privacy.html');
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Disclaimer: MockTester is an independent educational prep platform and is NOT affiliated with, endorsed by, or representing any government entity (BPSC, SSC, etc.).',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: _isDarkMode ? Colors.white60 : const Color(0xFF92400E),
                            height: 1.35,
                            fontWeight: FontWeight.w600,
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
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  String _drawerInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _drawerSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 7),
      child: Text(
        label,
        style: TextStyle(
          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.25,
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    String? badge,
    Color? badgeColor,
    bool indent = false,
    required VoidCallback onTap,
  }) {
    final titleColor = _isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subColor = _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: EdgeInsets.only(left: indent ? 28 : 12, right: 12, top: 3, bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: _isDarkMode ? Colors.white.withOpacity(0.025) : Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.72)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: titleColor, fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: subColor, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? color).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(color: badgeColor ?? color, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded, size: 18, color: subColor.withOpacity(0.65)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final surface = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final border = _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _bottomNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _bottomNavItem(1, Icons.menu_book_outlined, Icons.menu_book_rounded, 'Revision'),
              _bottomNavItem(2, Icons.assignment_outlined, Icons.assignment_rounded, 'Sectional'),
              _bottomNavItem(3, Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded, 'Community'),
              _bottomNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(int index, IconData icon, IconData selectedIcon, String label) {
    final selected = _currentBottomIndex == index;
    const primary = Color(0xFF2563EB);
    final muted = _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _currentBottomIndex = index);
            if (index == 0) _loadRealtimeProgress();
            if (index == 1) _fetchSubjectMappingLive();
            if (index == 2) _fetchSectionalDataLive();
          },
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 26 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: selected ? primary : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                ),
              ),
              const Spacer(),
              Icon(
                selected ? selectedIcon : icon,
                size: 23,
                color: selected ? primary : muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? primary : muted,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandAppBarTitle() {
    return Row(
      children: [
        const _BrandMark(size: 32),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MockTester',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              'BPSC • BSSC • Bihar Police',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkeletonLoading() {
    final Color base = _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final Color highlight = _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SkeletonBox(height: 132, base: base, highlight: highlight),
        const SizedBox(height: 16),
        for (int i = 0; i < 3; i++) ...[
          _SkeletonBox(height: 96, base: base, highlight: highlight),
          const SizedBox(height: 16),
        ],
      ],
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

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double r = size * 0.30;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.34),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.22),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(r),
              ),
            ),
          ),
          Icon(Icons.insights_rounded, color: Colors.white, size: size * 0.48),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.base,
    required this.highlight,
  });

  final double height;
  final Color base;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
