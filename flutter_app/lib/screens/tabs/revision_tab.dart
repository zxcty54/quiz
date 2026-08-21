import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/question_model.dart';
import '../revision_practice_screen.dart';
import '../subject_directory_screen.dart';

class RevisionTab extends StatefulWidget {
  final Map<String, dynamic> subjectMapping;
  final Function(BuildContext, String, String) onLaunchPractice;

  const RevisionTab({
    super.key,
    required this.subjectMapping,
    required this.onLaunchPractice,
  });

  @override
  State<RevisionTab> createState() => _RevisionTabState();
}

class _RevisionTabState extends State<RevisionTab> {
  Map<String, dynamic> _liveSubjectMapping = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFromDiskAndFetch();
  }

  @override
  void didUpdateWidget(covariant RevisionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subjectMapping.isNotEmpty && _liveSubjectMapping.isEmpty) {
      setState(() {
        _liveSubjectMapping = Map<String, dynamic>.from(widget.subjectMapping);
      });
    }
  }

  Future<void> _loadFromDiskAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('persistent_subject_mapping_json');

    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedJson);
        if (decoded is Map && mounted) {
          setState(() {
            _liveSubjectMapping = Map<String, dynamic>.from(decoded);
          });
        }
      } catch (_) {}
    }

    if (_liveSubjectMapping.isEmpty && widget.subjectMapping.isNotEmpty) {
      setState(() {
        _liveSubjectMapping = Map<String, dynamic>.from(widget.subjectMapping);
      });
    }

    _fetchLiveGitHubMapping();
  }

  Future<void> _fetchLiveGitHubMapping() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final int ts = DateTime.now().millisecondsSinceEpoch;
    final List<String> urls = [
      "https://raw.githack.com/zxcty54/quiz/main/subject_mapping.json",
      "https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/subject_mapping.json?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/subject_mapping.json?t=$ts",
      "https://cdn.statically.io/gh/zxcty54/quiz/main/subject_mapping.json",
      "https://raw.githubusercontent.com/zxcty54/quiz/main/subject_mapping.json?t=$ts",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          String rawBody = utf8.decode(res.bodyBytes).trim();

          if (rawBody.startsWith('\uFEFF')) {
            rawBody = rawBody.substring(1).trim();
          }
          rawBody = rawBody.replaceAll('```json', '').replaceAll('```', '').trim();

          if (rawBody.startsWith('<') || rawBody.startsWith('<!DOCTYPE')) {
            continue;
          }

          final dynamic parsed = jsonDecode(rawBody);
          if (parsed is Map && mounted) {
            setState(() {
              _liveSubjectMapping = Map<String, dynamic>.from(parsed);
              _isLoading = false;
            });

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('persistent_subject_mapping_json', jsonEncode(parsed));
            return;
          }
        }
      } catch (_) {
        continue;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  int _countChapters(List<Map<String, dynamic>> subSections) {
    int count = 0;
    for (var s in subSections) {
      final key = s['key'];
      if (_liveSubjectMapping.containsKey(key) && _liveSubjectMapping[key] is Map) {
        count += (_liveSubjectMapping[key] as Map).length;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final scienceSections = [
      {'title': 'Physics (TCS PYQs Focus)', 'key': 'phy_mapping'},
      {'title': 'Biology (Repeat Concepts)', 'key': 'bio_mapping'},
      {'title': 'Chemistry (Reactions & Formulas)', 'key': 'chem_mapping'},
    ];

    final gkSections = [
      {'title': 'Indian Polity (Articles Focus)', 'key': 'polity_mapping'},
      {'title': 'History (1857 & Modern)', 'key': 'history_mapping'},
      {'title': 'Geography (Maps & Physical)', 'key': 'geo_mapping'},
      {'title': 'Economy (Budget & Planning)', 'key': 'eco_mapping'},
    ];

    final staticSections = [
      {'title': 'Physics (Static Sets)', 'key': 'static_phy_mapping'},
      {'title': 'Biology (Static Sets)', 'key': 'static_bio_mapping'},
      {'title': 'Chemistry (Static Sets)', 'key': 'static_chem_mapping'},
      {'title': 'Polity (Static Sets)', 'key': 'static_polity_mapping'},
      {'title': 'History (Static Sets)', 'key': 'static_history_mapping'},
      {'title': 'Geography (Static Sets)', 'key': 'static_geo_mapping'},
      {'title': 'Economy (Static Sets)', 'key': 'static_eco_mapping'},
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Revision Hub',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: borderColor, height: 1.0),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLiveGitHubMapping,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🔬 1. General Science
            _buildSubjectCard(
              title: 'General Science',
              subtitle: 'Physics, Chemistry & Biology (PYQ Drill)',
              icon: '🔬',
              chapterCount: _countChapters(scienceSections),
              accentColor: const Color(0xFF2563EB),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              subTextColor: subTextColor,
              onTap: () => _openDirectory(
                title: 'General Science',
                icon: '🔬',
                accentColor: const Color(0xFF2563EB),
                subSections: scienceSections,
              ),
            ),
            const SizedBox(height: 10),

            // 📚 2. GK & Social Science
            _buildSubjectCard(
              title: 'GK & Social Science',
              subtitle: 'Polity, History, Geography & Economy',
              icon: '📚',
              chapterCount: _countChapters(gkSections),
              accentColor: const Color(0xFF4F46E5),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              subTextColor: subTextColor,
              onTap: () => _openDirectory(
                title: 'GK & Social Science',
                icon: '📚',
                accentColor: const Color(0xFF4F46E5),
                subSections: gkSections,
              ),
            ),
            const SizedBox(height: 10),

            // 🎯 3. Static GK & Science Foundation
            _buildSubjectCard(
              title: 'Static GK & Foundation',
              subtitle: 'Topic-wise one-liner concept sets',
              icon: '🎯',
              chapterCount: _countChapters(staticSections),
              accentColor: const Color(0xFF0D9488),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              subTextColor: subTextColor,
              onTap: () => _openDirectory(
                title: 'Static GK & Foundation',
                icon: '🎯',
                accentColor: const Color(0xFF0D9488),
                subSections: staticSections,
              ),
            ),
            const SizedBox(height: 10),

            // 📰 4. Current Affairs Vault
            _buildSubjectCard(
              title: 'Current Affairs Vault',
              subtitle: 'Monthly National & Bihar Special Capsules',
              icon: '📰',
              chapterCount: 307,
              isQuestionCount: true,
              accentColor: const Color(0xFF7C3AED),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              subTextColor: subTextColor,
              onTap: _openCurrentAffairs,
            ),
          ],
        ),
      ),
    );
  }

  void _openDirectory({
    required String title,
    required String icon,
    required Color accentColor,
    required List<Map<String, dynamic>> subSections,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectDirectoryScreen(
          title: title,
          icon: icon,
          accentColor: accentColor,
          subSections: subSections,
          subjectMapping: _liveSubjectMapping,
          onLaunchPractice: widget.onLaunchPractice,
        ),
      ),
    );
  }

  void _openCurrentAffairs() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📰 August 2026 Edition',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.public, color: Color(0xFF2563EB)),
              title: const Text('National & Global (218 Qs)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _fetchAndLaunchCA(false, 'National & Global (Aug 2026)');
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFF059669)),
              title: const Text('Bihar Special (89 Qs)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _fetchAndLaunchCA(true, 'Bihar Special (Aug 2026)');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAndLaunchCA(bool isBihar, String title) async {
    const jsonPath = "https://raw.githubusercontent.com/zxcty54/quiz/main/current_affair/august_2026.json";
    try {
      final res = await http.get(Uri.parse('$jsonPath?t=${DateTime.now().millisecondsSinceEpoch}'));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        final List rawList = isBihar ? (data['bihar_questions'] ?? []) : (data['national_questions'] ?? []);
        final qs = rawList.map<Question>((i) => Question.fromJson(Map<String, dynamic>.from(i))).toList();
        if (mounted && qs.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RevisionPracticeScreen(
                testTitle: title,
                questions: qs,
                storageKey: isBihar ? "ca_bihar_aug_2026" : "ca_nat_aug_2026",
              ),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Widget _buildSubjectCard({
    required String title,
    required String subtitle,
    required String icon,
    required int chapterCount,
    bool isQuestionCount = false,
    required Color accentColor,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: subTextColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isQuestionCount ? '$chapterCount Qs' : '$chapterCount Sets',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(Icons.chevron_right, size: 16, color: subTextColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
