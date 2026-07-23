import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
  bool _isHindi = true;
  String _selectedExamPanel = 'bpsc';

  Map<String, dynamic> _configData = {};
  bool _isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    TelegramTracker.sendActivityAlert(screenName: "App Opened / Home Screen");
    _loadHomeConfig();
  }

  // 📂 GitHub Raw Link Se Dynamic JSON Fetch Engine
  Future<void> _loadHomeConfig() async {
    try {
      final String localData = await rootBundle.loadString('assets/data/home_config.json');
      setState(() {
        _configData = jsonDecode(localData);
        _isLoadingConfig = false;
      });
    } catch (e) {
      setState(() => _isLoadingConfig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfig) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('MockTester', style: TextStyle(fontWeight: FontWeight.bold))),
      body: IndexedStack(
        index: _currentBottomIndex,
        children: [
          _buildHomeTab(context),
          _buildRevisionTab(context),
          _buildSectionalTab(context),
          const Center(child: Text('⭐ Bookmarked Questions Area')),
          _buildProfileTab(context),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentBottomIndex = idx);
          TelegramTracker.sendActivityAlert(screenName: "Switched Tab #$idx");
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Revision'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Sectional'),
          NavigationDestination(icon: Icon(Icons.star_outline_rounded), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  // 1️⃣ TAB 1: HOME (DYNAMICALLY BUILT FROM JSON)
  Widget _buildHomeTab(BuildContext context) {
    final webLinks = List<Map<String, dynamic>>.from(_configData['web_links'] ?? []);
    final miniMocks = List<Map<String, dynamic>>.from(_configData['mini_mocks'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            height: 100, width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔴 2026 Live Sectional Mocks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Real TCS CBT Exam Simulation • 9500+ Qs', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 🌐 Web Hub Cards (From JSON)
          if (webLinks.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: webLinks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.1),
              itemBuilder: (ctx, i) => InkWell(
                onTap: () => _openUrl(webLinks[i]['title'], webLinks[i]['url']),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Color(int.parse(webLinks[i]['color'])).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Text(webLinks[i]['icon'], style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(webLinks[i]['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ⚡ Mini Mocks (From JSON)
          if (miniMocks.isNotEmpty) ...[
            const Text('⚡ Quick Mini Mocks', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: miniMocks.map((m) => ElevatedButton(
                onPressed: () => _launchCbtMock(context, m['title'], m['json']),
                child: Text(m['title'], style: const TextStyle(fontSize: 11)),
              )).toList(),
            )
          ]
        ],
      ),
    );
  }

  // 2️⃣ TAB 2: REVISION HUB
  Widget _buildRevisionTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('🔬 General Science', style: TextStyle(fontWeight: FontWeight.bold)),
          onTap: () => _openSubCategory(context, 'General Science', [
            _SubCategory('⚡ Physics', Map<String, String>.from(_configData['phy_mapping'] ?? {})),
            _SubCategory('🧬 Biology', Map<String, String>.from(_configData['bio_mapping'] ?? {})),
            _SubCategory('🧪 Chemistry', Map<String, String>.from(_configData['chem_mapping'] ?? {})),
          ]),
        ),
        ListTile(
          title: const Text('📚 GK & Social Science', style: TextStyle(fontWeight: FontWeight.bold)),
          onTap: () => _openSubCategory(context, 'GK & Social Science', [
            _SubCategory('📜 Polity', Map<String, String>.from(_configData['polity_mapping'] ?? {})),
            _SubCategory('🏛️ History', Map<String, String>.from(_configData['history_mapping'] ?? {})),
            _SubCategory('🌍 Geography', Map<String, String>.from(_configData['geo_mapping'] ?? {})),
          ]),
        ),
      ],
    );
  }

  Widget _buildSectionalTab(BuildContext context) => const Center(child: Text('📝 Sectional Mocks Panel'));
  Widget _buildProfileTab(BuildContext context) => const Center(child: Text('⚙️ Profile Settings'));

  void _openUrl(String title, String url) async {
    TelegramTracker.sendActivityAlert(screenName: "Clicked Link", extraDetails: title);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _launchCbtMock(BuildContext context, String title, String path) async {
    TelegramTracker.sendActivityAlert(screenName: "Started Mock Test", extraDetails: title);
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

  void _openSubCategory(BuildContext context, String title, List<_SubCategory> subs) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: subs.map((s) => Card(
          child: ListTile(
            title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
