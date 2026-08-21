import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/question_model.dart';
import '../revision_practice_screen.dart';

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

  Future<void> _openCurrentAffairsSection({
    required bool isBihar,
    required String title,
    String jsonPath = "https://raw.githubusercontent.com/zxcty54/quiz/main/current_affair/august_2026.json",
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(width: 16),
                Text('Current Affairs लोड हो रहा है...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final String fetchUrl = jsonPath.startsWith('http')
          ? '$jsonPath?t=${DateTime.now().millisecondsSinceEpoch}'
          : 'https://raw.githubusercontent.com/zxcty54/quiz/main/$jsonPath?t=${DateTime.now().millisecondsSinceEpoch}';

      final res = await http.get(Uri.parse(fetchUrl)).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        String body = utf8.decode(res.bodyBytes).trim();
        if (body.startsWith('\uFEFF')) body = body.substring(1).trim();

        final Map<String, dynamic> data = jsonDecode(body);
        final List<dynamic> rawList = isBihar
            ? (data['bihar_questions'] ?? [])
            : (data['national_questions'] ?? []);

        final List<Question> qs = rawList
            .map<Question>((item) => Question.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        if (mounted) {
          Navigator.pop(context);

          if (qs.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => RevisionPracticeScreen(
                  testTitle: title,
                  questions: qs,
                  storageKey: isBihar ? "ca_bihar_aug_2026" : "ca_national_aug_2026",
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚠️ कोई प्रश्न नहीं मिला!')),
            );
          }
        }
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ लोड करने में त्रुटि: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // High-Contrast Colors (No Eye Strain)
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      onRefresh: _fetchLiveGitHubMapping,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 🛡️ HERO BANNER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                const Text(
                  'Sirf sahi answer nahi — galat option ke peeche ka reason samjho aur 3x tezi se revise karo.',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 14),
                          SizedBox(width: 4),
                          Text('100% PYQ Base', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFBBF24), size: 14),
                          SizedBox(width: 4),
                          Text('Trap Breakdown', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: Color(0xFF4ADE80), size: 14),
                          SizedBox(width: 4),
                          Text('Fast Revision', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Text('📚 Chapterwise Revision Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text('Subject par click karein aur direct chapter button dabakar revision shuru karein', style: TextStyle(color: subTextColor, fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),

          // 🔬 1. General Science (BPSC Drill Sets)
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

          // 🏛️ 2. GK & Social Science (BPSC Drill Sets)
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

          // 📰 3. Current Affairs Vault (Multi-Month Scrollable)
          _buildCurrentAffairsCategory(
            context: context,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // 🎯 4. STATIC GK & SCIENCE FOUNDATION
          _buildExpansionSubjectCategory(
            context: context,
            title: 'Static GK & Science Foundation',
            badgeText: '📌 Core Concepts & One-Liner MCQs',
            icon: '🎯',
            color: const Color(0xFF0D9488),
            isDark: isDark,
            subSections: [
              {'title': '⚡ Physics (Static Sets)', 'key': 'static_phy_mapping'},
              {'title': '🧬 Biology (Static Sets)', 'key': 'static_bio_mapping'},
              {'title': '🧪 Chemistry (Static Sets)', 'key': 'static_chem_mapping'},
              {'title': '📜 Indian Polity (Static Sets)', 'key': 'static_polity_mapping'},
              {'title': '🏛️ History (Static Sets)', 'key': 'static_history_mapping'},
              {'title': '🌍 Geography (Static Sets)', 'key': 'static_geo_mapping'},
              {'title': '📈 Economy (Static Sets)', 'key': 'static_eco_mapping'},
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentAffairsCategory({
    required BuildContext context,
    required bool isDark,
  }) {
    const Color brandPurple = Color(0xFF7C3AED);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Multiple Months List (August + September + Upcoming Months smoothly render here)
    final List<Map<String, dynamic>> monthlyVault = [
      {
        "month": "August 2026",
        "badge": "🔥 LIVE NOW",
        "isLive": true,
        "total": 307,
        "natCount": 218,
        "biharCount": 89,
        "jsonUrl": "https://raw.githubusercontent.com/zxcty54/quiz/main/current_affair/august_2026.json"
      },
      {
        "month": "September 2026",
        "badge": "🔒 COMING SOON",
        "isLive": false,
        "total": 0,
        "natCount": 0,
        "biharCount": 0,
        "releaseDate": "1st October"
      },
      {
        "month": "October 2026",
        "badge": "🔒 UPCOMING",
        "isLive": false,
        "total": 0,
        "natCount": 0,
        "biharCount": 0,
        "releaseDate": "1st November"
      },
    ];

    return Card(
      color: cardBg,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? brandPurple.withOpacity(0.5) : brandPurple.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          unselectedWidgetColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          iconColor: brandPurple,
          collapsedIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: brandPurple.withOpacity(isDark ? 0.3 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('📰', style: TextStyle(fontSize: 20)),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Current Affairs Vault',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: brandPurple),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(isDark ? 0.3 : 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.6)),
                    ),
                    child: const Text(
                      '2026 EDITION',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Monthly curated MCQs with trap logic & fact breakdown',
                style: TextStyle(fontSize: 11.5, color: subTextColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: dividerColor, height: 16),
            ...monthlyVault.map<Widget>((item) {
              final bool isLive = item['isLive'] as bool;
              final String monthTitle = item['month'] as String;
              final String badge = item['badge'] as String;

              if (isLive) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0284C7)),
                              const SizedBox(width: 6),
                              Text(
                                monthTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('● ', style: TextStyle(color: Colors.white, fontSize: 8)),
                                Text(
                                  badge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                _openCurrentAffairsSection(
                                  isBihar: false,
                                  title: "🌐 National & Global ($monthTitle)",
                                  jsonPath: item['jsonUrl'],
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('🌐', style: TextStyle(fontSize: 16)),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${item['natCount']} Qs',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'National & Global',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Awards, Sports, Schemes',
                                      style: TextStyle(fontSize: 10.5, color: subTextColor, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                _openCurrentAffairsSection(
                                  isBihar: true,
                                  title: "🇮🇳 Bihar Special ($monthTitle)",
                                  jsonPath: item['jsonUrl'],
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('📍', style: TextStyle(fontSize: 16)),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${item['biharCount']} Qs',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Bihar Special',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'BPSC & State Exams',
                                      style: TextStyle(fontSize: 10.5, color: subTextColor, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              } else {
                return InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Text('🔒 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                '$monthTitle capsule editorial review mein hai. ${item['releaseDate']} ko unlock hoga!',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF1E293B),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 16, color: subTextColor),
                            const SizedBox(width: 8),
                            Text(
                              monthTitle,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: subTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }),
          ],
        ),
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
    final Color subTitleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Card(
      color: cardBg,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? color.withOpacity(0.5) : color.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          unselectedWidgetColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
        child: ExpansionTile(
          iconColor: color,
          collapsedIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          leading: Text(icon, style: const TextStyle(fontSize: 22)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: color)),
              const SizedBox(height: 2),
              Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? color.withOpacity(0.95) : color.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: subTitleColor),
                  ),
                ),
                rawChapters.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Text(
                          "Loading chapters...",
                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: rawChapters.entries.map((entry) {
                          String path = entry.value.toString();
                          return ActionChip(
                            elevation: 1,
                            backgroundColor: isDark ? color.withOpacity(0.25) : color.withOpacity(0.1),
                            side: BorderSide(
                              color: isDark ? color.withOpacity(0.6) : color.withOpacity(0.4),
                            ),
                            label: Text(
                              "📖 ${entry.key}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
