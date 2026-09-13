import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/revision_hero_banner.dart';
import 'widgets/revision_category_cards.dart';
import 'widgets/revision_current_affairs.dart';

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

  int _selectedScienceSubIndex = 0;
  int _selectedGkSubIndex = 0;
  int _selectedStaticSubIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFromDiskAndFetch();
  }

  @override
  void didUpdateWidget(covariant RevisionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subjectMapping.isNotEmpty && _liveSubjectMapping.isEmpty) {
      setState(() => _liveSubjectMapping = Map<String, dynamic>.from(widget.subjectMapping));
    }
  }

  Future<void> _loadFromDiskAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('persistent_subject_mapping_json');
    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedJson);
        if (decoded is Map && mounted) {
          setState(() => _liveSubjectMapping = Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    if (_liveSubjectMapping.isEmpty && widget.subjectMapping.isNotEmpty) {
      setState(() => _liveSubjectMapping = Map<String, dynamic>.from(widget.subjectMapping));
    }
    _fetchLiveGitHubMapping();
  }

  Future<void> _fetchLiveGitHubMapping() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final int ts = DateTime.now().millisecondsSinceEpoch;
    final List<String> urls = [
      "https://raw.githubusercontent.com/zxcty54/content_base/main/subject_mapping.json?t=$ts",
      "https://raw.githack.com/zxcty54/content_base/main/subject_mapping.json",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/subject_mapping.json?t=$ts",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: {'Cache-Control': 'no-cache'}).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          String rawBody = utf8.decode(res.bodyBytes).trim().replaceAll('```json', '').replaceAll('```', '').trim();
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      onRefresh: _fetchLiveGitHubMapping,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Hero & Trust Banner
          RevisionHeroBanner(isDark: isDark, isLoading: _isLoading),

          const SizedBox(height: 18),
          Text('📚 Chapterwise Revision Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text('Subject select karein aur direct chapter chip dabakar revision shuru karein', style: TextStyle(color: subTextColor, fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),

          // 2. General Science Card
          RevisionSegmentedCard(
            title: 'General Science',
            badgeText: '🔥 High Weightage (BSSC/SSC)',
            icon: '🔬',
            color: const Color(0xFF2563EB),
            isDark: isDark,
            isLoading: _isLoading,
            selectedIndex: _selectedScienceSubIndex,
            onPillSelected: (index) => setState(() => _selectedScienceSubIndex = index),
            subjects: const [
              {'title': '⚡ Physics', 'key': 'phy_mapping'},
              {'title': '🧬 Biology', 'key': 'bio_mapping'},
              {'title': '🧪 Chemistry', 'key': 'chem_mapping'},
            ],
            liveMapping: _liveSubjectMapping,
            onLaunchPractice: widget.onLaunchPractice,
          ),
          const SizedBox(height: 12),

          // 3. GK & Social Science Card
          RevisionSegmentedCard(
            title: 'GK & Social Science',
            badgeText: '🏛️ BPSC/BSSC Core Syllabus',
            icon: '📚',
            color: const Color(0xFF4F46E5),
            isDark: isDark,
            isLoading: _isLoading,
            selectedIndex: _selectedGkSubIndex,
            onPillSelected: (index) => setState(() => _selectedGkSubIndex = index),
            subjects: const [
              {'title': '📜 Indian Polity', 'key': 'polity_mapping'},
              {'title': '🏛️ History', 'key': 'history_mapping'},
              {'title': '🌍 Geography', 'key': 'geo_mapping'},
              {'title': '📈 Economy', 'key': 'eco_mapping'},
            ],
            liveMapping: _liveSubjectMapping,
            onLaunchPractice: widget.onLaunchPractice,
          ),
          const SizedBox(height: 12),

          // 4. Quantitative Aptitude (Direct Flat Chips, Indigo Theme)
          RevisionDirectCard(
            title: 'Quantitative Aptitude (Maths)',
            badgeText: '🎯 Chapterwise & Type-Wise (SSC, BSSC & RLY)',
            headerLabel: 'Mathematics Chapters',
            icon: '📐',
            mappingKey: 'aptitude_mapping',
            fallbackKey: 'aptitude_math_mapping',
            brandColor: const Color(0xFF6366F1), // Royal Indigo
            isDark: isDark,
            isLoading: _isLoading,
            liveMapping: _liveSubjectMapping,
            onLaunchPractice: widget.onLaunchPractice,
          ),
          const SizedBox(height: 12),

          // 5. Reasoning Ability (Direct Flat Chips, Cyan Theme)
          RevisionDirectCard(
            title: 'Reasoning Ability & Logic',
            badgeText: '🧩 High Scoring Speed & Logic Section',
            headerLabel: 'Reasoning Chapters',
            icon: '🧩',
            mappingKey: 'reasoning_mapping',
            fallbackKey: 'reasoning_verbal_mapping',
            brandColor: const Color(0xFF0284C7), // Sky Blue / Cyan
            isDark: isDark,
            isLoading: _isLoading,
            liveMapping: _liveSubjectMapping,
            onLaunchPractice: widget.onLaunchPractice,
          ),
          const SizedBox(height: 12),

          // 6. Current Affairs Vault
          RevisionCurrentAffairsCard(isDark: isDark),
          const SizedBox(height: 12),

          // 7. Static GK & Science Foundation
          RevisionSegmentedCard(
            title: 'Static GK & Science Foundation',
            badgeText: '📌 Core Concepts & One-Liner MCQs',
            icon: '🎯',
            color: const Color(0xFF0D9488),
            isDark: isDark,
            isLoading: _isLoading,
            selectedIndex: _selectedStaticSubIndex,
            onPillSelected: (index) => setState(() => _selectedStaticSubIndex = index),
            subjects: const [
              {'title': '⚡ Physics', 'key': 'static_phy_mapping'},
              {'title': '🧬 Biology', 'key': 'static_bio_mapping'},
              {'title': '🧪 Chemistry', 'key': 'static_chem_mapping'},
              {'title': '📜 Polity', 'key': 'static_polity_mapping'},
              {'title': '🏛️ History', 'key': 'static_history_mapping'},
              {'title': '🌍 Geography', 'key': 'static_geo_mapping'},
              {'title': '📈 Economy', 'key': 'static_eco_mapping'},
            ],
            liveMapping: _liveSubjectMapping,
            onLaunchPractice: widget.onLaunchPractice,
          ),
        ],
      ),
    );
  }
}
