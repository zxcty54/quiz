import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../revision_chapters_screen.dart';
import 'widgets/revision_current_affairs.dart';

// --- Content Proxy (Private content_base ka darwaza: Cloudflare Worker) ---
const String _contentProxyBase =
    'https://content-proxy.nitesh-skyhigh.workers.dev';
const String _contentAppKey = 'mt_4bd7ba22c736af380d9d3905';


/// Ek subject tile ki definition (grid + chapters screen dono ke liye).
class _HubSubject {
  final String title;
  final String subtitle;
  final String icon;
  final Color color;
  final List<RevisionSubjectSection> sections;

  const _HubSubject({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.sections,
  });
}

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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Map<String, int> _progressByKey = {}; // rev_prog_* -> saved question index
  List<Map<String, String>> _newChapters = []; // is update me naye add hue chapters
  bool _hadCachedMapping = false;
  bool _newComputed = false;

  static const List<_HubSubject> _subjects = [
    _HubSubject(
      title: 'General Science',
      subtitle: 'Physics • Biology • Chemistry',
      icon: '🔬',
      color: Color(0xFF2563EB),
      sections: [
        RevisionSubjectSection(label: 'Physics', mappingKey: 'phy_mapping'),
        RevisionSubjectSection(label: 'Biology', mappingKey: 'bio_mapping'),
        RevisionSubjectSection(label: 'Chemistry', mappingKey: 'chem_mapping'),
      ],
    ),
    _HubSubject(
      title: 'GK & Social Science',
      subtitle: 'Polity • History • Geography • Economy',
      icon: '📚',
      color: Color(0xFF4F46E5),
      sections: [
        RevisionSubjectSection(label: 'Polity', mappingKey: 'polity_mapping'),
        RevisionSubjectSection(label: 'History', mappingKey: 'history_mapping'),
        RevisionSubjectSection(label: 'Geography', mappingKey: 'geo_mapping'),
        RevisionSubjectSection(label: 'Economy', mappingKey: 'eco_mapping'),
      ],
    ),
    _HubSubject(
      title: 'Bihar Special',
      subtitle: 'History • Culture • Geography • Polity',
      icon: '🗺️',
      color: Color(0xFFD97706),
      sections: [
        RevisionSubjectSection(label: 'Bihar Special', mappingKey: 'bihar_special_mapping', fallbackKey: 'bihar_mapping'),
      ],
    ),
    _HubSubject(
      title: 'Maths (Quantitative Aptitude)',
      subtitle: 'Chapterwise & Type-wise practice sets',
      icon: '📐',
      color: Color(0xFF6366F1),
      sections: [
        RevisionSubjectSection(label: 'Maths', mappingKey: 'aptitude_mapping', fallbackKey: 'aptitude_math_mapping'),
      ],
    ),
    _HubSubject(
      title: 'Reasoning Ability',
      subtitle: 'Speed & Logic — high scoring section',
      icon: '🧩',
      color: Color(0xFF0284C7),
      sections: [
        RevisionSubjectSection(label: 'Reasoning', mappingKey: 'reasoning_mapping', fallbackKey: 'reasoning_verbal_mapping'),
      ],
    ),
    _HubSubject(
      title: 'Static GK Foundation',
      subtitle: 'One-liner MCQs • Core concepts',
      icon: '🎯',
      color: Color(0xFF0D9488),
      sections: [
        RevisionSubjectSection(label: 'Physics', mappingKey: 'static_phy_mapping'),
        RevisionSubjectSection(label: 'Biology', mappingKey: 'static_bio_mapping'),
        RevisionSubjectSection(label: 'Chemistry', mappingKey: 'static_chem_mapping'),
        RevisionSubjectSection(label: 'Polity', mappingKey: 'static_polity_mapping'),
        RevisionSubjectSection(label: 'History', mappingKey: 'static_history_mapping'),
        RevisionSubjectSection(label: 'Geography', mappingKey: 'static_geo_mapping'),
        RevisionSubjectSection(label: 'Economy', mappingKey: 'static_eco_mapping'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadFromDiskAndFetch();
    _loadProgress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RevisionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subjectMapping.isNotEmpty && _liveSubjectMapping.isEmpty) {
      setState(() => _liveSubjectMapping = Map<String, dynamic>.from(widget.subjectMapping));
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> found = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('rev_prog_')) {
        final v = prefs.getInt(key);
        if (v != null && v > 0) found[key] = v;
      }
    }
    if (mounted) setState(() => _progressByKey = found);
  }

  Future<void> _loadFromDiskAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('persistent_subject_mapping_json');
    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedJson);
        if (decoded is Map && mounted) {
          _hadCachedMapping = true;
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
      "$_contentProxyBase/subject_mapping.json",
      "https://raw.githack.com/zxcty54/content_base/main/subject_mapping.json",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/subject_mapping.json?t=$ts",
      "https://raw.githubusercontent.com/zxcty54/content_base/main/subject_mapping.json?t=$ts",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: {'Cache-Control': 'no-cache', 'X-App-Key': _contentAppKey}).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          String rawBody = utf8.decode(res.bodyBytes).trim().replaceAll('```json', '').replaceAll('```', '').trim();
          final dynamic parsed = jsonDecode(rawBody);
          if (parsed is Map && mounted) {
            final Map<String, dynamic> fresh = Map<String, dynamic>.from(parsed);
            // Naye chapters pehchano: purane cached mapping me jo path nahi tha
            if (_hadCachedMapping && !_newComputed && _liveSubjectMapping.isNotEmpty) {
              _newChapters = _diffNewChapters(_liveSubjectMapping, fresh);
              _newComputed = true;
            }
            setState(() {
              _liveSubjectMapping = fresh;
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

  // ---------- helpers ----------

  Map<String, dynamic> _sectionChapters(RevisionSubjectSection s) {
    final m = _liveSubjectMapping;
    if (m[s.mappingKey] is Map) return Map<String, dynamic>.from(m[s.mappingKey] as Map);
    final fb = s.fallbackKey;
    if (fb != null && m[fb] is Map) return Map<String, dynamic>.from(m[fb] as Map);
    return {};
  }

  int _subjectChapterCount(_HubSubject subject) =>
      subject.sections.fold<int>(0, (sum, s) => sum + _sectionChapters(s).length);

  String _progKey(String path) =>
      'rev_prog_${path.split('?').first.replaceAll('/', '_').replaceAll('.', '_')}';

  String _subjectLabelForKey(String key) {
    const labels = {
      'phy_mapping': 'General Science • Physics',
      'bio_mapping': 'General Science • Biology',
      'chem_mapping': 'General Science • Chemistry',
      'polity_mapping': 'GK • Polity',
      'history_mapping': 'GK • History',
      'geo_mapping': 'GK • Geography',
      'eco_mapping': 'GK • Economy',
      'aptitude_mapping': 'Maths',
      'reasoning_mapping': 'Reasoning',
      'bihar_special_mapping': 'Bihar Special',
      'static_phy_mapping': 'Static GK • Physics',
      'static_bio_mapping': 'Static GK • Biology',
      'static_chem_mapping': 'Static GK • Chemistry',
      'static_polity_mapping': 'Static GK • Polity',
      'static_history_mapping': 'Static GK • History',
      'static_geo_mapping': 'Static GK • Geography',
      'static_eco_mapping': 'Static GK • Economy',
      'current_mapping': 'Current Affairs',
    };
    return labels[key] ?? key.replaceAll('_mapping', '').replaceAll('_', ' ');
  }

  /// Saare leaf chapters: [{title, path, subject}] — nested type maps expand ho jate hain.
  List<Map<String, String>> _allLeafChapters(Map<String, dynamic> mapping) {
    final List<Map<String, String>> out = [];
    mapping.forEach((topKey, topValue) {
      if (topValue is! Map) return;
      final subject = _subjectLabelForKey(topKey);
      topValue.forEach((name, value) {
        if (value is String) {
          out.add({'title': name.toString(), 'path': value, 'subject': subject});
        } else if (value is Map) {
          value.forEach((typeName, p) {
            if (p is String) {
              out.add({'title': '$name — $typeName', 'path': p, 'subject': subject});
            }
          });
        }
      });
    });
    return out;
  }

  List<Map<String, String>> _diffNewChapters(
    Map<String, dynamic> oldMapping,
    Map<String, dynamic> newMapping,
  ) {
    final oldPaths = _allLeafChapters(oldMapping).map((e) => e['path']).toSet();
    final fresh = _allLeafChapters(newMapping)
        .where((e) => !oldPaths.contains(e['path']))
        .toList();
    return fresh.take(10).toList();
  }

  List<Map<String, String>> _continueItems() {
    if (_progressByKey.isEmpty || _liveSubjectMapping.isEmpty) return [];
    final byProgKey = <String, Map<String, String>>{};
    for (final leaf in _allLeafChapters(_liveSubjectMapping)) {
      byProgKey[_progKey(leaf['path']!)] = leaf;
    }
    final items = <Map<String, String>>[];
    _progressByKey.forEach((key, index) {
      final leaf = byProgKey[key];
      if (leaf != null) {
        items.add({...leaf, 'index': '$index'});
      }
    });
    return items.take(6).toList();
  }

  List<Map<String, String>> _searchResults(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _allLeafChapters(_liveSubjectMapping)
        .where((e) =>
            e['title']!.toLowerCase().contains(q) ||
            e['subject']!.toLowerCase().contains(q))
        .take(30)
        .toList();
  }

  void _openSubject(BuildContext context, _HubSubject subject, {required bool isDark}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevisionChaptersScreen(
          title: subject.title,
          icon: subject.icon,
          brandColor: subject.color,
          sections: subject.sections,
          liveMapping: _liveSubjectMapping,
          isLoading: _isLoading,
          onLaunchPractice: widget.onLaunchPractice,
        ),
      ),
    ).then((_) => _loadProgress());
  }

  void _openCurrentAffairs(BuildContext context, {required bool isDark}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevisionChaptersScreen(
          title: 'Current Affairs',
          icon: '📰',
          brandColor: const Color(0xFF7C3AED),
          sections: const [],
          liveMapping: _liveSubjectMapping,
          isLoading: _isLoading,
          onLaunchPractice: widget.onLaunchPractice,
          customBody: RevisionCurrentAffairsCard(isDark: isDark),
        ),
      ),
    ).then((_) => _loadProgress());
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7);

    final continueItems = _continueItems();
    final searching = _searchQuery.trim().isNotEmpty;
    final results = searching ? _searchResults(_searchQuery) : const <Map<String, String>>[];

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      onRefresh: () async {
        await _fetchLiveGitHubMapping();
        await _loadProgress();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📚 Practice Hub', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.3)),
                    const SizedBox(height: 3),
                    Text(
                      'Chapterwise revision — subject chuno, chapter tap karo, practice shuru',
                      style: TextStyle(color: subTextColor, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF2563EB)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.4),
              boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
              decoration: InputDecoration(
                hintText: 'Chapter search karo — Percentage, Magadha, Polity…',
                hintStyle: TextStyle(color: subTextColor, fontSize: 12.5, fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                suffixIcon: searching
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: subTextColor),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),

          if (searching) ...[
            const SizedBox(height: 18),
            Text(
              '🔍 "${_searchQuery.trim()}" — ${results.length} chapters mile',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
            ),
            const SizedBox(height: 10),
            if (results.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'Is naam ka koi chapter nahi mila 😕\nSpelling check karke phir try karo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: subTextColor, height: 1.5),
                ),
              )
            else
              ...List.generate(results.length, (i) {
                final r = results[i];
                return RevisionChapterRow(
                  index: i,
                  title: r['title']!,
                  subtitle: r['subject']!,
                  brandColor: const Color(0xFF2563EB),
                  isDark: isDark,
                  savedIndex: _progressByKey[_progKey(r['path']!)] ?? 0,
                  onTap: () => widget.onLaunchPractice(context, r['title']!, r['path']!),
                );
              }),
          ] else ...[
            // Continue Revising
            if (continueItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionHead('▶️ Continue Revising', '${continueItems.length} IN PROGRESS', textColor),
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: continueItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final item = continueItems[i];
                    final int idx = int.tryParse(item['index'] ?? '0') ?? 0;
                    return InkWell(
                      onTap: () => widget.onLaunchPractice(context, item['title']!, item['path']!),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 225,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor),
                          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['subject']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: subTextColor),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(99)),
                                  child: Text(
                                    '⏳ Q${idx + 1} tak ho gaya',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  'Resume →',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // New Chapters (content update se auto-detect)
            if (_newChapters.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionHead('🆕 New Chapters Add Hue', 'FRESH CONTENT', textColor),
              const SizedBox(height: 10),
              ..._newChapters.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => widget.onLaunchPractice(context, c['title']!, c['path']!),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(8)),
                                child: const Text('NEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['title']!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textColor, height: 1.3),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      c['subject']!,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subTextColor),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.play_circle_fill_rounded, size: 22, color: const Color(0xFF16A34A)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )),
            ],

            // All Subjects grid
            const SizedBox(height: 20),
            _sectionHead('📚 All Subjects', '${_subjects.length + 1} SUBJECTS', textColor),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.98,
              ),
              itemCount: _subjects.length,
              itemBuilder: (ctx, i) {
                final s = _subjects[i];
                final int count = _subjectChapterCount(s);
                return _subjectTile(
                  context: ctx,
                  title: s.title,
                  subtitle: s.subtitle,
                  icon: s.icon,
                  color: s.color,
                  countLabel: _isLoading && count == 0 ? 'LOADING…' : '$count CHAPTERS',
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  onTap: () => _openSubject(ctx, s, isDark: isDark),
                );
              },
            ),
            const SizedBox(height: 10),

            // Current Affairs — wide tile
            Material(
              color: cardBg,
              borderRadius: BorderRadius.circular(19),
              child: InkWell(
                onTap: () => _openCurrentAffairs(context, isDark: isDark),
                borderRadius: BorderRadius.circular(19),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.25 : 0.10), borderRadius: BorderRadius.circular(13)),
                        child: const Center(child: Text('📰', style: TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Affairs', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor)),
                            const SizedBox(height: 2),
                            Text('Month-wise National + Bihar current sets', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: subTextColor)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.25 : 0.10), borderRadius: BorderRadius.circular(99)),
                        child: const Text('MONTHLY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Chapter counts aur new content live content se auto-update hote hain — bina app update ke.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: subTextColor, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHead(String title, String tag, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.2)),
        Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF2563EB), letterSpacing: 0.6)),
      ],
    );
  }

  Widget _subjectTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String icon,
    required Color color,
    required String countLabel,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.25 : 0.10), borderRadius: BorderRadius.circular(13)),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor, height: 1.25, letterSpacing: -0.2),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: subTextColor, height: 1.35),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.25 : 0.10), borderRadius: BorderRadius.circular(99)),
                    child: Text(countLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color)),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
