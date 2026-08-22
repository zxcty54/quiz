import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_model.dart';
import '../screens/sectional_cbt_screen.dart';

class CreatorMocksSection extends StatelessWidget {
  final bool isDarkMode;
  const CreatorMocksSection({super.key, required this.isDarkMode});

  void _startMock(BuildContext context, Map<String, dynamic> mock) {
    final List rawList = mock['questions_json'] ?? [];
    if (rawList.isEmpty) return;

    final List<Question> qList = rawList.map((q) => Question(
      qe: q['qe'] ?? q['qh'] ?? '',
      qh: q['qh'] ?? q['qe'] ?? '',
      se: q['se'] != null ? List<String>.from(q['se']) : null,
      sh: q['sh'] != null ? List<String>.from(q['sh']) : null,
      oe: List<String>.from(q['oe'] ?? q['oh'] ?? []),
      oh: List<String>.from(q['oh'] ?? q['oe'] ?? []),
      answerIndex: q['a'] ?? 0,
      explanation: q['eh'] ?? q['ee'] ?? '',
    )).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalCbtScreen(
          testTitle: mock['title'] ?? 'Community Mock',
          questions: qList,
          subFolder: (mock['subject'] ?? 'general').toString().toLowerCase(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('creator_mocks')
          .select('*, creator_profiles!inner(name, is_blocked)')
          .eq('creator_profiles.is_blocked', false)
          .order('created_at', ascending: false)
          .limit(10),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }

        final mocks = snapshot.data ?? [];
        if (mocks.isEmpty) {
          return const SizedBox.shrink(); // Agar koi test nahi hai to hide
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('🔥 Community & Creator Mocks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('LIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mocks.length,
              itemBuilder: (context, idx) {
                final m = mocks[idx];
                final List q = m['questions_json'] ?? [];
                final creator = m['creator_profiles']?['name'] ?? 'Educator';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.15),
                      child: const Icon(Icons.quiz_rounded, color: Color(0xFF2563EB)),
                    ),
                    title: Text(m['title'] ?? 'Mock Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text('By $creator • ${q.length} Questions • ${m['duration_mins']} Mins', style: const TextStyle(fontSize: 12)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _startMock(context, m),
                      child: const Text('Start', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
