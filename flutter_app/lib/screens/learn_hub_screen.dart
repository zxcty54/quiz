import 'package:flutter/material.dart';
import 'learn_chat_screen.dart';

class LearnHubScreen extends StatefulWidget {
  const LearnHubScreen({super.key});

  @override
  State<LearnHubScreen> createState() => _LearnHubScreenState();
}

class _LearnHubScreenState extends State<LearnHubScreen> {
  final List<Map<String, dynamic>> _subjects = [
    {
      'title': 'Biology',
      'icon': '🧬',
      'color': const Color(0xFF059669),
      'chapters': [
        {
          'id': 'bio_cell',
          'title': 'Cell (Koshika)',
          'subtitle': '33 Micro-Learning Cards',
          'isAvailable': true,
          'jsonUrl': 'https://raw.githubusercontent.com/zxcty54/quiz/refs/heads/main/learn/biology/cell.json',
        },
        {
          'id': 'bio_tissue',
          'title': 'Tissues (Ootak)',
          'subtitle': 'Coming Soon',
          'isAvailable': false,
        },
      ]
    },
    {
      'title': 'Physics',
      'icon': '⚡',
      'color': const Color(0xFF2563EB),
      'chapters': [
        {
          'id': 'phy_units',
          'title': 'Units & Measurement',
          'subtitle': 'Coming Soon',
          'isAvailable': false,
        },
      ]
    },
    {
      'title': 'Chemistry',
      'icon': '🧪',
      'color': const Color(0xFF7C3AED),
      'chapters': [
        {
          'id': 'chem_matter',
          'title': 'Matter & Its States',
          'subtitle': 'Coming Soon',
          'isAvailable': false,
        },
      ]
    },
    {
      'title': 'Polity',
      'icon': '📜',
      'color': const Color(0xFFD97706),
      'chapters': [
        {
          'id': 'pol_preamble',
          'title': 'Preamble & Constitution',
          'subtitle': 'Coming Soon',
          'isAvailable': false,
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
