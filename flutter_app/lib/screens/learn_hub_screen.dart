import 'package:flutter/material.dart';
import 'learn_chat_screen.dart';

class LearnHubScreen extends StatefulWidget {
  const LearnHubScreen({super.key});

  @override
  State<LearnHubScreen> createState() => _LearnHubScreenState();
}

class _LearnHubScreenState extends State<LearnHubScreen> {
  final List<Map<String, dynamic>> _subjects = [
    // 🧬 1. BIOLOGY (11 Chapters - Tissues Removed)
    {
      'title': 'Biology',
      'icon': '🧬',
      'color': const Color(0xFF059669),
      'chapters': [
        {
          'id': 'bio_cell',
          'title': 'Cell (Koshika)',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/cell.json',
        },
        {
          'id': 'bio_digestive',
          'title': 'Digestive System',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/digestive.json',
        },
        {
          'id': 'bio_circulatory',
          'title': 'Circulatory System',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/circulatory.json',
        },
        {
          'id': 'bio_respiratory',
          'title': 'Respiratory System',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/respiratory.json',
        },
        {
          'id': 'bio_nervous',
          'title': 'Nervous System',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/nervous.json',
        },
        {
          'id': 'bio_excreatory',
          'title': 'Excretory System',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/excreatory.json',
        },
        {
          'id': 'bio_disease',
          'title': 'Human Diseases & Health',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/disease.json',
        },
        {
          'id': 'bio_classification',
          'title': 'Classification of Organisms',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/classification.json',
        },
        {
          'id': 'bio_inheritance',
          'title': 'Genetics & Inheritance',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/inheritance.json',
        },
        {
          'id': 'bio_ecosystem',
          'title': 'Ecosystem & Environment',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/ecosystem.json',
        },
        {
          'id': 'bio_biotech',
          'title': 'Biotechnology',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/biotech.json',
        },
      ]
    },

    // ⚡ 2. PHYSICS (7 Chapters)
    {
      'title': 'Physics',
      'icon': '⚡',
      'color': const Color(0xFF2563EB),
      'chapters': [
        {
          'id': 'phy_motion',
          'title': 'Motion & Kinematics',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/motion.json',
        },
        {
          'id': 'phy_force',
          'title': 'Force & Laws of Motion',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/force.json',
        },
        {
          'id': 'phy_gravity',
          'title': 'Gravitation',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/gravity.json',
        },
        {
          'id': 'phy_work',
          'title': 'Work, Energy & Power',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/work.json',
        },
        {
          'id': 'phy_electricity',
          'title': 'Electricity & Current',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/electricity.json',
        },
        {
          'id': 'phy_magnetism',
          'title': 'Magnetism',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/magnetism.json',
        },
        {
          'id': 'phy_lights',
          'title': 'Light & Optics',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/lights.json',
        },
      ]
    },

    // 🧪 3. CHEMISTRY (11 Chapters)
    {
      'title': 'Chemistry',
      'icon': '🧪',
      'color': const Color(0xFF7C3AED),
      'chapters': [
        {
          'id': 'chem_matter',
          'title': 'Matter & Its States',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/matter.json',
        },
        {
          'id': 'chem_atomic',
          'title': 'Atomic Structure',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/atomicstructure.json',
        },
        {
          'id': 'chem_acidbase',
          'title': 'Acids, Bases & Salts',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/acidbasesalt.json',
        },
        {
          'id': 'chem_metals',
          'title': 'Metals & Metallurgy',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/metals.json',
        },
        {
          'id': 'chem_nonmetals',
          'title': 'Non-Metals & Compounds',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/nonmetal.json',
        },
        {
          'id': 'chem_carbon',
          'title': 'Carbon & Its Compounds',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/carbon.json',
        },
        {
          'id': 'chem_polymer',
          'title': 'Polymers',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/polymer.json',
        },
        {
          'id': 'chem_biomolecules',
          'title': 'Biomolecules',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/biomolecules.json',
        },
        {
          'id': 'chem_electro',
          'title': 'Electrochemistry',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/electrochemistry.json',
        },
        {
          'id': 'chem_surface',
          'title': 'Surface Chemistry',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/surfacechem.json',
        },
        {
          'id': 'chem_life',
          'title': 'Chemistry in Everyday Life',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/chemminlife.json',
        },
      ]
    },

    // 📜 4. POLITY
    {
      'title': 'Polity',
      'icon': '📜',
      'color': const Color(0xFFD97706),
      'chapters': [
        {
          'id': 'pol_preamble',
          'title': 'Preamble & Constitution',
          'subtitle': 'Learn with Aman Sir & Raju',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/polity/preamble.json',
        },
      ]
    },
  ];

  int _selectedSubjectIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeSubject = _subjects[_selectedSubjectIndex];
    final List chapters = activeSubject['chapters'];
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MockTester Learn 🎓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 📌 COMPACT POSITIONING STRIP (MINIMALIST & PROFESSIONAL)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exam-Focused Interactive Learning',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Concept ➔ Story ➔ Practice',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'BPSC • TRE • SSC • BSSC CGL • All Bihar Competitive Exams',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Subject Selector
          Container(
            height: 60,
            color: Theme.of(context).cardColor,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final sub = _subjects[index];
                final bool isSelected = index == _selectedSubjectIndex;

                return GestureDetector(
                  onTap: () => setState(() => _selectedSubjectIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? sub['color'] : sub['color'].withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? sub['color'] : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(sub['icon'], style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          sub['title'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : sub['color'],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Chapter List Builder
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chap = chapters[index];
                final bool isAvailable = chap['isAvailable'] ?? false;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: activeSubject['color'].withOpacity(0.12),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: activeSubject['color']),
                      ),
                    ),
                    title: Text(
                      chap['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Row(
                      children: [
                        const Text('👨‍🏫 ', style: TextStyle(fontSize: 11)),
                        Text(
                          chap['subtitle'],
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable ? const Color(0xFF059669) : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: isAvailable
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF075E54),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LearnChatScreen(
                                    jsonUrl: chap['jsonUrl'],
                                    chapterTitle: chap['title'],
                                  ),
                                ),
                              );
                            },
                            child: const Text('Start ➔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        : const Icon(Icons.lock_clock_rounded, color: Colors.grey, size: 20),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
