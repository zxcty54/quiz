import 'package:flutter/material.dart';
import 'chapter_select_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomIndex = 0;

  // Exact File Mappings from Website Script
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
    setState(() {});
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
          _buildHomeDashboard(context),
          _buildPracticeHub(context),
          _buildWebsitePostsTab(),
          _buildProfileSettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentBottomIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Practice'),
          NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article_rounded), label: 'Notes'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  // 1️⃣ MAIN REVISION HUB (LANDING PAGE - MATCHING WEBSITE SCRIPT)
  Widget _buildHomeDashboard(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HERO CAROUSEL POSTERS
            SizedBox(
              height: 150,
              child: PageView(
                children: [
                  _buildPosterCard('🔴 2026 Updated Pattern', 'BPSC, BSSC & Competitive Mocks', '4000+ MCQs • Bilingual', const Color(0xFF2563EB)),
                  _buildPosterCard('⚡ Bihar Special Current Affairs', 'Monthly Bulletins & One-Liners', 'Updated Today', const Color(0xFF059669)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // GUIDE CARD (WEBSITE STEP GUIDE)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('💡 MockTester Se Best Result Kaise Lein?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF))),
                  SizedBox(height: 6),
                  Text('1. Chapterwise Revision: Weak topics ke MCQs practice karein.', style: TextStyle(fontSize: 12)),
                  Text('2. Explanations Padhein: Har answer ke baad vyakhya padhein.', style: TextStyle(fontSize: 12)),
                  Text('3. Real Test: Master Mock attempt karke time manage karein.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Categories & Revision Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // 🎯 TOP 3 MAIN CATEGORIES ONLY (CLEAN SCREEN)
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
      ),
    );
  }

  // 📱 SUB-MENU NAVIGATOR SCREEN (SCREEN 2 LOGIC)
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

  // WIDGET BUILDERS
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

  Widget _buildPracticeHub(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('🎯 Quick Practice Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('🏆 Complete Master Mock Test'),
            subtitle: const Text('Mixed MCQs from all subjects'),
            trailing: const Icon(Icons.play_arrow_rounded),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildWebsitePostsTab() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          Text('📝 Website Posts & Revision Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('📌 BPSC 71st Prelims: High Yield History One-Liners'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProfileSettingsTab() {
    return const Center(child: Text('👤 User Profile & Settings'));
  }
}

class _SubCategory {
  final String title;
  final String subtitle;
  final Map<String, String> mapping;

  _SubCategory(this.title, this.subtitle, this.mapping);
}
