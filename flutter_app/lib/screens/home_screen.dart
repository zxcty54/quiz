import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/question_model.dart';
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

  // 📁 Master JSON Mappings
  static const Map<String, String> polityMapping = {
    'Historical Background': 'historicalbackgroud.json',
    'Making of Constitution': 'makingofconstitution.json',
    'FR, FD, DPSP & Amendments': 'FR-FD-DPSP-Amend.json',
    'President, VP & PM': 'President_VP_PM.json',
    'The Parliament': 'parliament.json',
    'Panchayati Raj & Municipalities': 'Panchayati_Raj_Muncipal.json',
  };

  static const Map<String, String> historyMapping = {
    '1857 Revolt': '1857_revolt.json',
    'Bihar History': 'bihar_hist.json',
    'Medieval India': 'medieval.json',
    'Struggle 1939-1947': 'towardfreedom.json',
  };

  static const Map<String, String> geoMapping = {
    'Soils, Forests & Agri': 'soil_forest_dams_agri.json',
    'Indian Geo': 'Indian_Geo.json',
  };

  static const Map<String, String> bioMapping = {
    'Digestive System': 'digestive_system.json',
    'Health & Diseases': 'health.json',
  };

  static const Map<String, String> phyMapping = {
    'Electricity': 'electrical_energy.json',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MockTester', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: IndexedStack(
        index: _currentBottomIndex,
        children: [
          _buildHomeTab(context),       // 🏠 Tab 1: Home
          _buildRevisionTab(context),   // 📚 Tab 2: Revision
          _buildSectionalTab(context),  // 📝 Tab 3: TCS Sectional CBT
          _buildSavedTab(),            // ⭐ Tab 4: Saved
          _buildProfileTab(context),    // ⚙️ Tab 5: Profile & Community
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomIndex,
        onDestinationSelected: (idx) => setState(() => _currentBottomIndex = idx),
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
          // Banner Carousel
          Container(
            height: 120,
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

          // ⚡ WIDGET 1: TOPIC-WISE MINI MOCKS
          _buildMiniMocksCard(context),
          const SizedBox(height: 16),

          // 🩺 WIDGET 2: BTSC ANM/GNM BANNER
          _buildBtscBanner(context),
          const SizedBox(height: 16),

          // 📸 WIDGET 3: TELEGRAM CREATOR FORM
          const TelegramCreatorWidget(),
        ],
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
        ListTile(
          tileColor: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: const Text('🔬', style: TextStyle(fontSize: 22)),
          title: const Text('General Science', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Physics • Chemistry • Biology'),
          onTap: () => _openSubCategory(context, 'General Science', [
            _SubCategory('⚡ Physics', phyMapping),
            _SubCategory('🧬 Biology', bioMapping),
          ]),
        ),
        const SizedBox(height: 10),
        ListTile(
          tileColor: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: const Text('📚', style: TextStyle(fontSize: 22)),
          title: const Text('GK & Social Science', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('History • Polity • Geography'),
          onTap: () => _openSubCategory(context, 'GK & Social Science', [
            _SubCategory('📜 Indian Polity', polityMapping),
            _SubCategory('🏛️ History', historyMapping),
            _SubCategory('🌍 Geography', geoMapping),
          ]),
        ),
        const SizedBox(height: 16),
        _buildParamedicalMatrixCard(),
      ],
    );
  }

  // 3️⃣ TAB 3: TCS SECTIONAL CBT MOCK PORTAL
  Widget _buildSectionalTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Target Exam Sectional Mocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Select Exam for Real TCS CBT Interface', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _examBtn('BPSC PCS', 'bpsc', Colors.pink)),
              const SizedBox(width: 8),
              Expanded(child: _examBtn('SSC CGL', 'ssc', Colors.green)),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedExamPanel == 'bpsc') ...[
            const Text('🏛️ BPSC Modern History Sets', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: List.generate(10, (i) => ActionChip(
                label: Text('Set 0${i + 1}'),
                onPressed: () => _launchCbtMock(context, 'BPSC Set ${i + 1}', 'bpsc/science/Modern History/set${i + 1}.json'),
              )),
            )
          ] else ...[
            const Text('⚡ SSC Reasoning Sets', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: List.generate(5, (i) => ActionChip(
                label: Text('Set 0${i + 1}'),
                onPressed: () => _launchCbtMock(context, 'SSC Set ${i + 1}', 'reasoning/set${i + 1}.json'),
              )),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildSavedTab() => const Center(child: Text('⭐ Bookmarked Questions Area'));

  // 5️⃣ TAB 5: PROFILE & ROADMAP / TRUST / DONATION
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
        
        // 📅 WIDGET 4: LAUNCH ROADMAP
        _buildLaunchRoadmapCard(),
        const SizedBox(height: 12),

        // 🎯 WIDGET 5: WHY TRUST MOCKTESTER
        _buildTrustCard(),
        const SizedBox(height: 12),

        // ❤️ WIDGET 6: STUDENT SUPPORT (DONATION)
        _buildStudentSupportCard(context),
      ],
    );
  }

  // 🛠️ HELPER WIDGET BUILDERS

  Widget _buildMiniMocksCard(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ Quick Mini Mocks (15s Timer)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Based on Latest Syllabus', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2575FC), foregroundColor: Colors.white),
                    onPressed: () => _launchCbtMock(context, 'Electricity', 'electrical_energy.json'),
                    child: const Text('⚡ Electricity'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D2D3), foregroundColor: Colors.white),
                    onPressed: () => _launchCbtMock(context, 'Digestive', 'digestive_system.json'),
                    child: const Text('🧬 Digestive'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

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

  Widget _examBtn(String title, String key, Color color) {
    final active = _selectedExamPanel == key;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(backgroundColor: active ? color.withOpacity(0.15) : Colors.white),
      onPressed: () => setState(() => _selectedExamPanel = key),
      child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  void _openSubCategory(BuildContext context, String title, List<_SubCategory> subs) {
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

  void _launchCbtMock(BuildContext context, String title, String path) async {
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
}

// 📸 Telegram Question Photo Form Widget
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
