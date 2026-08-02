import 'package:flutter/material.dart';

class SectionalTab extends StatefulWidget {
  final Map<String, dynamic> sectionalData;
  final bool isDarkMode;
  final Function(BuildContext, String, String) onLaunchCbtMock;

  const SectionalTab({
    super.key,
    required this.sectionalData,
    required this.isDarkMode,
    required this.onLaunchCbtMock,
  });

  @override
  State<SectionalTab> createState() => _SectionalTabState();
}

class _SectionalTabState extends State<SectionalTab> {
  String _selectedExamPanel = 'bpsc';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Target Exam Sectional Mocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('अपनी परीक्षा चुनें और रियल TCS CBT पैटर्न पर प्रैक्टिस शुरू करें', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 14),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.4,
            children: [
              _examSelectorCard('BPSC PCS', 'STATE PCS', const Color(0xFF9D174D), 'bpsc'),
              _examSelectorCard('SSC / NTPC', 'TCS PATTERN', const Color(0xFF166534), 'ssc'),
              _examSelectorCard('BSSC CGL', 'GRADUATE', const Color(0xFF6B21A8), 'bssc_cgl'),
              _examSelectorCard('BSSC 10+2', 'INTER LEVEL', const Color(0xFF075985), 'bssc_inter'),
            ],
          ),
          const SizedBox(height: 20),

          _buildDynamicSectionalSetsPanel(context),
        ],
      ),
    );
  }

  Widget _buildDynamicSectionalSetsPanel(BuildContext context) {
    final dynamic panelData = widget.sectionalData[_selectedExamPanel];

    if (panelData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text("⚠️ Sets loading...", style: TextStyle(fontSize: 12, color: Colors.grey))),
        ),
      );
    }

    if (panelData is Map) {
      int count = panelData['total_sets'] ?? 10;
      String prefix = panelData['path_prefix'] ?? 'bpsc/science/Modern History/set';
      String title = panelData['title'] ?? '🏛️ Exam Special Zone';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(count, (i) {
                  final setNum = i + 1;
                  return ActionChip(
                    backgroundColor: const Color(0xFF9D174D).withOpacity(0.08),
                    side: const BorderSide(color: Color(0xFF9D174D)),
                    label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
                    onPressed: () => widget.onLaunchCbtMock(context, '$title Set $setNum', '$prefix$setNum.json'),
                  );
                }),
              )
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _examSelectorCard(String title, String badge, Color color, String panelKey) {
    final bool isSelected = _selectedExamPanel == panelKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedExamPanel = panelKey),
      child: Card(
        color: isSelected ? color.withOpacity(0.12) : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
