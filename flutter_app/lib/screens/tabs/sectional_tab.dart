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

  void _showUpcomingNotice(String setTitle, String notice) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🔒 $setTitle jald hi live hoga!\n($notice)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🎯 Target Exam Sectional Mocks',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            const Text('अपनी परीक्षा चुनें और रियल TCS CBT पैटर्न पर प्रैक्टिस शुरू करें',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),

            // ⚡ HIGH-IMPACT REAL-TIME EXAM ENGINE BANNER (Unmissable & Authoritative)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isDarkMode 
                      ? [const Color(0xFF0F2942), const Color(0xFF132F4C)] 
                      : [const Color(0xFFEFF6FF), const Color(0xFFE0F2FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDarkMode ? const Color(0xFF0284C7) : const Color(0xFF38BDF8),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(widget.isDarkMode ? 0.3 : 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF10B981),
                                blurRadius: 5,
                                spreadRadius: 1.2,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Real-Time Updated Mocks (2026 Edition)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: widget.isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Commission ke latest notification, revised syllabus aur modern PYQ trends ke aadhar par sabhi mock sets real-time dynamically update hote hain.',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: widget.isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🚀 CLEAN NON-SCROLL WRAP (Exam Selector Pills)
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: List.generate(examKeys.length, (index) {
                final examKey = examKeys[index];
                final panelData = _liveData[examKey];
                final String title = _formatExamTitle(examKey, panelData);
                final String badge = _formatExamBadge(examKey, panelData);
                final Color examColor = _resolveColor(examKey, index);
                final bool isSelected = _selectedExamPanel == examKey;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedExamPanel = examKey),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? examColor
                          : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? examColor
                            : (widget.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: examColor.withOpacity(0.32),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              )
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.22)
                                : examColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : examColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (widget.isDarkMode ? Colors.white : const Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.8),
            const SizedBox(height: 14),

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
      int upcomingCount = panelData['upcoming_sets'] ?? 0;
      String upcomingText = panelData['upcoming_text'] ?? "Coming Soon";
      String prefix = panelData['path_prefix'] ?? '$examKey/set';
      String title = panelData['title'] ?? '🏛️ Exam Special Zone';
      Color themeColor = _resolveColor(examKey, 0);

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeColor)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...List.generate(count, (i) {
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
                  ...List.generate(upcomingCount, (i) {
                    final setNum = count + i + 1;
                    return ActionChip(
                      avatar: const Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
                      backgroundColor: Colors.grey.withOpacity(0.12),
                      side: BorderSide(color: Colors.grey.shade400),
                      label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.grey)),
                      onPressed: () => _showUpcomingNotice('Set $setNum', upcomingText),
                    );
                  }),
                ],
              )
            ],
          ),
        ),
      );
    }

    // 2️⃣ List / Items Format (Bihar Amin, BSSC, SSC, Bihar SI, etc.)
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
          int upcomingSets = item['upcoming_sets'] ?? 0;
          String upcomingText = item['upcoming_text'] ?? "Live Tomorrow";
          String folder = item['folder'] ?? examKey;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(itemTitle,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ),
                      if (upcomingSets > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade700, width: 0.8),
                          ),
                          child: Text(
                            '🔥 +$upcomingSets Upcoming',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...List.generate(totalSets, (i) {
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
                      ...List.generate(upcomingSets, (i) {
                        final setNum = totalSets + i + 1;
                        return ActionChip(
                          avatar: const Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
                          backgroundColor: Colors.grey.withOpacity(0.12),
                          side: BorderSide(color: Colors.grey.shade400),
                          label: Text('Set ${setNum < 10 ? '0$setNum' : setNum}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: Colors.grey)),
                          onPressed: () => _showUpcomingNotice('Set $setNum', upcomingText),
                        );
                      }),
                    ],
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
