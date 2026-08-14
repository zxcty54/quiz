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

    // 1️⃣ Offline Assets Load (Instant UI Render)
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

    final prefs = await SharedPreferences.getInstance();

    // 💾 Revision persistent storage check
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

    // 💾 Sectional persistent storage check (Permanent Disk Lock)
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

    // 2️⃣ Live Cloud Sync (Background Fresh Update)
    _fetchSectionalDataLive();
    _fetchSubjectMappingLive();
  }

  // 🌐 DIRECT REALTIME FAST FETCHER (Races CDNs with cache-busting timestamp)
  Future<dynamic> _fetchRobustJson(String relativePath) async {
    String clean = relativePath.startsWith("/") ? relativePath.substring(1) : relativePath;
    final int ts = DateTime.now().millisecondsSinceEpoch;
    String encodedPath = Uri.encodeFull(clean);

    List<String> mirrorUrls = clean.startsWith("http")
        ? [clean]
        : [
            "https://raw.githubusercontent.com/zxcty54/quiz/main/$encodedPath?t=$ts",
            "https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/$encodedPath?t=$ts",
            "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/$encodedPath?t=$ts",
            "https://cdn.statically.io/gh/zxcty54/quiz/main/$encodedPath",
          ];

    // Race all CDN mirrors for blazing speed
    List<Future<dynamic>> requests = mirrorUrls.map((url) async {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          String decoded = utf8.decode(res.bodyBytes);
          return jsonDecode(decoded);
        }
      } catch (_) {}
      throw Exception("Mirror failed");
    }).toList();

    try {
      final result = await Future.any(requests);
      if (result != null) return result;
    } catch (_) {
      for (String url in mirrorUrls) {
        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) {
            return jsonDecode(utf8.decode(res.bodyBytes));
          }
        } catch (_) {}
      }
    }
    return null;
  }

  // 🎯 LIVE SECTIONAL SYNC + AUTO PERSISTENT SAVE
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

  // 🎯 LIVE REVISION SYNC + AUTO PERSISTENT SAVE
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
          // 🏡 Tab 0: Home Tab
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
            key: ValueKey('rev_${_subjectMapping.keys.length}'),
            subjectMapping: _subjectMapping,
            onLaunchPractice: _launchRevisionPractice,
          ),

          // 🎯 Tab 2: Sectional Tab (Persistent Sync Key)
          SectionalTab(
            key: ValueKey('sec_${_sectionalData.keys.join('_')}'),
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
          if (idx == 2) _fetchSectionalDataLive();
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

  // 🎯 UNIVERSAL CBT MOCK LAUNCHER
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

    // Build exhaustive list of candidate paths
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
              qList.add(Question.fromJson(Map<String, dynamic>.from(item)));
            }
          }

          if (context.mounted && qList.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => RevisionPracticeScreen(testTitle: title, questions: qList),
              ),
            );
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
