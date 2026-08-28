import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import '../services/ai_explainer_service.dart';
import '../services/telegram_tracker.dart';
import '../services/knowledge_base_service.dart';
import 'ai_chat_screen.dart';
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

  // 🤖 OFFLINE MODEL DOWNLOADER & AUTO-DETECT STATE
  bool _isModelDownloaded = false;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = "One-Time Offline Setup (~1.7 GB)";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TelegramTracker.initSession();
    _loadAllConfigs();
    _checkLocalModelStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAutomaticDbCheck();
    });
  }

  // 🔍 1. Smart Local Storage & Downloads Folder Auto-Detect
  Future<void> _checkLocalModelStatus() async {
    final devModelFile = File('/storage/emulated/0/Download/gemma-2-2b-it-Q4_K_M.gguf');
    final appDocDir = await getApplicationDocumentsDirectory();
    final internalModel = File('${appDocDir.path}/gemma-2-2b-it-Q4_K_M.gguf');

    final bool exists = await devModelFile.exists() || await internalModel.exists();
    if (mounted) {
      setState(() {
        _isModelDownloaded = exists;
        if (exists) {
          _downloadStatusText = "✅ On-Device Model Active (1.7 GB)";
        }
      });
    }
  }

  // 📥 2. In-App Download Fallback (Agar kisi device me pehle se downloaded na ho)
  Future<void> _startModelDownload() async {
    setState(() {
      _isDownloadingModel = true;
      _downloadProgress = 0.0;
      _downloadStatusText = "Downloading Offline AI Engine...";
    });

    const String modelUrl = "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf";

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${appDocDir.path}/gemma-2-2b-it-Q4_K_M.gguf');

      final request = http.Request('GET', Uri.parse(modelUrl));
      final response = await http.Client().send(request);

      final totalBytes = response.contentLength ?? (1710 * 1024 * 1024);
      int receivedBytes = 0;

      final sink = targetFile.openWrite();

      await response.stream.listen(
        (List<int> chunk) {
          receivedBytes += chunk.length;
          sink.add(chunk);

          final progress = receivedBytes / totalBytes;
          if (mounted) {
            setState(() {
              _downloadProgress = progress.clamp(0.0, 1.0);
              _downloadStatusText = "${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(totalBytes / (1024 * 1024)).toStringAsFixed(0)} MB (${(_downloadProgress * 100).toStringAsFixed(0)}%)";
            });
          }
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          if (mounted) {
            setState(() {
              _isDownloadingModel = false;
              _isModelDownloaded = true;
              _downloadStatusText = "✅ On-Device Model Active (1.7 GB)";
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🎉 Offline AI Model 100% Integrated!"),
                backgroundColor: Color(0xFF16A34A),
              ),
            );
          }
        },
        onError: (e) {
          sink.close();
          if (mounted) {
            setState(() {
              _isDownloadingModel = false;
              _downloadStatusText = "Download Failed. Tap to Retry";
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingModel = false;
          _downloadStatusText = "Error: $e";
        });
      }
    }
  }

  Future<void> _runAutomaticDbCheck() async {
    try {
      final stopwatch = Stopwatch()..start();
      final chunks = await KnowledgeBaseService.instance.searchRelevantChunks("Mitochondria", limit: 1);
      stopwatch.stop();

      if (!mounted) return;

      if (chunks.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Database Active! Loaded in ${stopwatch.elapsedMilliseconds}ms"),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {}
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
      _fetchLiveAppConfig();
      _fetchSectionalDataLive();
      _fetchSubjectMappingLive();
      _checkLocalModelStatus();
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

    final String apiUrl = "https://api.github.com/repos/zxcty54/quiz/contents/$encodedPath?ref=main&t=$ts";
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
      "https://raw.githack.com/zxcty54/quiz/main/$encodedPath",
      "https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/$encodedPath?t=$ts",
      "https://cdn.statically.io/gh/zxcty54/quiz/main/$encodedPath",
      "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/$encodedPath?t=$ts",
      "https://raw.githubusercontent.com/zxcty54/quiz/main/$encodedPath?t=$ts",
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
          rawBody = rawBody.replaceAll('```json', '').replaceAll('```', '').trim();
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

  // 🎨 OFFLINE AI BANNER (WITH AUTO-DETECT)
  Widget _buildAiModelDownloadBanner() {
    final isDark = _isDarkMode;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isModelDownloaded ? Colors.green.withOpacity(0.4) : const Color(0xFF2563EB).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isModelDownloaded ? Colors.green.withOpacity(0.12) : const Color(0xFF2563EB).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isModelDownloaded ? Icons.offline_bolt_rounded : Icons.psychology_rounded,
                  color: _isModelDownloaded ? Colors.green : const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isModelDownloaded ? "Offline AI Tutor Ready" : "Enable 100% Offline AI",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      _downloadStatusText,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isModelDownloaded && !_isDownloadingModel)
                ElevatedButton.icon(
                  onPressed: _startModelDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text("Download", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else if (_isModelDownloaded)
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AiChatScreen(isDarkMode: _isDarkMode)),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.green),
                  label: const Text("Open Chat", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
          if (_isDownloadingModel) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                minHeight: 6,
                backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          ],
        ],
      ),
    );
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
      body: Column(
        children: [
          // 🚀 1. OFFLINE AI BANNER
          _buildAiModelDownloadBanner(),

          // 📱 2. CORE TABS
          Expanded(
            child: IndexedStack(
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
          ),
        ],
      ),

      // 🤖 FLOATING ACTION BUTTON
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.38),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AiChatScreen(isDarkMode: _isDarkMode),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          label: const Text(
            "Ask AI Doubt",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
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
