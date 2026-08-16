import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  // 1️⃣ Pehle Disk Storage se padho (0ms instant load), fir background live fetch
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

    // Live cloud sync in background
    _fetchLiveGitHubMapping();
  }

  // 🚀 DIRECT MULTI-CDN UNBLOCKED FETCHER + PERMANENT DISK SAVE
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

          // 🧹 Strip UTF-8 BOM & Markdown if any
          if (rawBody.startsWith('\uFEFF')) {
            rawBody = rawBody.substring(1).trim();
          }
          rawBody = rawBody.replaceAll('```json', '').replaceAll('```', '').trim();

          if (rawBody.startsWith('<') || rawBody.startsWith('<!DOCTYPE')) {
            continue; // Skip HTML responses
          }

          final dynamic parsed = jsonDecode(rawBody);
          if (parsed is Map && mounted) {
            setState(() {
              _liveSubjectMapping = Map<String, dynamic>.from(parsed);
              _isLoading = false;
            });

            // 💾 Phone ke permanent disk storage mein save
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
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      onRefresh: _fetchLiveGitHubMapping,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 🛡️ REVISION HUB HERO TRUST BANNER (Option B: 3x Fast Punch)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Badge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⚡ ', style: TextStyle(fontSize: 10)),
                          Text(
                            'SMART REVISION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'BPSC • BSSC • SSC • RLY',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Main Punch Headline
                const Text(
                  '1 Question = Multiple Facts.\nHar Statement Ka Logic.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Sub-headline / Descriptive Text
                const Text(
                  'Sirf sahi answer nahi — galat option ke peeche ka reason samjho aur 3x tezi se revise karo.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Quick Micro-Feature Pills Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 14),
                          SizedBox(width: 4),
                          Text(
                            '100% PYQ Base',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFBBF24), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Trap Breakdown',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: Color(0xFF4ADE80), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Fast Revision',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Text(
            '📚 Chapterwise Revision Hub',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Subject par click karein aur direct chapter button dabakar revision shuru karein',
            style: TextStyle(color: subTextColor, fontSize: 12),
          ),
          const SizedBox(height: 14),

          _buildExpansionSubjectCategory(
            context: context,
            title: 'General Science',
            badgeText: '🔥 High Weightage (BSSC/SSC)',
            icon: '🔬',
            color: const Color(0xFF2563EB),
            isDark: isDark,
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
            isDark: isDark,
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
            isDark: isDark,
            subSections: [
              {'title': '📰 Monthly Sets & Bihar Special', 'key': 'current_mapping'},
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionSubjectCategory({
    required BuildContext context,
    required String title,
    required String badgeText,
    required String icon,
    required Color color,
    required bool isDark,
    required List<Map<String, dynamic>> subSections,
  }) {
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subTitleColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final Color dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Card(
      color: cardBg,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? color.withOpacity(0.4) : color.withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          unselectedWidgetColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        child: ExpansionTile(
          iconColor: color,
          collapsedIconColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          leading: Text(icon, style: const TextStyle(fontSize: 22)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              const SizedBox(height: 2),
              Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? color.withOpacity(0.9) : color.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: subSections.map((section) {
            final String subTitle = section['title'];
            final String mapKey = section['key'];

            Map<String, dynamic> rawChapters = {};
            if (_liveSubjectMapping.containsKey(mapKey) && _liveSubjectMapping[mapKey] is Map) {
              rawChapters = Map<String, dynamic>.from(_liveSubjectMapping[mapKey]);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: dividerColor, height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Text(
                    subTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: subTitleColor),
                  ),
                ),
                rawChapters.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Text(
                          "Loading chapters...",
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade500 : Colors.grey),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: rawChapters.entries.map((entry) {
                          String path = entry.value.toString();
                          return ActionChip(
                            elevation: 1,
                            backgroundColor: isDark ? color.withOpacity(0.2) : color.withOpacity(0.08),
                            side: BorderSide(
                              color: isDark ? color.withOpacity(0.5) : color.withOpacity(0.3),
                            ),
                            label: Text(
                              "📖 ${entry.key}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : color,
                              ),
                            ),
                            onPressed: () {
                              widget.onLaunchPractice(context, entry.key, path);
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
