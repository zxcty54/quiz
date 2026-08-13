import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SectionalCbtListScreen extends StatefulWidget {
  final bool isDarkMode;
  const SectionalCbtListScreen({super.key, required this.isDarkMode});

  @override
  State<SectionalCbtListScreen> createState() => _SectionalCbtListScreenState();
}

class _SectionalCbtListScreenState extends State<SectionalCbtListScreen> {
  Map<String, dynamic> _sectionalData = {};
  bool _isLoading = true;

  // Selected Target Key: 'ALL', 'bpsc', 'ssc', 'bssc_cgl', 'bssc_inter', 'bihar_si'
  String _selectedTarget = 'ALL';

  @override
  void initState() {
    super.initState();
    fetchSectionalMocks();
  }

  // 📰 FETCH LIVE JSON FROM GITHUB WITH CACHE BUSTER
  Future<void> fetchSectionalMocks({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'cached_sectional_data_json';

    if (!forceRefresh) {
      String? cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        try {
          final data = jsonDecode(cachedJson);
          if (mounted) {
            setState(() {
              _sectionalData = data is Map<String, dynamic> ? data : {};
              _isLoading = false;
            });
          }
        } catch (_) {}
      }
    }

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String url =
        "https://raw.githubusercontent.com/zxcty54/quiz/main/sectional_data.json?t=$timestamp";

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        String decoded = utf8.decode(res.bodyBytes);
        final data = jsonDecode(decoded);

        if (mounted) {
          setState(() {
            _sectionalData = data is Map<String, dynamic> ? data : {};
            _isLoading = false;
          });
        }
        await prefs.setString(cacheKey, decoded);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching Sectional Mocks: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Target Exam Sectional Mocks',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: () async => await fetchSectionalMocks(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(), // 👈 Allows Pull to Refresh Always
          children: [
            Row(
              children: [
                const Text('🎯 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Target Exam Sectional Mocks',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('अपनी परीक्षा चुनें और रियल TCS CBT पैटर्न पर प्रैक्टिस शुरू करें',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 🎯 TOP DYNAMIC HORIZONTAL SCROLL CARDS (5 EXAMS: BPSC, SSC, BSSC CGL, BSSC 10+2, BIHAR SI)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _targetExamChip('ALL', 'ALL EXAMS', 'Show All Mocks', const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  _targetExamChip('bpsc', 'STATE PCS', 'BPSC PCS', const Color(0xFF881337)),
                  const SizedBox(width: 8),
                  _targetExamChip('ssc', 'TCS PATTERN', 'SSC / NTPC', const Color(0xFF065F46)),
                  const SizedBox(width: 8),
                  _targetExamChip('bssc_cgl', 'GRADUATE', 'BSSC CGL', const Color(0xFF581C87)),
                  const SizedBox(width: 8),
                  _targetExamChip('bssc_inter', 'INTER LEVEL', 'BSSC 10+2', const Color(0xFF1E3A8A)),
                  const SizedBox(width: 8),
                  // 👮 5TH BLOCK: BIHAR SI
                  _targetExamChip('bihar_si', 'POLICE / DAROGA', 'BIHAR SI', const Color(0xFFD97706)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 📋 SETS RENDER SECTION
            _buildSetsSection(cardBg),
          ],
        ),
      ),
    );
  }

  Widget _targetExamChip(String key, String tag, String title, Color activeColor) {
    bool isSelected = _selectedTarget == key;
    return InkWell(
      onTap: () => setState(() => _selectedTarget = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 130,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.15)
              : (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tag, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: activeColor)),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsSection(Color cardBg) {
    List<Widget> sections = [];

    // 1. BIHAR SI SECTION
    if ((_selectedTarget == 'ALL' || _selectedTarget == 'bihar_si') &&
        _sectionalData.containsKey('bihar_si')) {
      final List biharSiList = (_sectionalData['bihar_si'] as List?) ?? [];
      for (var item in biharSiList) {
        final String title = item['title'] ?? '🎯 Bihar SI Practice Sets';
        final int setsCount = item['sets'] ?? 5;
        final String folder = item['folder'] ?? 'bihar_si';

        sections.add(_buildSetGroupCard(title, setsCount, folder, const Color(0xFFD97706)));
      }
    }

    // 2. BPSC SECTION
    if ((_selectedTarget == 'ALL' || _selectedTarget == 'bpsc') &&
        _sectionalData.containsKey('bpsc')) {
      final Map<String, dynamic> bpscData = _sectionalData['bpsc'] ?? {};
      final String title = bpscData['title'] ?? '🏛️ BPSC PCS Special Zone';
      final int totalSets = bpscData['total_sets'] ?? 28;
      final String prefix = bpscData['path_prefix'] ?? 'bpsc';

      sections.add(_buildSetGroupCard(title, totalSets, prefix, const Color(0xFF881337)));
    }

    // 3. BSSC CGL SECTION
    if ((_selectedTarget == 'ALL' || _selectedTarget == 'bssc_cgl') &&
        _sectionalData.containsKey('bssc_cgl')) {
      final List list = (_sectionalData['bssc_cgl'] as List?) ?? [];
      for (var item in list) {
        sections.add(_buildSetGroupCard(
          item['title'] ?? 'BSSC CGL Sets',
          item['sets'] ?? 5,
          item['folder'] ?? 'bssc_cgl',
          const Color(0xFF581C87),
        ));
      }
    }

    // 4. BSSC INTER SECTION
    if ((_selectedTarget == 'ALL' || _selectedTarget == 'bssc_inter') &&
        _sectionalData.containsKey('bssc_inter')) {
      final List list = (_sectionalData['bssc_inter'] as List?) ?? [];
      for (var item in list) {
        sections.add(_buildSetGroupCard(
          item['title'] ?? 'BSSC Inter Sets',
          item['sets'] ?? 5,
          item['folder'] ?? 'bssc_inter',
          const Color(0xFF1E3A8A),
        ));
      }
    }

    // 5. SSC SECTION
    if ((_selectedTarget == 'ALL' || _selectedTarget == 'ssc') &&
        _sectionalData.containsKey('ssc')) {
      final List list = (_sectionalData['ssc'] as List?) ?? [];
      for (var item in list) {
        sections.add(_buildSetGroupCard(
          item['title'] ?? 'SSC Sets',
          item['sets'] ?? 5,
          item['folder'] ?? 'ssc',
          const Color(0xFF065F46),
        ));
      }
    }

    if (sections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("No Sets Available for this Category", style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(children: sections);
  }

  Widget _buildSetGroupCard(String groupTitle, int setsCount, String subFolder, Color themeColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(groupTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(setsCount, (idx) {
              int setNum = idx + 1;
              String setLabel = "Set ${setNum.toString().padLeft(2, '0')}";

              return InkWell(
                onTap: () {
                  // TODO: Open Test Engine with `subFolder` and `setNum`
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeColor, width: 1.2),
                  ),
                  child: Text(
                    setLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
