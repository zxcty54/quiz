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
  String? _selectedExamPanel;

  // Har naye card ke liye auto-rotating colors
  final List<Color> _paletteColors = [
    const Color(0xFF9D174D), // BPSC / Rose
    const Color(0xFFD97706), // Bihar SI / Amber
    const Color(0xFF166534), // SSC / Green
    const Color(0xFF6B21A8), // BSSC CGL / Purple
    const Color(0xFF075985), // BSSC 10+2 / Blue
    const Color(0xFFDC2626), // Railway / Red
    const Color(0xFF0D9488), // Police / Teal
  ];

  @override
  void didUpdateWidget(covariant SectionalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedExamPanel == null || !widget.sectionalData.containsKey(_selectedExamPanel)) {
      if (widget.sectionalData.isNotEmpty) {
        _selectedExamPanel = widget.sectionalData.keys.first;
      }
    }
  }

  // Helper: Exam Key se Clean Title aur Badge banana
  Map<String, String> _getExamMeta(String key) {
    switch (key.toLowerCase()) {
      case 'bpsc':
        return {'title': 'BPSC PCS', 'badge': 'STATE PCS'};
      case 'ssc':
        return {'title': 'SSC / NTPC', 'badge': 'TCS PATTERN'};
      case 'bssc_cgl':
        return {'title': 'BSSC CGL', 'badge': 'GRADUATE'};
      case 'bssc_inter':
        return {'title': 'BSSC 10+2', 'badge': 'INTER LEVEL'};
      case 'bihar_si':
        return {'title': 'BIHAR SI', 'badge': 'POLICE / DAROGA'};
      default:
        return {
          'title': key.replaceAll('_', ' ').toUpperCase(),
          'badge': 'TARGET EXAM',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌐 JITNE KEYS sectional_data.json MEIN HONGI SAB AUTO-FETCH HONGI
    final List<String> examKeys = widget.sectionalData.keys.toList();

    if (_selectedExamPanel == null && examKeys.isNotEmpty) {
      _selectedExamPanel = examKeys.first;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Target Exam Sectional Mocks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('अपनी परीक्षा चुनें और रियल TCS CBT पैटर्न पर प्रैक्टिस शुरू करें',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 14),

          // 🚀 DYNAMIC GRID: ZERO HARDCODING (Jitne exams JSON mein utne Cards)
          if (examKeys.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text("Loading sectional exams...",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.4,
              ),
              itemCount: examKeys.length,
              itemBuilder: (context, index) {
                final key = examKeys[index];
                final meta = _getExamMeta(key);
                final color = _paletteColors[index % _paletteColors.length];

                return _dynamicExamSelectorCard(
                  title: meta['title']!,
                  badge: meta['badge']!,
                  color: color,
                  panelKey: key,
                );
              },
            ),

          const SizedBox(height: 20),

          // 📋 DYNAMIC SETS PANEL (Set 01, Set 02...)
          if (_selectedExamPanel != null)
            _buildDynamicSectionalSetsPanel(context, _selectedExamPanel!),
        ],
      ),
    );
  }

  Widget _buildDynamicSectionalSetsPanel(BuildContext context, String currentKey) {
    final dynamic panelData = widget.sectionalData[currentKey];

    if (panelData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
              child: Text("⚠️ Sets loading... Please check connection.",
                  style: TextStyle(fontSize: 12, color: Colors.grey))),
        ),
      );
    }

    // 1. Single Object Map (Jaise BPSC hota hai)
    if (panelData is Map) {
      int count = panelData['total_sets'] ?? 10;
      String prefix = panelData['path_prefix'] ?? '$currentKey/set';
      String title = panelData['title'] ?? '🏛️ Exam Special Zone';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(count, (i) {
                  final setNum = i + 1;
                  return ActionChip(
                    backgroundColor: const Color(0xFF9D174D).withOpacity(0.08),
                    side: const BorderSide(color: Color(0xFF9D174D)),
                    label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9D174D))),
                    onPressed: () => widget.onLaunchCbtMock(
                        context, '$title Set $setNum', '$prefix$setNum.json'),
                  );
                }),
              )
            ],
          ),
        ),
      );
    }

    // 2. List Array (Jaise bihar_si, ssc, bssc_cgl, bssc_inter, ya koi bhi naya folder)
    if (panelData is List) {
      return Column(
        children: panelData.map((item) {
          if (item is! Map) return const SizedBox.shrink();
          String itemTitle = item['title'] ?? 'Sectional Mock';
          int totalSets = item['sets'] ?? 5;
          String folder = item['folder'] ?? currentKey;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(totalSets, (i) {
                      final setNum = i + 1;
                      return ActionChip(
                        backgroundColor: const Color(0xFF2563EB).withOpacity(0.08),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB))),
                        onPressed: () => widget.onLaunchCbtMock(
                            context,
                            "$itemTitle Set $setNum",
                            "$folder/set$setNum.json"),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _dynamicExamSelectorCard({
    required String title,
    required String badge,
    required Color color,
    required String panelKey,
  }) {
    final bool isSelected = _selectedExamPanel == panelKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedExamPanel = panelKey),
      child: Card(
        color: isSelected
            ? color.withOpacity(0.12)
            : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(badge,
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}
