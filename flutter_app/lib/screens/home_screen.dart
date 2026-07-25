import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import '../services/telegram_tracker.dart';
import '../widgets/home_widgets.dart';
import 'profile_screen.dart';
import 'revision_practice_screen.dart';
import 'saved_questions_screen.dart';
import 'sectional_cbt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentBottomIndex = 0;
  bool _isDarkMode = false;
  bool _isHindi = true;
  String _selectedExamPanel = 'bpsc';

  // 📂 Direct Dynamic JSON Data Storage
  Map<String, dynamic> _appConfig = {};
  Map<String, dynamic> _homeData = {};
  Map<String, dynamic> _subjectMapping = {};
  Map<String, dynamic> _sectionalData = {};

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      TelegramTracker.sendOnAppExitAlert();
    }
  }

  // 📖 Pure External JSON Asset Loader with Pull-to-Refresh return
  Future<void> _loadAllConfigs() async {
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

    try {
      final String subjectStr = await rootBundle.loadString('assets/data/subject_mapping.json');
      _subjectMapping = jsonDecode(subjectStr);
    } catch (e) {
      debugPrint("Error loading subject_mapping.json: $e");
    }

    try {
      final String sectionalStr = await rootBundle.loadString('assets/data/sectional_data.json');
      _sectionalData = jsonDecode(sectionalStr);
    } catch (e) {
      debugPrint("Error loading sectional_data.json: $e");
    }

    if (mounted) {
      setState(() {
        _isLoadingConfig = false;
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

    if (_appConfig['maintenance']?['enabled'] == true) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🛠️', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 16),
                Text(
                  _appConfig['maintenance']['message'] ?? 'Under Maintenance',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bgColor = _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF0F172A);

    return Theme(
      data: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bgColor,
        cardColor: cardColor,
        useMaterial3: true,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('MockTester', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          backgroundColor: cardColor,
          elevation: 0,
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: IndexedStack(
            key: ValueKey<int>(_currentBottomIndex),
            index: _currentBottomIndex,
            children: [
              _buildHomeTab(context),
              _buildRevisionTab(context),
              _buildSectionalTab(context),
              
              // ⭐ TAB 4: REAL-TIME SAVED / BOOKMARKED QUESTIONS SCREEN
              const SavedQuestionsScreen(),

              // 👤 TAB 5: CLEAN EXTERNAL PROFILE SCREEN
              ProfileScreen(
                isHindi: _isHindi,
                isDarkMode: _isDarkMode,
                onHindiChanged: (v) => setState(() => _isHindi = v),
                onDarkModeChanged: (v) => setState(() => _isDarkMode = v),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentBottomIndex,
          onDestinationSelected: (idx) {
            setState(() => _currentBottomIndex = idx);
            List<String> tabs = ['Home Tab', 'Revision Hub', 'Sectional CBT', 'Saved Area', 'Profile Tab'];
            TelegramTracker.logActivity("Switched to ${tabs[idx]}");
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Revision'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Sectional'),
            NavigationDestination(icon: Icon(Icons.star_outline_rounded), selectedIcon: Icon(Icons.star_rounded), label: 'Saved'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // 1️⃣ TAB 1: HOME TAB (WITH PULL-TO-REFRESH)
  Widget _buildHomeTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAllConfigs,
      color: const Color(0xFF2563EB),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_appConfig['today_update']?['show'] == true) ...[
              TodayUpdateTickerWidget(updateData: _appConfig['today_update'], onTapUrl: _openWebsiteUrl),
              const SizedBox(height: 16),
            ],
            HeroHeaderWidget(featuredData: _appConfig['featured_mock'] ?? {}),
            const SizedBox(height: 16),
            WebHubCardWidget(
              webHubSections: (_homeData['web_hub'] as List?) ?? [],
              onTapUrl: _openWebsiteUrl,
            ),
            EligibilityCheckerWidget(isDarkMode: _isDarkMode, onTapUrl: _openWebsiteUrl),
            const SizedBox(height: 16),
            _buildLaunchRoadmapCard(),
            const SizedBox(height: 16),
            const TelegramCreatorWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchRoadmapCard() {
    final List roadmapList = _appConfig['launch_roadmap'] ?? [
      {"text": "🔥 Coming Tomorrow: BSSC Inter Level Top 100 Qs", "color": "0xFFFF4757"},
      {"text": "✅ Just Added: Current Affairs Bulletin", "color": "0xFF059669"}
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📅 Launch Roadmap & Live Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...roadmapList.map((item) {
              final String text = item['text'] ?? '';
              final Color color = Color(int.parse(item['color'] ?? '0xFF2563EB'));
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 2️⃣ TAB 2: REVISION HUB
  Widget _buildRevisionTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAllConfigs,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('📚 Chapterwise Revision Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Subject par click karein aur direct chapter button dabakar revision shuru karein', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 14),

          _buildExpansionSubjectCategory(
            title: 'General Science',
            icon: '🔬',
            color: const Color(0xFF2563EB),
            subSections: [
              {'title': '⚡ Physics', 'key': 'phy_mapping'},
              {'title': '🧬 Biology', 'key': 'bio_mapping'},
              {'title': '🧪 Chemistry', 'key': 'chem_mapping'},
            ],
          ),
          const SizedBox(height: 12),

          _buildExpansionSubjectCategory(
            title: 'GK & Social Science',
            icon: '📚',
            color: const Color(0xFF4F46E5),
            subSections: [
              {'title': '📜 Indian Polity', 'key': 'polity_mapping'},
              {'title': '🏛️ History', 'key': 'history_mapping'},
              {'title': '🌍 Geography', 'key': 'geo_mapping'},
              {'title': '📈 Economy', 'key': 'eco_mapping'},
            ],
          ),
          const SizedBox(height: 12),

          _buildExpansionSubjectCategory(
            title: 'Current Affairs 2026',
            icon: '📰',
            color: const Color(0xFF7C3AED),
            subSections: [
              {'title': '📰 Monthly Sets & Bihar Special', 'key': 'current_mapping'},
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionSubjectCategory({
    required String title,
    required String icon,
    required Color color,
    required List<Map<String, dynamic>> subSections,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Text(icon, style: const TextStyle(fontSize: 22)),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: subSections.map((section) {
            final String subTitle = section['title'];
            final String mapKey = section['key'];

            Map<String, dynamic> rawChapters = {};
            if (_subjectMapping.containsKey(mapKey) && _subjectMapping[mapKey] is Map) {
              rawChapters = Map<String, dynamic>.from(_subjectMapping[mapKey]);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Text(subTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                rawChapters.isEmpty
                    ? const Text("No chapters mapped yet.", style: TextStyle(fontSize: 11, color: Colors.grey))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: rawChapters.entries.map((entry) {
                          String path = entry.value.toString();
                          return ActionChip(
                            elevation: 1,
                            backgroundColor: color.withOpacity(0.08),
                            side: BorderSide(color: color.withOpacity(0.3)),
                            label: Text(
                              "📖 ${entry.key}",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                            ),
                            onPressed: () {
                              _launchRevisionPractice(context, entry.key, path);
                            },
                          );
                        }).toList(),
                      ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // 3️⃣ TAB 3: SECTIONAL MOCK
  Widget _buildSectionalTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAllConfigs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎯 Target Exam Sectional Mocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('अपनी परीक्षा चुनें और रियल TCS CBT पैटर्न पर प्रैक्टिस शुरू करें', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
              children: [
                _examSelectorCard('BPSC PCS', 'STATE PCS', const Color(0xFF9D174D), 'bpsc'),
                _examSelectorCard('SSC / NTPC', 'TCS PATTERN', const Color(0xFF166534), 'ssc'),
                _examSelectorCard('BSSC CGL', 'GRADUATE', const Color(0xFF6B21A8), 'bssc_cgl'),
                _examSelectorCard('BSSC 10+2', 'INTER LEVEL', const Color(0xFF075985), 'bssc_inter'),
              ],
            ),
            const SizedBox(height: 20),

            _buildDynamicSectionalSetsPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicSectionalSetsPanel(BuildContext context) {
    final dynamic panelData = _sectionalData[_selectedExamPanel];

    if (panelData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text("⚠️ Sets loading... Please check connection.", style: TextStyle(fontSize: 12, color: Colors.grey))),
        ),
      );
    }

    if (panelData is Map) {
      int count = panelData['total_sets'] ?? 10;
      String prefix = panelData['path_prefix'] ?? 'bpsc/science/Modern History/set';
      String title = panelData['title'] ?? '🏛️ Exam Special Zone';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(count, (i) {
                  final setNum = i + 1;
                  return ActionChip(
                    backgroundColor: const Color(0xFF9D174D).withOpacity(0.08),
                    side: const BorderSide(color: Color(0xFF9D174D)),
                    label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
                    onPressed: () => _launchCbtMock(context, '$title Set $setNum', '$prefix$setNum.json'),
                  );
                }),
              )
            ],
          ),
        ),
      );
    }

    if (panelData is List) {
      return Column(
        children: panelData.map((item) {
          String itemTitle = item['title'] ?? 'Sectional Mock';
          int totalSets = item['sets'] ?? 5;
          String folder = item['folder'] ?? 'bssc/science';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: List.generate(totalSets, (i) {
                      final setNum = i + 1;
                      return ActionChip(
                        backgroundColor: const Color(0xFF2563EB).withOpacity(0.08),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        label: Text('Set 0$setNum', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        onPressed: () => _launchCbtMock(context, "$itemTitle Set $setNum", "$folder/set$setNum.json"),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return const SizedBox.shrink();
  }

  // HELPER LAUNCHER FUNCTIONS
  Future<void> _openWebsiteUrl(String linkTitle, String url) async {
    TelegramTracker.logActivity("Opened Web Tool: $linkTitle");
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch website: $e')));
    }
  }

  // 1️⃣ REVISION HUB PRACTICE LAUNCHER (FIXED WITH JSDELIVR CDN & ENCODING)
  void _launchRevisionPractice(BuildContext context, String title, String path) async {
    TelegramTracker.logActivity("Started Revision Practice: $title");
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    
    String finalUrl = path.startsWith("http") 
        ? path 
        : Uri.encodeFull("https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/$path");
    
    try {
      final res = await http.get(Uri.parse(finalUrl));
      if (context.mounted) Navigator.pop(context);
      if (res.statusCode == 200) {
        List body = jsonDecode(res.body);
        List<Question> qList = body.map((i) => Question.fromJson(i)).toList();
        if (context.mounted && qList.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => RevisionPracticeScreen(testTitle: title, questions: qList),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ No questions found in this set.')));
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Failed to load set (Error ${res.statusCode}). Please check GitHub path.')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Network error: $e')));
      }
    }
  }

  // 2️⃣ SECTIONAL CBT MOCK LAUNCHER (FIXED WITH JSDELIVR CDN & ENCODING)
  void _launchCbtMock(BuildContext context, String title, String path) async {
    TelegramTracker.logActivity("Started Sectional CBT Mock: $title");
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    
    String finalUrl = path.startsWith("http") 
        ? path 
        : Uri.encodeFull("https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/$path");
    
    try {
      final res = await http.get(Uri.parse(finalUrl));
      if (context.mounted) Navigator.pop(context);
      if (res.statusCode == 200) {
        List body = jsonDecode(res.body);
        List<Question> qList = body.map((i) => Question.fromJson(i)).toList();
        if (context.mounted && qList.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => SectionalCbtScreen(testTitle: title, questions: qList, subFolder: path),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ No questions found in this set.')));
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Failed to load set (Error ${res.statusCode}). Please check GitHub path.')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Network error: $e')));
      }
    }
  }

  Widget _examSelectorCard(String title, String badge, Color color, String panelKey) {
    final bool isSelected = _selectedExamPanel == panelKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedExamPanel = panelKey),
      child: Card(
        color: isSelected ? color.withOpacity(0.12) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
