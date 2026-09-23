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

// 🛠️ Aspirant Tools Imports
import '../widgets/exam_photo_resizer_screen.dart';

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

  // 🔗 WhatsApp Deep Link Listener
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TelegramTracker.initSession();
    _loadAllConfigs();
    _initChallengeDeepLinks();

    // 🚀 Silent Background Sync
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
        rawBody = rawBody.replaceAll('```json', '').replaceAll('```', '').trim();
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
          rawBody = rawBody.replaceAll('```json', '').replaceAll('
