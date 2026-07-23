import 'package:flutter/material.dart';
import 'chapter_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Category & Chapter Mappings matching exact JSON file names
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔴 HERO BANNER (PRD Spec)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '🔴 2026 Updated Pattern',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'BPSC, BSSC & Competitive Exams',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildChip('4000+ MCQs'),
                      _buildChip('30+ Chapters'),
                      _buildChip('HI / EN Bilingual'),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Exam Categories & Subjects',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // CATEGORY GRID LIST
            _buildCategoryTile(context, '🏛️ Indian Polity', '13 Chapters', polityMapping),
            _buildCategoryTile(context, '📜 Indian History', '11 Chapters', historyMapping),
            _buildCategoryTile(context, '🌍 Geography', '7 Chapters', geoMapping),
            _buildCategoryTile(context, '📈 Indian Economy', '7 Chapters', ecoMapping),
            _buildCategoryTile(context, '🧬 Biology', '12 Chapters', bioMapping),
            _buildCategoryTile(context, '🧪 Chemistry', '13 Chapters', chemMapping),
            _buildCategoryTile(context, '⚡ Physics', '7 Chapters', phyMapping),
            _buildCategoryTile(context, '📰 Current Affairs 2026', '5 Bulletins', currentMapping),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    String title,
    String subtitle,
    Map<String, String> mapping,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF2563EB)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChapterSelectScreen(
                categoryTitle: title,
                chapterMapping: mapping,
              ),
            ),
          );
        },
      ),
    );
  }
}
