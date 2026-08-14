import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  Map<String, dynamic> _liveData = {};
  String? _selectedExamPanel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFromDiskAndFetch();
  }

  @override
  void didUpdateWidget(covariant SectionalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sirf tab update karein agar liveData abhi tak empty ho
    if (widget.sectionalData.isNotEmpty && _liveData.isEmpty) {
      setState(() {
        _liveData = Map<String, dynamic>.from(widget.sectionalData);
        _selectFirstKey();
      });
    }
  }

  // 1️⃣ Pehle Disk Storage se padho (0ms instant load), fir background live fetch
  Future<void> _loadFromDiskAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('persistent_sectional_data_json');

    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedJson);
        if (decoded is Map && mounted) {
          setState(() {
            _liveData = Map<String, dynamic>.from(decoded);
            _selectFirstKey();
          });
        }
      } catch (_) {}
    }

    if (_liveData.isEmpty && widget.sectionalData.isNotEmpty) {
      setState(() {
        _liveData = Map<String, dynamic>.from(widget.sectionalData);
        _selectFirstKey();
      });
    }

    // Background live cloud sync
    _fetchLiveGitHubData();
  }

  void _selectFirstKey() {
    if (_liveData.isNotEmpty) {
      if (_selectedExamPanel == null || !_liveData.containsKey(_selectedExamPanel)) {
        _selectedExamPanel = _liveData.keys.first;
      }
    }
  }

  // 🚀 DIRECT GITHUB FETCHER + PERMANENT DISK SAVE
  Future<void> _fetchLiveGitHubData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final int ts = DateTime.now().millisecondsSinceEpoch;
    final List<String> urls = [
      "https://raw.githubusercontent.com/zxcty54/quiz/main/sectional_data.json?t=$ts",
      "https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/sectional_data.json?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/sectional_data.json?t=$ts",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final dynamic parsed = jsonDecode(utf8.decode(res.bodyBytes));
          if (parsed is Map && mounted) {
            setState(() {
              _liveData = Map<String, dynamic>.from(parsed);
              _selectFirstKey();
              _isLoading = false;
            });

            // 💾 Phone ke permanent disk storage mein save
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('persistent_sectional_data_json', jsonEncode(parsed));
            return;
          }
        }
      } catch (_) {
        continue;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Color _resolveColor(String key, int index) {
    switch (key) {
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
        const List<Color> palette = [
          Color(0xFF2563EB),
          Color(0xFFDC2626),
          Color(0xFF7C3AED),
          Color(0xFF0D9488),
          Color(0xFFEA580C),
        ];
        return palette[index % palette.length];
    }
  }

  String _formatExamTitle(String key, dynamic data) {
    if (data is Map && data['display_name'] != null) return data['display_name'];
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

  String _formatExamBadge(String key, dynamic data) {
    if (data is Map && data['badge'] != null) return data['badge'];
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
    if (_liveData.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final examKeys = _liveData.keys.toList();
    _selectFirstKey();

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      onRefresh: _fetchLiveGitHubData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🎯 Target Exam Sectional Mocks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const Text('अपनी परीक्षा चुनें और रियल TCS CBT पैटर्न पर प्रैक्टिस शुरू करें',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),

            // 🚀 FULLY DYNAMIC GRID
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
                final panelData = _liveData[examKey];

                final String title = _formatExamTitle(examKey, panelData);
                final String badge = _formatExamBadge(examKey, panelData);
                final Color examColor = _resolveColor(examKey, index);
                final bool isSelected = _selectedExamPanel == examKey;

                return GestureDetector(
                  onTap: () => setState(() => _selectedExamPanel = examKey),
                  child: Card(
                    color: isSelected
                        ? examColor.withOpacity(0.12)
                        : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? examColor : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(badge,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: examColor)),
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
              },
            ),
            const SizedBox(height: 20),

            // 📋 SETS PANEL
            if (_selectedExamPanel != null)
              _buildDynamicSectionalSetsPanel(context, _selectedExamPanel!),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicSectionalSetsPanel(BuildContext context, String examKey) {
    final dynamic panelData = _liveData[examKey];
    if (panelData == null) return const SizedBox.shrink();

    // 1️⃣ Map Format (BPSC PCS)
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: themeColor)),
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

    // 2️⃣ List / Items Format (Bihar Amin, BSSC, SSC, etc.)
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
}
