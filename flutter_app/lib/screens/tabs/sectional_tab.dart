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

  @override
  void initState() {
    super.initState();
    _initSelection();
  }

  @override
  void didUpdateWidget(covariant SectionalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initSelection();
  }

  void _initSelection() {
    if (widget.sectionalData.isNotEmpty) {
      if (_selectedExamPanel == null || !widget.sectionalData.containsKey(_selectedExamPanel)) {
        _selectedExamPanel = widget.sectionalData.keys.first;
      }
    }
  }

  // Pre-set attractive exam colors fallback
  Color _resolveColor(String examKey, int index) {
    switch (examKey) {
      case 'bpsc':
        return const Color(0xFF9D174D);
      case 'ssc':
        return const Color(0xFF166534);
      case 'bssc_cgl':
        return const Color(0xFF6B21A8);
      case 'bssc_inter':
        return const Color(0xFF075985);
      case 'bihar_si':
        return const Color(0xFFD97706);
      case 'bihar_amin':
        return const Color(0xFF059669);
      default:
        const List<Color> dynamicPalette = [
          Color(0xFF2563EB),
          Color(0xFFD97706),
          Color(0xFFDC2626),
          Color(0xFF7C3AED),
          Color(0xFF0D9488),
          Color(0xFFEA580C),
        ];
        return dynamicPalette[index % dynamicPalette.length];
    }
  }

  String _formatExamTitle(String key, dynamic panelData) {
    if (panelData is Map && panelData['display_name'] != null) {
      return panelData['display_name'];
    }
    switch (key) {
      case 'bpsc':
        return 'BPSC PCS';
      case 'ssc':
        return 'SSC / NTPC';
      case 'bssc_cgl':
        return 'BSSC CGL';
      case 'bssc_inter':
        return 'BSSC 10+2';
      case 'bihar_si':
        return 'BIHAR SI';
      case 'bihar_amin':
        return 'BIHAR AMIN';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatExamBadge(String key, dynamic panelData) {
    if (panelData is Map && panelData['badge'] != null) {
      return panelData['badge'];
    }
    switch (key) {
      case 'bpsc':
        return 'STATE PCS';
      case 'ssc':
        return 'TCS PATTERN';
      case 'bssc_cgl':
        return 'GRADUATE';
      case 'bssc_inter':
        return 'INTER LEVEL';
      case 'bihar_si':
        return 'POLICE / DAROGA';
      case 'bihar_amin':
        return 'REVENUE DEPT';
      default:
        return 'EXAM ZONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sectionalData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("⚠️ Sets loading... Please check connection.",
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }

    final examKeys = widget.sectionalData.keys.toList();
    _initSelection();

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

          // 🚀 FULLY DYNAMIC GRID BUILDER (GitHub ke har exam ka card auto banega)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: examKeys.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (context, index) {
              final examKey = examKeys[index];
              final panelData = widget.sectionalData[examKey];

              final String title = _formatExamTitle(examKey, panelData);
              final String badge = _formatExamBadge(examKey, panelData);
              final Color examColor = _resolveColor(examKey, index);

              return _examSelectorCard(title, badge, examColor, examKey);
            },
          ),
          const SizedBox(height: 20),

          // 📋 SETS PANEL
          if (_selectedExamPanel != null) _buildDynamicSectionalSetsPanel(context, _selectedExamPanel!),
        ],
      ),
    );
  }

  Widget _buildDynamicSectionalSetsPanel(BuildContext context, String examKey) {
    final dynamic panelData = widget.sectionalData[examKey];

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

    // 1️⃣ Map Format (Jaise BPSC Single Zone)
    if (panelData is Map && panelData.containsKey('total_sets')) {
      int count = panelData['total_sets'] ?? 10;
      String prefix = panelData['path_prefix'] ?? '$examKey/set';
      String title = panelData['title'] ?? '🏛️ Exam Special Zone';
      Color themeColor = _resolveColor(examKey, 0);

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(count, (i) {
                  final setNum = i + 1;
                  return ActionChip(
                    backgroundColor: themeColor.withOpacity(0.08),
                    side: BorderSide(color: themeColor),
                    label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
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

    // 2️⃣ List / Items Format (BSSC, SSC, Bihar SI, Bihar Amin, etc.)
    List items = [];
    if (panelData is List) {
      items = panelData;
    } else if (panelData is Map && panelData['items'] is List) {
      items = panelData['items'];
    }

    if (items.isNotEmpty) {
      return Column(
        children: items.map<Widget>((item) {
          String itemTitle = item['title'] ?? 'Sectional Mock';
          int totalSets = item['sets'] ?? 1;
          String folder = item['folder'] ?? examKey;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                                fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        onPressed: () => widget.onLaunchCbtMock(
                            context, "$itemTitle Set $setNum", "$folder/set$setNum.json"),
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

  Widget _examSelectorCard(String title, String badge, Color color, String panelKey) {
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
                  maxLines: 2,
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
