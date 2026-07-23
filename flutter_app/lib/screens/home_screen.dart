import 'package:flutter/material.dart';
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
  String _selectedExamPanel = 'bpsc'; // Default selected exam zone

  // JSON Mappings for Revision Hub (Tab 2)
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
          _buildTab2Revision(context),        // 📚 Tab 2: Revision Hub (Chapterwise)
          _buildTab3SectionalMock(context),   // 📝 Tab 3: Sectional Mock (Examwise Sets)
          _buildTab4SavedHub(context),         // ⭐ Tab 4: Saved & Downloads
          _buildTab5Profile(context),         // ⚙️ Tab 5: Profile & Settings
        ],
      ),

      // 📱 5-TAB BOTTOM NAVIGATION BAR
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentBottomIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Revision',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Sectional',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
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
            // Banner Carousel
            SizedBox(
              height: 150,
              child: PageView(
                children: [
                  _buildPosterCard('🔴 2026 Live Mocks', 'BPSC & BSSC Sectional Mocks', '9500+ Exam Qs • 53+ Sets', const Color(0xFF2563EB)),
                  _buildPosterCard('⚡ TCS & BPSC Pattern', 'Real CBT Exam Simulation', 'Speed & Accuracy Mocks', const Color(0xFF059669)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats Bar
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 16),

            // Daily Challenge Button
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF2563EB), child: Icon(Icons.bolt, color: Colors.white)),
                title: const Text('🚀 Explore Sectional Test Mocks', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('BPSC, BSSC CGL, SSC & Railway Sets'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => setState(() => _currentBottomIndex = 2), // Switch to Sectional Mock Tab
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📚 TAB 2: REVISION HUB (CHAPTERWISE JSONs)
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
        ],
      ),
    );
  }

  // 📝 TAB 3: SECTIONAL MOCK PORTAL (EXAMWISE SETS FROM WEBSITE CODE)
  Widget _buildTab3SectionalMock(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sectional Header
          const Text('🎯 Target Exam Sectional Mocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('अपनी परीक्षा चुनें और रियल एग्जाम पैटर्न पर प्रैक्टिस शुरू करें', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),

          // 4 Main Target Exam Grid Buttons
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

          // Dynamic Sets Container based on selected Exam
          if (_selectedExamPanel == 'bpsc') _buildBpscSetsPanel(context),
          if (_selectedExamPanel == 'ssc') _buildSscSetsPanel(context),
          if (_selectedExamPanel == 'bssc_cgl') _buildBsscCglSetsPanel(context),
          if (_selectedExamPanel == 'bssc_inter') _buildBsscInterSetsPanel(context),
        ],
      ),
    );
  }

  // 🎯 PANEL 1: BPSC Modern History Sets (28 Sets)
  Widget _buildBpscSetsPanel(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏛️ BPSC Civil Services Prelims Core Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF9D174D))),
            const SizedBox(height: 8),
            const Text('Modern History Mini Mocks (Set 01 - Set 28)', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(28, (index) {
                final setNum = index + 1;
                final setName = 'set$setNum';
                return ActionChip(
                  label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}'),
                  backgroundColor: Colors.pink.shade50,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D)),
                  onPressed: () {
                    // Open Modern History JSON file dynamically
                    _launchSectionalQuiz(context, 'BPSC Modern History Set $setNum', 'bpsc/science/Modern History/$setName.json');
                  },
                );
              }),
            )
          ],
        ),
      ),
    );
  }

  // 🎯 PANEL 2: SSC CGL / RRB NTPC Sets
  Widget _buildSscSetsPanel(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ SSC CGL & RRB NTPC Sets (TCS Pattern)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF166534))),
            const SizedBox(height: 12),
            _buildSubjectSetRow(context, 'General Reasoning', 'reasoning', 5),
            const Divider(),
            _buildSubjectSetRow(context, 'Quantitative Aptitude', 'aptitude', 5),
            const Divider(),
            _buildSubjectSetRow(context, 'English Language', 'english', 5),
          ],
        ),
      ),
    );
  }

  // 🎯 PANEL 3: BSSC CGL Sets
  Widget _buildBsscCglSetsPanel(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📚 BSSC Graduate Level Special Sets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6B21A8))),
            const SizedBox(height: 12),
            _buildSubjectSetRow(context, 'BSSC CGL Reasoning', 'bssc_cgl_reasoning', 5),
            const Divider(),
            _buildSubjectSetRow(context, 'BSSC CGL Mathematics', 'bssc_cgl_aptitude', 5),
          ],
        ),
      ),
    );
  }

  // 🎯 PANEL 4: BSSC 10+2 Inter Level Sets
  Widget _buildBsscInterSetsPanel(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎓 BSSC 10+2 Inter Level Active Mocks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF075985))),
            const SizedBox(height: 12),
            _buildSubjectSetRow(context, 'Mental Ability & Reasoning', 'bssc_inter_reasoning', 5),
            const Divider(),
            _buildSubjectSetRow(context, 'General Mathematics / Arithmetic', 'bssc_inter_aptitude', 5),
          ],
        ),
      ),
    );
  }

  // HELPER FOR SUBJECT SETS
  Widget _buildSubjectSetRow(BuildContext context, String title, String subFolder, int totalSets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: List.generate(totalSets, (index) {
            final setNum = index + 1;
            return ActionChip(
              label: Text('Set 0$setNum'),
              onPressed: () {
                _launchSectionalQuiz(context, '$title Set $setNum', '$subFolder/set$setNum.json');
              },
            );
          }),
        ),
      ],
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

  // ⚙️ TAB 5: PROFILE & APP SETTINGS
  Widget _buildTab5Profile(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: Column(
            children: [
              SizedBox(height: 10),
              CircleAvatar(radius: 36, backgroundColor: Color(0xFF2563EB), child: Icon(Icons.person_rounded, size: 40, color: Colors.white)),
              SizedBox(height: 8),
              Text('Aspirant User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Target: BPSC / BSSC 2026', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('Preferences & Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),

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

        Card(
          child: ListTile(
            leading: const Icon(Icons.format_size_rounded),
            title: const Text('Font Size'),
            subtitle: Text('Current Size: ${_fontSize.toInt()}pt'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(12.0, 20.0))),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(12.0, 20.0))),
              ],
            ),
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('App Version & About'),
            subtitle: const Text('MockTester v1.0.0 (2026 Build)'),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  // WIDGET HELPERS
  Widget _buildExamSelectorCard(String title, String badge, String qs, String sets, Color color, String panelKey) {
    final bool isSelected = _selectedExamPanel == panelKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedExamPanel = panelKey),
      child: Card(
        color: isSelected ? color.withOpacity(0.1) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              ),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(sets, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  void _launchSectionalQuiz(BuildContext context, String chapterName, String jsonPath) {
    // Navigates directly using ChapterSelectScreen instruction dialog logic
    Map<String, String> singleMapping = {chapterName: jsonPath};
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterSelectScreen(
          categoryTitle: 'Sectional Mock',
          chapterMapping: singleMapping,
        ),
      ),
    );
  }

  void _openSubCategoryScreen(BuildContext context, String title, List<_SubCategory> subCategories) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subCategories.length,
            itemBuilder: (context, index) {
              final sub = subCategories[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(sub.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(sub.subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF2563EB)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChapterSelectScreen(
                          categoryTitle: sub.title,
                          chapterMapping: sub.mapping,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPosterCard(String badge, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String lbl) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
        Text(lbl, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMainCategoryCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String tags,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.12),
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tags, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        onTap: onTap,
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
