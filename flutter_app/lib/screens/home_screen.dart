import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import '../services/telegram_tracker.dart';
import 'learn_hub_screen.dart';
import 'profile_screen.dart';
import 'revision_practice_screen.dart';
import 'sectional_cbt_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/revision_tab.dart';
import 'tabs/sectional_tab.dart';

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

  // Unique refresh key to force re-render
  int _sectionalDataVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TelegramTracker.initSession();
    _loadAllConfigs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRealtimeProgress();
      _fetchSectionalDataLive();
      _fetchSubjectMappingLive();
    }
  }

  Future<void> _loadAllConfigs() async {
    await _loadRealtimeProgress();

    // 1️⃣ Home Data, Bulletin & Jobs (100% UNTOUCHED)
    try {
      final String configStr = await rootBundle.loadString('assets/data/app_config.json');
      _appConfig = jsonDecode(configStr);
    } catch (e) {
      debugPrint("Error loading app_config.json: $e");
    }

    try {
      final String homeStr = await rootBundle.loadString('assets/data/home_data.json');
      _homeData = jsonDecode(homeStr);
    } catch (e) {
      debugPrint("Error loading home_data.json: $e");
    }

    // 2️⃣ Revision Mapping (Local Cache/Asset Fallback)
    final prefs = await SharedPreferences.getInstance();
    String? cachedMapping = prefs.getString('cached_subject_mapping_json');
    if (cachedMapping != null) {
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

    // 3️⃣ Sectional Data (Local Cache/Asset Fallback)
    String? cachedSectional = prefs.getString('cached_sectional_data_json');
    if (cachedSectional != null) {
      try {
        _sectionalData = Map<String, dynamic>.from(jsonDecode(cachedSectional));
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

    // 4️⃣ Live Sync on Startup
    _fetchSectionalDataLive();
    _fetchSubjectMappingLive();
  }

  // 🌐 DIRECT UNBLOCKED REALTIME FETCHER (Purges jsDelivr Cache Instantly)
  Future<dynamic> _fetchRobustJson(String relativePath) async {
    String clean = relativePath.startsWith("/") ? relativePath.substring(1) : relativePath;
    final int ts = DateTime.now().millisecondsSinceEpoch;

    // Direct Purge & Fresh CDN Links (Always unblocked, 100% Realtime)
    List<String> urls = [
      "https://purge.jsdelivr.net/gh/zxcty54/quiz@main/$clean", // Instant Cache Clear
      "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/$clean?t=$ts",
      "https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/$clean?nocache=$ts",
      "https://raw.githack.com/zxcty54/quiz/main/$clean",
    ];

    // Pehle purge hit karo
    try {
      http.get(Uri.parse(urls[0])).timeout(const Duration(seconds: 2));
    } catch (_) {}

    // Fir fresh data load karo
    for (int i = 1; i < urls.length; i++) {
      try {
        final res = await http.get(Uri.parse(urls[i])).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          String decoded = utf8.decode(res.bodyBytes);
          return jsonDecode(decoded);
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // 🎯 LIVE SECTIONAL MOCKS SYNC & INSTANT SCREEN UPDATE
  Future<void> _fetchSectionalDataLive() async {
    final data = await _fetchRobustJson("sectional_data.json");
    if (data != null && data is Map && mounted) {
      setState(() {
        _sectionalData = Map<String, dynamic>.from(data);
        _sectionalDataVersion++; // 👈 Forces SectionalTab to redraw immediately
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_sectional_data_json', jsonEncode(data));
      debugPrint("✅ Sectional Data Updated Live: Set count refreshed!");
    }
  }

  // 🎯 LIVE REVISION SUBJECT MAPPING SYNC
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
      appBar: AppBar(
        title: Text('MockTester',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : const Color(0xFF0F172A))),
        backgroundColor: cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.school_rounded, color: Color(0xFF075E54)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LearnHubScreen()))
                  .then((_) => _loadRealtimeProgress());
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentBottomIndex,
        children: [
          // 🏡 Tab 0: Home Tab (News, Bulletin, Jobs - 100% UNTOUCHED)
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
            onNavigateToLearn: () => setState(() => _currentBottomIndex = 3),
          ),

          // 📚 Tab 1: Revision Tab
          RevisionTab(
            subjectMapping: _subjectMapping,
            onLaunchPractice: _launchRevisionPractice,
          ),

          // 🎯 Tab 2: Sectional Tab (Key added to force fresh UI build)
          SectionalTab(
            key: ValueKey('sectional_tab_v$_sectionalDataVersion'),
            sectionalData: _sectionalData,
            isDarkMode: _isDarkMode,
            onLaunchCbtMock: _launchCbtMock,
          ),

          // 🎓 Tab 3: Learn Hub
          const LearnHubScreen(),

          // 👤 Tab 4: Profile
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
          if (idx == 2) _fetchSectionalDataLive(); // 👈 Sectional tab aate hi trigger hoga
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Revision'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Sectional'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Future<void> _openWebsiteUrl(String linkTitle, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _launchRevisionPractice(BuildContext context, String title, String path) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()));

    final data = await _fetchRobustJson(path);
    if (context.mounted) Navigator.pop(context);

    if (data != null && data is List) {
      List<Question> qList = data.map((i) => Question.fromJson(i)).toList();
      if (context.mounted && qList.isNotEmpty) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (ctx) => RevisionPracticeScreen(testTitle: title, questions: qList)));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test questions load nahi ho paye. Internet check karein.')),
        );
      }
    }
  }

  void _launchCbtMock(BuildContext context, String title, String path) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()));

    final data = await _fetchRobustJson(path);
    if (context.mounted) Navigator.pop(context);

    if (data != null && data is List) {
      List<Question> qList = data.map((i) => Question.fromJson(i)).toList();
      if (context.mounted && qList.isNotEmpty) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (ctx) => SectionalCbtScreen(
                    testTitle: title, questions: qList, subFolder: path)));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CBT Mock questions load nahi ho paye. Internet check karein.')),
        );
      }
    }
  }
}
