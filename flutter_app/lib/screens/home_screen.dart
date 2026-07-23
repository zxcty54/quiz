import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/question_model.dart';
import '../services/telegram_tracker.dart';
import 'chapter_select_screen.dart';
import 'sectional_cbt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomIndex = 0;
  bool _isDarkMode = false;
  bool _isHindi = true;
  String _selectedExamPanel = 'bpsc';

  // 📂 Multi-JSON Data Maps
  Map<String, dynamic> _appConfig = {};
  Map<String, dynamic> _homeData = {};
  Map<String, dynamic> _subjectMapping = {};
  Map<String, dynamic> _sectionalData = {};
  bool _isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    TelegramTracker.sendActivityAlert(screenName: "App Opened / Home Screen");
    _loadAllConfigs();
  }

  // 🚀 Parallel Load 4 Clean JSON Files
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
      return Scaffold(appBar: AppBar(title: const Text('MockTester')), body: _buildSkeletonLoading());
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
                Text(_appConfig['maintenance']['message'] ?? 'Under Maintenance', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('MockTester', style: TextStyle(fontWeight: FontWeight.bold)), elevation: 0),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: IndexedStack(
          key: ValueKey<int>(_currentBottomIndex),
          index: _currentBottomIndex,
          children: [
            _buildHomeTab(context),
            _buildRevisionTab(context),
            _buildSectionalTab(context),
            const Center(child: Text('⭐ Bookmarked Questions Area')),
            _buildProfileTab(context),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentBottomIndex = idx);
          List<String> tabs = ['Home Tab', 'Revision Hub', 'Sectional CBT', 'Saved Area', 'Profile Tab'];
          TelegramTracker.sendActivityAlert(screenName: "Switched to ${tabs[idx]}");
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Revision'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Sectional'),
          NavigationDestination(icon: Icon(Icons.star_outline_rounded), selectedIcon: Icon(Icons.star_rounded), label: 'Saved'),
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
        baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
        child: Container(height: 100, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  // 1️⃣ HOME TAB
  Widget _buildHomeTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeroHeader(),
          const SizedBox(height: 16),
          _buildWebHubCard(context),
          const SizedBox(height: 16),
          _buildEligibilityBanner(context),
          const SizedBox(height: 16),
          _buildMiniMocksCard(context),
          const SizedBox(height: 16),
          const TelegramCreatorWidget(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    final featured = _appConfig['featured_mock'] ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)]),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(featured['title'] ?? 'BPSC & BSSC Live Mocks', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(featured['subtitle'] ?? 'Real TCS Simulation', style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11)),
              ],
            ),
          ),
          const Text('🎯', style: TextStyle(fontSize: 32)),
        ],
      ),
    );
  }

  Widget _buildWebHubCard(BuildContext context) {
    final webLinks = List<Map<String, dynamic>>.from(_homeData['web_links'] ?? []);
    if (webLinks.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📚 Free Study Notes & Web Articles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: webLinks.length, separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (ctx, i) {
                final item = webLinks[i];
                return ListTile(
                  dense: true,
                  leading: Text(item['icon'] ?? '📝', style: const TextStyle(fontSize: 18)),
                  title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(item['desc'] ?? ''),
                  onTap: () => _openUrl(context, item['title']!, item['url']!),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilityBanner(BuildContext context) {
    return Card(
      color: const Color(0xFFEFF6FF),
      child: ListTile(
        title: const Text('🎯 Job Eligibility Checker Tool', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Check eligible Bihar Sarkari Jobs by DOB & Stream'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openUrl(context, "Eligibility Checker", "https://www.mocktester.online/p/bihar-job-eligibility-checker.html"),
      ),
    );
  }

  Widget _buildMiniMocksCard(BuildContext context) {
    final miniMocks = List<Map<String, dynamic>>.from(_homeData['mini_mocks'] ?? []);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ Quick Mini Mocks', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: miniMocks.map((t) => ActionChip(
                label: Text(t['title']!),
                onPressed: () => _launchCbtMock(context, t['title']!, t['json']!),
              )).toList(),
            )
          ],
        ),
      ),
    );
  }

  // 2️⃣ REVISION TAB
  Widget _buildRevisionTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('📚 Chapterwise Revision Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _subTile(context, '🔬 General Science', 'Physics • Bio • Chem', Colors.blue, [
          _SubCat('⚡ Physics', Map<String, String>.from(_subjectMapping['phy_mapping'] ?? {})),
          _SubCat('🧬 Biology', Map<String, String>.from(_subjectMapping['bio_mapping'] ?? {})),
          _SubCat('🧪 Chemistry', Map<String, String>.from(_subjectMapping['chem_mapping'] ?? {})),
        ]),
        _subTile(context, '📚 GK & Social Science', 'Polity • History • Geo • Eco', Colors.indigo, [
          _SubCat('📜 Polity', Map<String, String>.from(_subjectMapping['polity_mapping'] ?? {})),
          _SubCat('🏛️ History', Map<String, String>.from(_subjectMapping['history_mapping'] ?? {})),
          _SubCat('🌍 Geography', Map<String, String>.from(_subjectMapping['geo_mapping'] ?? {})),
          _SubCat('📈 Economy', Map<String, String>.from(_subjectMapping['eco_mapping'] ?? {})),
        ]),
        _subTile(context, '📰 Current Affairs', 'Monthly Bulletins', Colors.purple, [
          _SubCat('📰 Current Affairs', Map<String, String>.from(_subjectMapping['current_mapping'] ?? {})),
        ]),
      ],
    );
  }

  Widget _subTile(BuildContext context, String title, String sub, Color color, List<_SubCat> list) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: TextStyle(color: color, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => _openSubNav(context, title, list),
      ),
    );
  }

  // 3️⃣ SECTIONAL TAB (DYNAMICALLY READS FROM sectional_data.json)
  Widget _buildSectionalTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Target Exam Sectional Mocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
            children: [
              _examCard('BPSC PCS', 'STATE PCS', Colors.pink, 'bpsc'),
              _examCard('SSC / NTPC', 'TCS PATTERN', Colors.green, 'ssc'),
              _examCard('BSSC CGL', 'GRADUATE', Colors.purple, 'bssc_cgl'),
              _examCard('BSSC 10+2', 'INTER LEVEL', Colors.blue, 'bssc_inter'),
            ],
          ),
          const SizedBox(height: 20),

          // DYNAMIC SETS GENERATION
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
            Text(bpscInfo['title'] ?? '🏛️ BPSC Core Zone', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: List.generate(count, (i) {
                final setNum = i + 1;
                return ActionChip(
                  label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}'),
                  onPressed: () => _launchCbtMock(context, 'BPSC Set $setNum', '$prefix$setNum.json'),
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
              Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _examCard(String title, String badge, Color color, String key) {
    final bool isSelected = _selectedExamPanel == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedExamPanel = key),
      child: Card(
        color: isSelected ? color.withOpacity(0.12) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // ⚙️ PROFILE TAB
  Widget _buildProfileTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(child: CircleAvatar(radius: 30, child: Icon(Icons.person))),
        SwitchListTile(title: const Text('Bilingual (Hindi / Eng)'), value: _isHindi, onChanged: (v) => setState(() => _isHindi = v)),
        SwitchListTile(title: const Text('Dark Mode'), value: _isDarkMode, onChanged: (v) => setState(() => _isDarkMode = v)),
      ],
    );
  }

  // 🛠️ HELPER FUNCTIONS
  Future<void> _openUrl(BuildContext context, String title, String url) async {
    TelegramTracker.sendActivityAlert(screenName: "Opened Web Link", extraDetails: "$title ($url)");
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _launchCbtMock(BuildContext context, String title, String path) async {
    TelegramTracker.sendActivityAlert(screenName: "Started Test", extraDetails: "$title ($path)");
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

  void _openSubNav(BuildContext context, String title, List<_SubCat> list) {
    TelegramTracker.sendActivityAlert(screenName: "Opened Category", extraDetails: title);
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: list.map((s) => Card(
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

class TelegramCreatorWidget extends StatelessWidget {
  const TelegramCreatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFECFDF5),
      child: ListTile(
        leading: const Text('📸', style: TextStyle(fontSize: 24)),
        title: const Text('Bano MockTester Ke Creator!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: const Text('Telegram par apne Questions ka photo bhej kar judo!', style: TextStyle(fontSize: 11)),
        onTap: () async {
          final uri = Uri.parse("https://t.me/MT_Masterhub_bot");
          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      ),
    );
  }
}

class _SubCat {
  final String title;
  final Map<String, String> mapping;
  _SubCat(this.title, this.mapping);
}
