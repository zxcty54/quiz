import 'package:flutter/material.dart';
import 'learn_chat_screen.dart';

class LearnHubScreen extends StatefulWidget {
  const LearnHubScreen({super.key});

  @override
  State<LearnHubScreen> createState() => _LearnHubScreenState();
}

class _LearnHubScreenState extends State<LearnHubScreen> {
  // 📚 CDN BASE PATH: https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/
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
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/cell.json',
        },
        {
          'id': 'bio_digestive',
          'title': 'Digestive System',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/digestive.json',
        },
        {
          'id': 'bio_circulatory',
          'title': 'Circulatory System',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/circulatory.json',
        },
        {
          'id': 'bio_respiratory',
          'title': 'Respiratory System',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/respiratory.json',
        },
        {
          'id': 'bio_nervous',
          'title': 'Nervous System',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/nervous.json',
        },
        {
          'id': 'bio_excreatory',
          'title': 'Excretory System',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/excreatory.json',
        },
        {
          'id': 'bio_disease',
          'title': 'Human Diseases & Health',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/disease.json',
        },
        {
          'id': 'bio_classification',
          'title': 'Classification of Organisms',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/classification.json',
        },
        {
          'id': 'bio_inheritance',
          'title': 'Genetics & Inheritance',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/inheritance.json',
        },
        {
          'id': 'bio_ecosystem',
          'title': 'Ecosystem & Environment',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/ecosystem.json',
        },
        {
          'id': 'bio_biotech',
          'title': 'Biotechnology',
          'subtitle': 'Micro-Learning Concept Cards',
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
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/motion.json',
        },
        {
          'id': 'phy_force',
          'title': 'Force & Laws of Motion',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/force.json',
        },
        {
          'id': 'phy_gravity',
          'title': 'Gravitation',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/gravity.json',
        },
        {
          'id': 'phy_work',
          'title': 'Work, Energy & Power',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/work.json',
        },
        {
          'id': 'phy_electricity',
          'title': 'Electricity & Current',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/electricity.json',
        },
        {
          'id': 'phy_magnetism',
          'title': 'Magnetism',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/physics/magnetism.json',
        },
        {
          'id': 'phy_lights',
          'title': 'Light & Optics',
          'subtitle': 'Micro-Learning Concept Cards',
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
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/matter.json',
        },
        {
          'id': 'chem_atomic',
          'title': 'Atomic Structure',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/atomicstructure.json',
        },
        {
          'id': 'chem_acidbase',
          'title': 'Acids, Bases & Salts',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/acidbasesalt.json',
        },
        {
          'id': 'chem_metals',
          'title': 'Metals & Metallurgy',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/metals.json',
        },
        {
          'id': 'chem_nonmetals',
          'title': 'Non-Metals & Compounds',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/nonmetal.json',
        },
        {
          'id': 'chem_carbon',
          'title': 'Carbon & Its Compounds',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/carbon.json',
        },
        {
          'id': 'chem_polymer',
          'title': 'Polymers',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/polymer.json',
        },
        {
          'id': 'chem_biomolecules',
          'title': 'Biomolecules',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/biomolecules.json',
        },
        {
          'id': 'chem_electro',
          'title': 'Electrochemistry',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/electrochemistry.json',
        },
        {
          'id': 'chem_surface',
          'title': 'Surface Chemistry',
          'subtitle': 'Micro-Learning Concept Cards',
          'isAvailable': true,
          'jsonUrl': 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/chemistry/surfacechem.json',
        },
        {
          'id': 'chem_life',
          'title': 'Chemistry in Everyday Life',
          'subtitle': 'Micro-Learning Concept Cards',
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
          'subtitle': 'Micro-Learning Concept Cards',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('MockTester Learn 🎓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
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
                    subtitle: Text(
                      chap['subtitle'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isAvailable ? Colors.green.shade700 : Colors.grey,
                        fontWeight: isAvailable ? FontWeight.bold : FontWeight.normal,
                      ),
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
