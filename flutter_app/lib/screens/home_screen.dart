import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chapter_select_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomIndex = 0;
  bool _isDarkMode = false;
  bool _isHindi = true;
  double _fontSize = 14.0;
  String _selectedExamPanel = 'bpsc';

  // JSON Mappings
  static const Map<String, String> polityMapping = {
    'Historical Background': 'historicalbackgroud.json',
    'Making of Constitution': 'makingofconstitution.json',
    'FR, FD, DPSP & Amendments': 'FR-FD-DPSP-Amend.json',
    'President, VP & PM': 'President_VP_PM.json',
    'Governor, CM & COM': 'Gover_CM_COM.json',
    'The Parliament': 'parliament.json',
    'SC, HC & Sub. Courts': 'SC_HC_Gram.json',
    'Panchayati Raj & Municipalities': 'Panchayati_Raj_Muncipal.json',
    'Constitutional Bodies': 'EC_UPSC_SPSC_FC_CAG_AG.json',
    'Non-Constitutional Bodies': 'Niti_NDC_HRC_CIC_SIC_CVC_lokpal.json',
    'Emergency Provisions': 'emergency.json',
    'Federal System & Relations': 'federal.json',
    'Special Cat. (SC/ST/OBC)': 'SC_ST_BC.json',
  };

  static const Map<String, String> historyMapping = {
    '1857 Revolt': '1857_revolt.json',
    'Bihar History': 'bihar_hist.json',
    'Medieval India': 'medieval.json',
    'Struggle 1939-1947': 'towardfreedom.json',
    'Development of Indian Press': 'histpress.json',
    'Economic Impact of British Rule': 'economicimpact.json',
    'Social & Religious Reforms': 'histsocial.json',
    'National Movement (1905-18)': 'nationalmov1905-18.json',
    'National Movement (1919-39)': 'nationalmov1919-39.json',
    'Peasant Movements': 'peasantmov.json',
    'Beginning of Struggle': 'strugglebegin.json',
  };

  static const Map<String, String> geoMapping = {
    'Soils, Forests, Dams & Agri': 'soil_forest_dams_agri.json',
    'Astronomy & Solar System': 'astronomy.json',
    'Introduction & Indian Geo': 'Indian_Geo.json',
    'Drainage, Climate & Disaster': 'drainage_climate_disaster.json',
    'States & Union Territories': 'states_ut.json',
    'Physical Geography': 'Physicalgeo.json',
    'Resources & Industries': 'resources.json',
  };

  static const Map<String, String> ecoMapping = {
    'Public Finance & Deficit': 'public_finance_fiscal_deficit.json',
    'Planning Commission & NITI': 'planning_commission.json',
    'Inflation & Tax Structure': 'price_inflation.json',
    'Industry & Infrastructure': 'Industry.json',
    'Banking & RBI Policies': 'banking.json',
    'Sectors, GDP & National Income': 'Sectors_GDP_NI.json',
    'Agri & Land Reforms': 'Agriculture_landreforms.json',
  };

  static const Map<String, String> bioMapping = {
    'Botany': 'botany.json',
    'Cell Biology': 'cell_biology.json',
    'Circulatory System': 'circulatory_system.json',
    'Classification': 'classification.json',
    'Digestive System': 'digestive_system.json',
    'Excretory System': 'excreatory_system.json',
    'Nervous System': 'nervous_system_glands.json',
    'Respiratory System': 'resipiratory_system.json',
    'Health & Diseases': 'health.json',
    'Inheritance': 'inheritance.json',
    'Ecosystem': 'ecosystem.json',
    'Biotech': 'biotech.json',
  };

  static const Map<String, String> chemMapping = {
    'Metals & Ores': 'metals_compounds.json',
    'Acids, Bases & Salts': 'acid_base_salt.json',
    'Atomic Structure': 'atomic_structure.json',
    'Bonding': 'bonding.json',
    'Carbon Compounds': 'carbon_compounds.json',
    'Matter': 'matter.json',
    'Non-Metals': 'nonmetal_compounds.json',
    'Periodic Table': 'periodictable.json',
    'Surface Chemistry': 'surfacechem.json',
    'Electrochemistry': 'electrochem.json',
    'Polymers': 'polymer.json',
    'Chemistry in Everyday Life': 'cheminlife.json',
    'Biomolecules': 'biomolecules.json',
  };

  static const Map<String, String> phyMapping = {
    'Light & Optics': 'optics.json',
    'Electricity': 'electrical_energy.json',
    'Magnetism': 'magnetic_energy.json',
    'Force & Gravity': 'force_gravity.json',
    'Motion': 'motions.json',
    'Work, Energy & Power': 'work_energy_power.json',
    'Waves': 'waves.json',
  };

  static const Map<String, String> currentMapping = {
    'Jan 2026': 'jan.json',
    'Feb 2026': '2026-02.json',
    'Mar 2026': '2026-03.json',
    'Apr 2026': '2026-04.json',
    'Bihar Special News': 'bihar_news.json',
  };

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚡ Content Refreshed!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MockTester', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentBottomIndex,
        children: [
          _buildTab1Home(context),            // 🏠 Tab 1: Home Dashboard
          _buildTab2Revision(context),        // 📚 Tab 2: Revision Hub
          _buildTab3SectionalMock(context),   // 📝 Tab 3: Sectional Mock
          _buildTab4SavedHub(context),         // ⭐ Tab 4: Saved & Downloads
          _buildTab5Profile(context),         // ⚙️ Tab 5: Profile & Settings
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentBottomIndex = index);
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

  // 🏠 TAB 1: HOME DASHBOARD
  Widget _buildTab1Home(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Poster Carousel
            SizedBox(
              height: 140,
              child: PageView(
                children: [
                  _buildPosterCard('🔴 2026 Live Mocks', 'BPSC & BSSC Sectional Mocks', '9500+ Exam Qs • 53+ Sets', const Color(0xFF2563EB)),
                  _buildPosterCard('⚡ TCS & BPSC Pattern', 'Real CBT Exam Simulation', 'Speed & Accuracy Mocks', const Color(0xFF059669)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Quick Stats Grid
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('9,500+', 'Exam Qs'),
                    _buildStatItem('53+', 'Mock Sets'),
                    _buildStatItem('100%', 'TCS/BPSC'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. ⚡ Topic-Wise Mini Mocks Widget
            _buildMiniMocksGrid(context),
            const SizedBox(height: 14),

            // 4. 🩺 BTSC ANM/GNM Special Banner
            _buildBtscBanner(context),
            const SizedBox(height: 14),

            // 5. 📸 Bano MockTester Ke Creator (Telegram Photo Form)
            const TelegramCreatorWidget(),
          ],
        ),
      ),
    );
  }

  // 📚 TAB 2: REVISION HUB
  Widget _buildTab2Revision(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('📚 Chapterwise Revision Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildMainCategoryCard(
            context,
            icon: '🔬',
            title: 'General Science',
            tags: 'Physics • Chemistry • Biology',
            subtitle: '1285 MCQs • 18 Chapters',
            color: const Color(0xFF0284C7),
            onTap: () => _openSubCategoryScreen(
              context,
              'General Science',
              [
                _SubCategory('⚡ Physics', '7 Modules • High Weightage', phyMapping),
                _SubCategory('🧬 Biology', '12 Modules • Exam Favorite', bioMapping),
                _SubCategory('🧪 Chemistry', '13 Modules • Formula & Trends', chemMapping),
              ],
            ),
          ),
          _buildMainCategoryCard(
            context,
            icon: '📚',
            title: 'GK & Social Science',
            tags: 'History • Polity • Geography • Economy',
            subtitle: '4200 MCQs • 25 Chapters',
            color: const Color(0xFF2563EB),
            onTap: () => _openSubCategoryScreen(
              context,
              'GK & Social Science',
              [
                _SubCategory('🏛️ Indian History', '11 Modules • High Weightage', historyMapping),
                _SubCategory('📜 Indian Polity', '13 Modules • Must Revise', polityMapping),
                _SubCategory('🌍 Geography', '7 Modules • Core Concepts', geoMapping),
                _SubCategory('📈 Indian Economy', '7 Modules • Exam Specific', ecoMapping),
              ],
            ),
          ),
          _buildMainCategoryCard(
            context,
            icon: '📰',
            title: 'Current Affairs 2026',
            tags: 'Monthly Bulletins • Bihar Special',
            subtitle: '900 MCQs • Monthly Updated',
            color: const Color(0xFF7C3AED),
            onTap: () => _openSubCategoryScreen(
              context,
              'Current Affairs 2026',
              [
                _SubCategory('📰 Current Affairs Bulletins', 'Monthly Sets & Bihar Special', currentMapping),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Paramedical Detailed Matrix Table Widget
          _buildParamedicalMatrixCard(),
        ],
      ),
    );
  }

  // 📝 TAB 3: SECTIONAL MOCK PORTAL
  Widget _buildTab3SectionalMock(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Target Exam Sectional Mocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('अपनी परीक्षा चुनें और रियल एग्जाम पैटर्न पर प्रैक्टिस शुरू करें', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              _buildExamSelectorCard('BPSC PCS', 'STATE PCS', '4,200+ Qs', '28 Sets Available', const Color(0xFF9D174D), 'bpsc'),
              _buildExamSelectorCard('SSC / NTPC', 'TCS PATTERN', '3,100+ Qs', '15 Sets Available', const Color(0xFF166534), 'ssc'),
              _buildExamSelectorCard('BSSC CGL', 'GRADUATE', '2,250+ Qs', '10 Sets Available', const Color(0xFF6B21A8), 'bssc_cgl'),
              _buildExamSelectorCard('BSSC 10+2', 'INTER LEVEL', '1,800+ Qs', '10 Sets Available', const Color(0xFF075985), 'bssc_inter'),
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

  // ⭐ TAB 4: SAVED & DOWNLOADS
  Widget _buildTab4SavedHub(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF2563EB),
            indicatorColor: Color(0xFF2563EB),
            tabs: [
              Tab(icon: Icon(Icons.star_rounded), text: 'Bookmarked Qs'),
              Tab(icon: Icon(Icons.download_done_rounded), text: 'Saved Notes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const Center(child: Text('⭐ No bookmarked questions yet.\nStar questions while practicing!', textAlign: TextAlign.center)),
                const Center(child: Text('📄 No saved offline notes yet.', textAlign: TextAlign.center)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⚙️ TAB 5: PROFILE & SETTINGS
  Widget _buildTab5Profile(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: Column(
            children: [
              CircleAvatar(radius: 32, backgroundColor: Color(0xFF2563EB), child: Icon(Icons.person_rounded, size: 36, color: Colors.white)),
              SizedBox(height: 6),
              Text('Aspirant User', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Target: BPSC / BSSC 2026', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Settings Cards
        Card(
          child: SwitchListTile(
            title: const Text('Bilingual Language'),
            subtitle: Text(_isHindi ? 'Hindi (हिंदी)' : 'English'),
            secondary: const Icon(Icons.language_rounded),
            value: _isHindi,
            onChanged: (val) => setState(() => _isHindi = val),
          ),
        ),
        Card(
          child: SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Eye-friendly night reading'),
            secondary: const Icon(Icons.dark_mode_rounded),
            value: _isDarkMode,
            onChanged: (val) => setState(() => _isDarkMode = val),
          ),
        ),
        const SizedBox(height: 16),

        // 📅 Launch Roadmap Card
        _buildLaunchRoadmapCard(),
        const SizedBox(height: 12),

        // 🎯 Why Trust MockTester Card
        _buildTrustCard(),
        const SizedBox(height: 12),

        // ❤️ Student Initiative Donation Card
        _buildStudentSupportCard(context),
      ],
    );
  }

  // WIDGET HELPER BUILDERS

  Widget _buildMiniMocksGrid(BuildContext context) {
    final miniTopics = [
      {'title': 'Electricity (विद्युत धारा)', 'category': 'General Science', 'jsonFile': 'electrical_energy.json', 'badge': 'SCIENCE', 'color': 0xFF2575FC},
      {'title': 'Digestive System (पाचन)', 'category': 'Biology', 'jsonFile': 'digestive_system.json', 'badge': 'BIOLOGY', 'color': 0xFF2575FC},
      {'title': 'Vitamins (विटामिन)', 'category': 'Biology', 'jsonFile': 'health.json', 'badge': 'HEALTH', 'color': 0xFF2575FC},
      {'title': 'Indian Rivers (नदियाँ)', 'category': 'Geography', 'jsonFile': 'drainage_climate_disaster.json', 'badge': 'GEOGRAPHY', 'color': 0xFF00D2D3},
      {'title': 'Parliament (संसद)', 'category': 'Indian Polity', 'jsonFile': 'parliament.json', 'badge': 'POLITY', 'color': 0xFF00D2D3},
      {'title': '1857 Revolt (1857 क्रांति)', 'category': 'Indian History', 'jsonFile': '1857_revolt.json', 'badge': 'HISTORY', 'color': 0xFFFF9F43},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⚡ Topic-Wise Free Mini Mocks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Text('10 Qs • ⏱️ 15s Per Question', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: miniTopics.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final t = miniTopics[index];
            final Color col = Color(t['color'] as int);
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(t['badge'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: col))),
                    Text(t['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: col, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                        onPressed: () => _launchSectionalQuiz(context, t['title'] as String, t['jsonFile'] as String),
                        child: const Text('Start 🚀', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
            Text('⏳ Next Week: General Science Genetics Framework', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
            Text('• 2K+ Active Aspirants • 80%+ Syllabus Match Rate\n• 100% Free Democratic Learning & Instant Analytics', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
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
            const Text('We don\'t charge ₹499/pass. Keep us free for rural students by contributing ₹10.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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

  Widget _buildParamedicalMatrixCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('📋 MockTester Paramedical Test Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D9488))),
            SizedBox(height: 6),
            Text('• Quick Mini Mocks (10 Qs): Anatomy & Daily Capsule\n• Sectional Mocks (30 Qs): Technical Syllabus & Speed\n• Subject Mocks: Community Health & Primary Care', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5)),
          ],
        ),
      ),
    );
  }

  // EXISTING MOCK PANELS & HELPERS
  Widget _buildBpscSetsPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏛️ BPSC Civil Services Prelims Core Zone', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: List.generate(28, (index) {
                final setNum = index + 1;
                return ActionChip(
                  label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}'),
                  onPressed: () => _launchSectionalQuiz(context, 'BPSC Modern History Set $setNum', 'bpsc/science/Modern History/set$setNum.json'),
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
          children: List.generate(totalSets, (i) => ActionChip(label: Text('Set 0${i + 1}'), onPressed: () => _launchSectionalQuiz(context, '$title Set ${i + 1}', '$subFolder/set${i + 1}.json'))),
        ),
      ],
    );
  }

  Widget _buildPosterCard(String badge, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)), child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String lbl) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
        Text(lbl, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildExamSelectorCard(String title, String badge, String qs, String sets, Color color, String panelKey) {
    final bool isSelected = _selectedExamPanel == panelKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedExamPanel = panelKey),
      child: Card(
        color: isSelected ? color.withOpacity(0.1) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color))),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(sets, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCategoryCard(BuildContext context, {required String icon, required String title, required String tags, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.12), child: Text(icon, style: const TextStyle(fontSize: 18))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(tags, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _launchSectionalQuiz(BuildContext context, String chapterName, String jsonPath) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChapterSelectScreen(categoryTitle: 'Sectional Mock', chapterMapping: {chapterName: jsonPath})));
  }

  void _openSubCategoryScreen(BuildContext context, String title, List<_SubCategory> subCategories) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(appBar: AppBar(title: Text(title)), body: ListView.builder(padding: const EdgeInsets.all(16), itemCount: subCategories.length, itemBuilder: (context, index) { final sub = subCategories[index]; return Card(margin: const EdgeInsets.symmetric(vertical: 6), child: ListTile(title: Text(sub.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text(sub.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF2563EB)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChapterSelectScreen(categoryTitle: sub.title, chapterMapping: sub.mapping))))); }))));
  }
}

// Stateful Widget for Telegram Photo Form
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
            const Text('Apna Naam aur Subject daal kar direct Telegram par question ki photo attach karke bhejein!', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                icon: Text(_isExpanded ? '✕' : '📸', style: const TextStyle(fontSize: 12)),
                label: Text(_isExpanded ? 'Close Form' : 'Bhejein Apna Question (Open Portal)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                    final msg = "Bhai, main apna question photo ke roop mein attach kar rha hu.\n\n👤 Name: ${_nameController.text}\n📚 Subject: ${_subjectController.text}";
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
  final String subtitle;
  final Map<String, String> mapping;

  _SubCategory(this.title, this.subtitle, this.mapping);
}
