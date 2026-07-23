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
  bool _isDarkMode = false;
  bool _isHindi = true;
  String _selectedExamPanel = 'bpsc';

  Map<String, dynamic> _configData = {};
  bool _isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    // 📲 Telegram Alert
    TelegramTracker.sendActivityAlert(screenName: "App Opened / Home Screen");
    _loadHomeConfig();
  }

  // 📂 Assets Se home_config.json Read Karein
  Future<void> _loadHomeConfig() async {
    try {
      final String localData = await rootBundle.loadString('assets/data/home_config.json');
      if (mounted) {
        setState(() {
          _configData = jsonDecode(localData);
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MockTester', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: IndexedStack(
        index: _currentBottomIndex,
        children: [
          _buildHomeTab(context),       // 🏠 Tab 1: Home
          _buildRevisionTab(context),   // 📚 Tab 2: Revision Hub
          _buildSectionalTab(context),  // 📝 Tab 3: Sectional CBT Panel
          _buildSavedTab(),            // ⭐ Tab 4: Saved Area
          _buildProfileTab(context),    // ⚙️ Tab 5: Profile & Support
        ],
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

  // 1️⃣ TAB 1: HOME DASHBOARD
  Widget _buildHomeTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔴 2026 Live Sectional Mocks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Real TCS CBT Exam Simulation • 9500+ Qs', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 🌐 Website Quick Access Portal
          _buildWebsiteQuickHubCard(context),
          const SizedBox(height: 16),

          // 🎯 SPOTLIGHT JOB ELIGIBILITY CHECKER BANNER
          _buildEligibilityCheckerBanner(context),
          const SizedBox(height: 16),

          // ⚡ Quick Mini Mocks Card
          _buildMiniMocksCard(context),
          const SizedBox(height: 16),

          // 🩺 BTSC Banner
          _buildBtscBanner(context),
          const SizedBox(height: 16),

          // 📸 Telegram Question Photo Form Widget
          const TelegramCreatorWidget(),
        ],
      ),
    );
  }

  // 🌐 WEBSITE QUICK ACCESS PORTAL WIDGET
  Widget _buildWebsiteQuickHubCard(BuildContext context) {
    final webLinks = List<Map<String, dynamic>>.from(_configData['web_links'] ?? []);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🌐 MockTester Web Hub', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                  child: const Text('OPEN IN CHROME 🌐', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                )
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: webLinks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.1,
              ),
              itemBuilder: (context, index) {
                final item = webLinks[index];
                final Color themeColor = Color(int.parse(item['color'] ?? '0xFF2563EB'));

                return InkWell(
                  onTap: () => _openWebsiteUrl(context, item['title']!, item['url']!),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.08),
                      border: Border.all(color: themeColor.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(item['icon'] ?? '🌐', style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: themeColor), overflow: TextOverflow.ellipsis),
                              Text(item['desc'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.grey), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 SPOTLIGHT JOB ELIGIBILITY CHECKER BANNER
  Widget _buildEligibilityCheckerBanner(BuildContext context) {
    const String eligibilityToolUrl = "https://www.mocktester.online/p/bihar-job-eligibility-checker.html";

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('🎯', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Job Eligibility Checker', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(20)),
                  child: const Text('ONLINE TOOL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Apni DOB, Stream aur Height daal kar check karein aap Bihar ki kis-kis Sarkari Naukri ke liye eligible hain!',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.3),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                _buildSmallBadge("✔ BPSC / BSSC Posts"),
                _buildSmallBadge("✔ Police & Height Check"),
                _buildSmallBadge("✔ TRE Teacher Course"),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openWebsiteUrl(
                  context,
                  "Job Eligibility Checker",
                  eligibilityToolUrl,
                ),
                icon: const Text('🚀', style: TextStyle(fontSize: 12)),
                label: const Text('Check My Eligibility On Website', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
    );
  }

  // ⚡ QUICK MINI MOCKS CARD
  Widget _buildMiniMocksCard(BuildContext context) {
    final miniMocks = List<Map<String, dynamic>>.from(_configData['mini_mocks'] ?? []);

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

  // 🩺 BTSC BANNER WIDGET
  Widget _buildBtscBanner(BuildContext context) {
    return Card(
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFBBF7D0))),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.medical_services_rounded, color: Color(0xFF16A34A))),
        title: const Text('🩺 BTSC ANM/GNM & PMM Mocks', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 14)),
        subtitle: const Text('11th-12th NCERT Biology & Technical Mocks', style: TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF16A34A)),
        onTap: () => setState(() => _currentBottomIndex = 1),
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
          icon: '🔬',
          title: 'General Science',
          subtitle: 'Physics • Biology • Chemistry',
          color: Colors.blue,
          onTap: () => _openSubCategory(context, 'General Science', [
            _SubCategory('⚡ Physics', Map<String, String>.from(_configData['phy_mapping'] ?? {})),
            _SubCategory('🧬 Biology', Map<String, String>.from(_configData['bio_mapping'] ?? {})),
            _SubCategory('🧪 Chemistry', Map<String, String>.from(_configData['chem_mapping'] ?? {})),
          ]),
        ),
        const SizedBox(height: 10),

        _buildMainCategoryTile(
          icon: '📚',
          title: 'GK & Social Science',
          subtitle: 'Polity • History • Geography • Economy',
          color: Colors.indigo,
          onTap: () => _openSubCategory(context, 'GK & Social Science', [
            _SubCategory('📜 Indian Polity', Map<String, String>.from(_configData['polity_mapping'] ?? {})),
            _SubCategory('🏛️ History', Map<String, String>.from(_configData['history_mapping'] ?? {})),
            _SubCategory('🌍 Geography', Map<String, String>.from(_configData['geo_mapping'] ?? {})),
            _SubCategory('📈 Economy', Map<String, String>.from(_configData['eco_mapping'] ?? {})),
          ]),
        ),
        const SizedBox(height: 10),

        _buildMainCategoryTile(
          icon: '📰',
          title: 'Current Affairs 2026',
          subtitle: 'Monthly Bulletins & Bihar Special News',
          color: Colors.purple,
          onTap: () => _openSubCategory(context, 'Current Affairs 2026', [
            _SubCategory('📰 Monthly Sets & Bihar Special', Map<String, String>.from(_configData['current_mapping'] ?? {})),
          ]),
        ),

        const SizedBox(height: 16),
        _buildParamedicalMatrixCard(),
      ],
    );
  }

  // 3️⃣ TAB 3: SECTIONAL MOCK PORTAL
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

          if (_selectedExamPanel == 'bpsc') _buildBpscSetsPanel(context),
          if (_selectedExamPanel == 'ssc') _buildSscSetsPanel(context),
          if (_selectedExamPanel == 'bssc_cgl') _buildBsscCglSetsPanel(context),
          if (_selectedExamPanel == 'bssc_inter') _buildBsscInterSetsPanel(context),
        ],
      ),
    );
  }

  Widget _buildSavedTab() => const Center(child: Text('⭐ Bookmarked Questions Area'));

  // 5️⃣ TAB 5: PROFILE
  Widget _buildProfileTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(child: CircleAvatar(radius: 30, child: Icon(Icons.person))),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Bilingual (Hindi / Eng)'),
          value: _isHindi,
          onChanged: (v) => setState(() => _isHindi = v),
        ),
        SwitchListTile(
          title: const Text('Dark Mode'),
          value: _isDarkMode,
          onChanged: (v) => setState(() => _isDarkMode = v),
        ),
        const Divider(),
        _buildLaunchRoadmapCard(),
        const SizedBox(height: 12),
        _buildTrustCard(),
        const SizedBox(height: 12),
        _buildStudentSupportCard(context),
      ],
    );
  }

  // 🛠️ HELPER FUNCTIONS

  Future<void> _openWebsiteUrl(BuildContext context, String linkTitle, String url) async {
    TelegramTracker.sendActivityAlert(screenName: "Opened Website Tool", extraDetails: "$linkTitle ($url)");
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch website: $e')));
      }
    }
  }

  void _launchCbtMock(BuildContext context, String title, String path) async {
    TelegramTracker.sendActivityAlert(screenName: "Started Mock Test", extraDetails: "$title ($path)");
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

  Widget _buildBpscSetsPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏛️ BPSC Civil Services Prelims Core Zone (28 Sets)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: List.generate(28, (index) {
                final setNum = index + 1;
                return ActionChip(
                  label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}'),
                  onPressed: () => _launchCbtMock(context, 'BPSC Modern History Set $setNum', 'bpsc/science/Modern History/set$setNum.json'),
                );
              }),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSscSetsPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ SSC CGL & RRB NTPC Sets', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534))),
            const SizedBox(height: 8),
            _buildSubjectSetRow(context, 'General Reasoning', 'reasoning', 5),
            const Divider(),
            _buildSubjectSetRow(context, 'Quantitative Aptitude', 'aptitude', 5),
          ],
        ),
      ),
    );
  }

  Widget _buildBsscCglSetsPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📚 BSSC Graduate Level Sets', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B21A8))),
            const SizedBox(height: 8),
            _buildSubjectSetRow(context, 'BSSC CGL Reasoning', 'bssc_cgl_reasoning', 5),
          ],
        ),
      ),
    );
  }

  Widget _buildBsscInterSetsPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎓 BSSC 10+2 Inter Level Sets', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF075985))),
            const SizedBox(height: 8),
            _buildSubjectSetRow(context, 'Mental Ability & Reasoning', 'bssc_inter_reasoning', 5),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectSetRow(BuildContext context, String title, String subFolder, int totalSets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: List.generate(totalSets, (i) => ActionChip(
            label: Text('Set 0${i + 1}'),
            onPressed: () => _launchCbtMock(context, '$title Set ${i + 1}', '$subFolder/set${i + 1}.json'),
          )),
        ),
      ],
    );
  }

  Widget _examSelectorCard(String title, String badge, Color color, String panelKey) {
    final bool isSelected = _selectedExamPanel == panelKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedExamPanel = panelKey),
      child: Card(
        color: isSelected ? color.withOpacity(0.12) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
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

  Widget _buildParamedicalMatrixCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('📋 MockTester Paramedical Test Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D9488))),
            SizedBox(height: 6),
            Text('• Quick Mini Mocks (10 Qs): Anatomy & Daily Capsule\n• Sectional Mocks (30 Qs): Technical Syllabus & Speed', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5)),
          ],
        ),
      ),
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
            Text('✅ Just Added: Current Affairs July 2026 Bulletin', style: TextStyle(fontSize: 12, color: Color(0xFF059669))),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustCard() {
    return Card(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('🎯 THE MOCKTESTER ADVANTAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2575FC))),
            SizedBox(height: 4),
            Text('Why Bihar Aspirants Trust MockTester?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 6),
            Text('• 2K+ Active Aspirants • 80%+ Syllabus Match Rate', style: TextStyle(fontSize: 12, color: Colors.grey)),
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

  void _openSubCategory(BuildContext context, String title, List<_SubCategory> subs) {
    TelegramTracker.sendActivityAlert(screenName: "Opened Category", extraDetails: title);
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

// 📸 TELEGRAM CREATOR FORM WIDGET
class TelegramCreatorWidget extends StatefulWidget {
  const TelegramCreatorWidget({super.key});

  @override
  State<TelegramCreatorWidget> createState() => _TelegramCreatorWidgetState();
}

class _TelegramCreatorWidgetState extends State<TelegramCreatorWidget> {
  bool _isExpanded = false;
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤝 Bano MockTester Ke Creator!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Apna Name/Subject daal kar Telegram par Question Photo bhejein!', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                icon: Text(_isExpanded ? '✕' : '📸', style: const TextStyle(fontSize: 12)),
                label: Text(_isExpanded ? 'Close Form' : 'Bhejein Apna Question', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Aapka Naam', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Exam / Subject', isDense: true)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF24A1DE), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Naam bharna zaroori hai!')));
                      return;
                    }
                    TelegramTracker.sendActivityAlert(screenName: "Creator Form Submitted", extraDetails: "Name: ${_nameController.text}");
                    final msg = "Bhai, main apna question photo attach kar rha hu.\n👤 Name: ${_nameController.text}\n📚 Subject: ${_subjectController.text}";
                    final uri = Uri.parse("https://t.me/MT_Masterhub_bot?text=${Uri.encodeComponent(msg)}");
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Text('🚀'),
                  label: const Text('Open Telegram & Send Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class _SubCategory {
  final String title;
  final Map<String, String> mapping;
  _SubCategory(this.title, this.mapping);
}
