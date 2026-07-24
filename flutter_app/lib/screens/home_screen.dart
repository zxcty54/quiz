import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/question_model.dart';
import '../services/telegram_tracker.dart';
import '../widgets/home_widgets.dart'; // 🚀 Import Reusable Widgets
import 'chapter_select_screen.dart';
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

  // 📂 Multi-JSON Data
  Map<String, dynamic> _appConfig = {};
  Map<String, dynamic> _homeData = {};
  Map<String, dynamic> _subjectMapping = {};
  Map<String, dynamic> _sectionalData = {};
  bool _isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    // 👁️ Add App Exit Listener
    WidgetsBinding.instance.addObserver(this);
    TelegramTracker.initSession();
    _loadAllConfigs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🚪 SIRF APP CLOSE / MINIMIZE HONE PAR HI TELEGRAM ALERT JAYEGA
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      TelegramTracker.sendOnAppExitAlert();
    }
  }

  // 🚀 Load Configs in Parallel
  Future<void> _loadAllConfigs() async {
    try {
      final results = await Future.wait([
        rootBundle.loadString('assets/data/app_config.json'),
        rootBundle.loadString('assets/data/home_data.json'),
        rootBundle.loadString('assets/data/subject_mapping.json'),
        rootBundle.loadString('assets/data/sectional_data.json'),
      ]);

      if (mounted) {
        setState(() {
          _appConfig = jsonDecode(results[0]);
          _homeData = jsonDecode(results[1]);
          _subjectMapping = jsonDecode(results[2]);
          _sectionalData = jsonDecode(results[3]);
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingConfig = false);
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
              Center(child: Text('⭐ Bookmarked Questions Area', style: TextStyle(color: textColor))),
              _buildProfileTab(context),
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

  // 1️⃣ TAB 1: HOME DASHBOARD
  Widget _buildHomeTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📰 Daily Update Ticker
          if (_appConfig['today_update']?['show'] == true) ...[
            TodayUpdateTickerWidget(updateData: _appConfig['today_update'], onTapUrl: _openWebsiteUrl),
            const SizedBox(height: 16),
          ],

          // 🚀 Hero Banner
          HeroHeaderWidget(featuredData: _appConfig['featured_mock'] ?? {}),
          const SizedBox(height: 16),

          // 🎯 3-BOX STRUCTURED WEB HUB (Free PDFs, Latest Updates, Current Affairs)
          WebHubCardWidget(
            webHubSections: List<Map<String, dynamic>>.from(_homeData['web_hub'] ?? []),
            onTapUrl: _openWebsiteUrl,
          ),

          // 🎯 Job Eligibility Checker Banner
          EligibilityCheckerWidget(isDarkMode: _isDarkMode, onTapUrl: _openWebsiteUrl),
          const SizedBox(height: 16),

          // ⚡ Mini Mocks
          _buildMiniMocksCard(context),
          const SizedBox(height: 16),

          // 📸 Telegram Creator Widget
          const TelegramCreatorWidget(),
        ],
      ),
    );
  }

  Widget _buildMiniMocksCard(BuildContext context) {
    final miniMocks = List<Map<String, dynamic>>.from(_homeData['mini_mocks'] ?? []);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ Quick Mini Mocks (15s Timer)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: miniMocks.map((t) => ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2575FC), foregroundColor: Colors.white),
                onPressed: () => _launchCbtMock(context, t['title']!, t['json']!),
                child: Text(t['title']!, style: const TextStyle(fontSize: 11)),
              )).toList(),
            )
          ],
        ),
      ),
    );
  }

  // 2️⃣ TAB 2: REVISION HUB
  Widget _buildRevisionTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('📚 Chapterwise Revision Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildMainCategoryTile(
          icon: '🔬', title: 'General Science', subtitle: 'Physics • Biology • Chemistry', color: Colors.blue,
          onTap: () => _openSubCategory(context, 'General Science', [
            _SubCategory('⚡ Physics', Map<String, String>.from(_subjectMapping['phy_mapping'] ?? {})),
            _SubCategory('🧬 Biology', Map<String, String>.from(_subjectMapping['bio_mapping'] ?? {})),
            _SubCategory('🧪 Chemistry', Map<String, String>.from(_subjectMapping['chem_mapping'] ?? {})),
          ]),
        ),
        const SizedBox(height: 10),
        _buildMainCategoryTile(
          icon: '📚', title: 'GK & Social Science', subtitle: 'Polity • History • Geography • Economy', color: Colors.indigo,
          onTap: () => _openSubCategory(context, 'GK & Social Science', [
            _SubCategory('📜 Indian Polity', Map<String, String>.from(_subjectMapping['polity_mapping'] ?? {})),
            _SubCategory('🏛️ History', Map<String, String>.from(_subjectMapping['history_mapping'] ?? {})),
            _SubCategory('🌍 Geography', Map<String, String>.from(_subjectMapping['geo_mapping'] ?? {})),
            _SubCategory('📈 Economy', Map<String, String>.from(_subjectMapping['eco_mapping'] ?? {})),
          ]),
        ),
        const SizedBox(height: 10),
        _buildMainCategoryTile(
          icon: '📰', title: 'Current Affairs 2026', subtitle: 'Monthly Bulletins & Bihar Special News', color: Colors.purple,
          onTap: () => _openSubCategory(context, 'Current Affairs 2026', [
            _SubCategory('📰 Monthly Sets & Bihar Special', Map<String, String>.from(_subjectMapping['current_mapping'] ?? {})),
          ]),
        ),
      ],
    );
  }

  // 3️⃣ TAB 3: SECTIONAL MOCK TAB
  Widget _buildSectionalTab(BuildContext context) {
    return SingleChildScrollView(
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

          if (_selectedExamPanel == 'bpsc') _buildBpscDynamicPanel(context),
          if (_selectedExamPanel != 'bpsc') _buildGenericSetsPanel(context, _selectedExamPanel),
        ],
      ),
    );
  }

  Widget _buildBpscDynamicPanel(BuildContext context) {
    final bpscInfo = _sectionalData['bpsc'] ?? {};
    int count = bpscInfo['total_sets'] ?? 28;
    String prefix = bpscInfo['path_prefix'] ?? 'bpsc/science/Modern History/set';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bpscInfo['title'] ?? '🏛️ BPSC Core Zone', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: List.generate(count, (i) {
                final setNum = i + 1;
                return ActionChip(
                  label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}'),
                  onPressed: () => _launchCbtMock(context, 'BPSC Modern History Set $setNum', '$prefix$setNum.json'),
                );
              }),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGenericSetsPanel(BuildContext context, String panelKey) {
    final List list = _sectionalData[panelKey] ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: list.map((item) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: List.generate(item['sets'] ?? 5, (i) => ActionChip(
                  label: Text('Set 0${i + 1}'),
                  onPressed: () => _launchCbtMock(context, "${item['title']} Set ${i + 1}", "${item['folder']}/set${i + 1}.json"),
                )),
              ),
              const Divider(),
            ],
          )).toList(),
        ),
      ),
    );
  }

  // ⚙️ TAB 5: PROFILE & SUPPORT
  Widget _buildProfileTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(child: CircleAvatar(radius: 35, child: Icon(Icons.person, size: 40))),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Bilingual (Hindi / Eng)'),
          value: _isHindi,
          onChanged: (v) => setState(() => _isHindi = v),
        ),
        SwitchListTile(
          title: const Text('Dark Mode (Night Theme)'),
          value: _isDarkMode,
          onChanged: (v) => setState(() => _isDarkMode = v),
        ),
        const Divider(),
        const SizedBox(height: 8),

        _buildLaunchRoadmapCard(),
        const SizedBox(height: 12),
        _buildTrustCard(),
        const SizedBox(height: 12),
        _buildStudentSupportCard(context),
      ],
    );
  }

  Widget _buildLaunchRoadmapCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('📅 Launch Roadmap & Live Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 8),
            Text('🔥 Coming Tomorrow: BSSC Inter Level Top 100 Qs', style: TextStyle(fontSize: 12, color: Color(0xFFFF4757), fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('✅ Just Added: Current Affairs Bulletin', style: TextStyle(fontSize: 12, color: Color(0xFF059669))),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('🎯 THE MOCKTESTER ADVANTAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2575FC))),
            SizedBox(height: 4),
            Text('Why Bihar Aspirants Trust MockTester?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 6),
            Text('• 2K+ Active Aspirants • 80%+ Syllabus Match Rate • 100% Free Practice Mocks', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentSupportCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFF4757), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤝 Student Initiative (100% Free)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFFF4757))),
            const SizedBox(height: 4),
            const Text('Help keep us free for rural students by contributing ₹10.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'niftyfifty@upi'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ UPI ID (niftyfifty@upi) copied!')));
                },
                icon: const Text('❤️'),
                label: const Text('Support Us (₹10 Contribute)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🛠️ HELPER FUNCTIONS
  Future<void> _openWebsiteUrl(String linkTitle, String url) async {
    TelegramTracker.logActivity("Opened Web Tool: $linkTitle");
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch website: $e')));
    }
  }

  void _launchCbtMock(BuildContext context, String title, String path) async {
    TelegramTracker.logActivity("Started Mock Test: $title");
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final res = await http.get(Uri.parse("https://raw.githubusercontent.com/zxcty54/quiz/main/$path"));
      if (context.mounted) Navigator.pop(context);
      if (res.statusCode == 200) {
        List body = jsonDecode(res.body);
        List<Question> qList = body.map((i) => Question.fromJson(i)).toList();
        if (context.mounted && qList.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => SectionalCbtScreen(testTitle: title, questions: qList, subFolder: path)));
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
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

  Widget _buildMainCategoryTile({required String icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return ListTile(
      tileColor: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Text(icon, style: const TextStyle(fontSize: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap,
    );
  }

  void _openSubCategory(BuildContext context, String title, List<_SubCategory> subs) {
    TelegramTracker.logActivity("Opened Category: $title");
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: subs.map((s) => Card(
          child: ListTile(
            title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => ChapterSelectScreen(categoryTitle: s.title, chapterMapping: s.mapping))),
          ),
        )).toList(),
      ),
    )));
  }
}

class _SubCategory {
  final String title;
  final Map<String, String> mapping;
  _SubCategory(this.title, this.mapping);
}
