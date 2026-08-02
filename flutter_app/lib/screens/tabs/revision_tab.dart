import 'package:flutter/material.dart';

class RevisionTab extends StatelessWidget {
  final Map<String, dynamic> subjectMapping;
  final Function(BuildContext, String, String) onLaunchPractice;

  const RevisionTab({
    super.key,
    required this.subjectMapping,
    required this.onLaunchPractice,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 🛡️ TRUST BANNER FOR REVISION HUB
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '🎯 100% EXAM ORIENTED',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'BPSC • BSSC • SSC CGL',
                    style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'No Irrelevant Questions.\nPure TCS & State Commission Pattern.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Har chapter me wahi topics filter kiye gaye hain jo pichle 5 saalo me sabse zyada repeat hue hain.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        const Text('📚 Chapterwise Revision Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Subject par click karein aur direct chapter button dabakar revision shuru karein', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 14),

        _buildExpansionSubjectCategory(
          context: context,
          title: 'General Science',
          badgeText: '🔥 High Weightage (BSSC/SSC)',
          icon: '🔬',
          color: const Color(0xFF2563EB),
          subSections: [
            {'title': '⚡ Physics (TCS PYQs Focus)', 'key': 'phy_mapping'},
            {'title': '🧬 Biology (Repeat Concept Sets)', 'key': 'bio_mapping'},
            {'title': '🧪 Chemistry (Formula & Reactions)', 'key': 'chem_mapping'},
          ],
        ),
        const SizedBox(height: 12),

        _buildExpansionSubjectCategory(
          context: context,
          title: 'GK & Social Science',
          badgeText: '🏛️ BPSC/BSSC Core Syllabus',
          icon: '📚',
          color: const Color(0xFF4F46E5),
          subSections: [
            {'title': '📜 Indian Polity (Articles Special)', 'key': 'polity_mapping'},
            {'title': '🏛️ History (1857 & Freedom Movement)', 'key': 'history_mapping'},
            {'title': '🌍 Geography (Physical & Bihar Map Focus)', 'key': 'geo_mapping'},
            {'title': '📈 Economy (Budget & Five Year Plans)', 'key': 'eco_mapping'},
          ],
        ),
        const SizedBox(height: 12),

        _buildExpansionSubjectCategory(
          context: context,
          title: 'Current Affairs 2026',
          badgeText: '⚡ Latest Exam Bulletins',
          icon: '📰',
          color: const Color(0xFF7C3AED),
          subSections: [
            {'title': '📰 Monthly Sets & Bihar Special', 'key': 'current_mapping'},
          ],
        ),
      ],
    );
  }

  Widget _buildExpansionSubjectCategory({
    required BuildContext context,
    required String title,
    required String badgeText,
    required String icon,
    required Color color,
    required List<Map<String, dynamic>> subSections,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Text(icon, style: const TextStyle(fontSize: 22)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              const SizedBox(height: 2),
              Text(badgeText, style: TextStyle(fontSize: 10.5, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: subSections.map((section) {
            final String subTitle = section['title'];
            final String mapKey = section['key'];

            Map<String, dynamic> rawChapters = {};
            if (subjectMapping.containsKey(mapKey) && subjectMapping[mapKey] is Map) {
              rawChapters = Map<String, dynamic>.from(subjectMapping[mapKey]);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Text(subTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                ),
                rawChapters.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6.0),
                        child: Text("Loading chapters...", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: rawChapters.entries.map((entry) {
                          String path = entry.value.toString();
                          return ActionChip(
                            elevation: 1,
                            backgroundColor: color.withOpacity(0.08),
                            side: BorderSide(color: color.withOpacity(0.3)),
                            label: Text(
                              "📖 ${entry.key}",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                            ),
                            onPressed: () {
                              onLaunchPractice(context, entry.key, path);
                            },
                          );
                        }).toList(),
                      ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
