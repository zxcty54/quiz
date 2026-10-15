import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../sectional_exam_screen.dart';

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
  bool _isLoading = false;

  // CbtProgressService ka saved data: launchTitle -> {status, score, correct, total...}
  Map<String, Map<String, dynamic>> _progress = {};
  Timer? _refreshTimer;
  bool _refreshPending = false;

  @override
  void initState() {
    super.initState();
    _loadFromDiskAndFetch();
    _refreshProgress();
    // Test khatm karke wapas aane par grid/hero auto-refresh ho jaye
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (_refreshPending && (ModalRoute.of(context)?.isCurrent ?? false)) {
        _refreshPending = false;
        _refreshProgress();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SectionalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sectionalData.isNotEmpty && _liveData.isEmpty) {
      setState(() {
        _liveData = Map<String, dynamic>.from(widget.sectionalData);
      });
    }
  }

  // 1️⃣ Disk Storage load (0ms instant load), background live fetch
  Future<void> _loadFromDiskAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('persistent_sectional_data_json');

    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedJson);
        if (decoded is Map && mounted) {
          setState(() {
            _liveData = Map<String, dynamic>.from(decoded);
          });
        }
      } catch (_) {}
    }

    if (_liveData.isEmpty && widget.sectionalData.isNotEmpty) {
      setState(() {
        _liveData = Map<String, dynamic>.from(widget.sectionalData);
      });
    }

    _fetchLiveGitHubData();
  }

  // 🚀 DIRECT GITHUB FETCHER (content_base) + PERMANENT DISK SAVE
  Future<void> _fetchLiveGitHubData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final int ts = DateTime.now().millisecondsSinceEpoch;
    final List<String> urls = [
      "https://raw.githubusercontent.com/zxcty54/content_base/main/sectional_data.json?t=$ts",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/sectional_data.json?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/sectional_data.json?t=$ts",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final dynamic parsed = jsonDecode(utf8.decode(res.bodyBytes));
          if (parsed is Map && mounted) {
            setState(() {
              _liveData = Map<String, dynamic>.from(parsed);
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

  String _examIcon(String key) {
    switch (key) {
      case 'bpsc':
        return '🏛️';
      case 'ssc':
        return '🚂';
      case 'bssc_cgl':
        return '🎓';
      case 'bssc_inter':
        return '📗';
      case 'bihar_si':
        return '🚔';
      case 'bihar_amin':
        return '🗺️';
      default:
        return '🎯';
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

  // ---------- Progress (CbtProgressService ke saved records) ----------

  Future<Map<String, Map<String, dynamic>>> _loadProgressMap() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, dynamic>> out = {};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith('cbt_progress_')) continue;
      try {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          out[k.substring('cbt_progress_'.length)] = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return out;
  }

  Future<void> _refreshProgress() async {
    final data = await _loadProgressMap();
    if (mounted) setState(() => _progress = data);
  }

  // ---------- JSON -> Groups (purani wali exact logic, dono formats) ----------

  List<SectionalExamGroup> _groupsFor(String examKey) {
    final dynamic panelData = _liveData[examKey];
    if (panelData == null) return [];

    // Map Format (total_sets)
    if (panelData is Map && panelData.containsKey('total_sets')) {
      return [
        SectionalExamGroup(
          title: panelData['title'] ?? '🏛️ Exam Special Zone',
          sets: panelData['total_sets'] ?? 10,
          upcomingSets: panelData['upcoming_sets'] ?? 0,
          upcomingText: panelData['upcoming_text'] ?? "Coming Soon",
          pathPrefix: panelData['path_prefix'] ?? '$examKey/set',
        ),
      ];
    }

    // List / Items Format
    List items = [];
    if (panelData is List) {
      items = panelData;
    } else if (panelData is Map && panelData['items'] is List) {
      items = panelData['items'];
    }

    return items.map<SectionalExamGroup>((item) {
      final String folder = item['folder'] ?? examKey;
      return SectionalExamGroup(
        title: item['title'] ?? 'Sectional Mock',
        sets: item['sets'] ?? 1,
        upcomingSets: item['upcoming_sets'] ?? 0,
        upcomingText: item['upcoming_text'] ?? "Live Tomorrow",
        pathPrefix: '$folder/set',
      );
    }).toList();
  }

  ({int done, int total}) _examCounts(String examKey) {
    int done = 0;
    int total = 0;
    for (final g in _groupsFor(examKey)) {
      total += g.sets;
      for (int n = 1; n <= g.sets; n++) {
        if (_progress[g.launchTitle(n)]?['status'] == 'COMPLETED') done++;
      }
    }
    return (done: done, total: total);
  }

  /// Next suggested set: pehle koi In-Progress, warna pehla bacha hua set.
  Map<String, dynamic>? _nextCandidate(List<String> examKeys) {
    Map<String, dynamic>? firstLeft;
    for (final key in examKeys) {
      final counts = _examCounts(key);
      for (final g in _groupsFor(key)) {
        for (int n = 1; n <= g.sets; n++) {
          final title = g.launchTitle(n);
          final status = _progress[title]?['status']?.toString();
          if (status == 'IN_PROGRESS') {
            return {
              'title': title,
              'path': g.launchPath(n),
              'examKey': key,
              'inProgress': true,
              'done': counts.done,
              'total': counts.total,
            };
          }
          if (status != 'COMPLETED' && firstLeft == null) {
            firstLeft = {
              'title': title,
              'path': g.launchPath(n),
              'examKey': key,
              'inProgress': false,
              'done': counts.done,
              'total': counts.total,
            };
          }
        }
      }
    }
    return firstLeft;
  }

  void _launch(BuildContext context, String title, String path) {
    _refreshPending = true;
    widget.onLaunchCbtMock(context, title, path);
  }

  void _openExam(BuildContext context, String examKey, int index) {
    final data = _liveData[examKey];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalExamScreen(
          examTitle: _formatExamTitle(examKey, data),
          badge: _formatExamBadge(examKey, data),
          icon: _examIcon(examKey),
          color: _resolveColor(examKey, index),
          isDarkMode: widget.isDarkMode,
          groups: _groupsFor(examKey),
          progressLoader: _loadProgressMap,
          onLaunchCbtMock: widget.onLaunchCbtMock,
          onShowUpcoming: _showUpcomingNotice,
        ),
      ),
    ).then((_) => _refreshProgress());
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    if (_liveData.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isDark = widget.isDarkMode;
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7);

    final examKeys = _liveData.keys.toList();
    final candidate = examKeys.isEmpty ? null : _nextCandidate(examKeys);
    final bool anyProgress = _progress.values.any((p) => p['status'] == 'COMPLETED' || p['status'] == 'IN_PROGRESS');

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      onRefresh: () async {
        await _fetchLiveGitHubData();
        await _refreshProgress();
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
                    Text('🎯 Sectional Mocks', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.3)),
                    const SizedBox(height: 3),
                    Text(
                      'Apna target exam chuno aur real CBT pattern par set lagao',
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

          if (examKeys.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'Abhi koi exam data available nahi hai.\nInternet on karke pull-down refresh karo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: subTextColor, height: 1.6),
              ),
            )
          else ...[
            // Next Set hero
            if (candidate != null) ...[
              const SizedBox(height: 20),
              _sectionHead(
                candidate['inProgress'] == true ? '⏯️ Aadha Ruka Set' : '⏭️ Tumhara Next Set',
                candidate['inProgress'] == true ? 'RESUME' : 'AUTO SUGGEST',
                textColor,
              ),
              const SizedBox(height: 10),
              _nextHero(context, candidate),
            ] else if (anyProgress) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14532D), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎉 Badhai Ho!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      'Saare available sets complete ho gaye hain. Kisi bhi set ko Re-attempt karke apna score aur improve karo!',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],

            // Exams grid
            const SizedBox(height: 20),
            _sectionHead('🏛️ Target Exams', '${examKeys.length} EXAMS', textColor),
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
              itemCount: examKeys.length,
              itemBuilder: (ctx, i) {
                final key = examKeys[i];
                final data = _liveData[key];
                final Color color = _resolveColor(key, i);
                final counts = _examCounts(key);
                final double pct = counts.total == 0 ? 0 : counts.done / counts.total;
                return Material(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(19),
                  child: InkWell(
                    onTap: () => _openExam(ctx, key, i),
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
                            child: Center(child: Text(_examIcon(key), style: const TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _formatExamTitle(key, data),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.25 : 0.10), borderRadius: BorderRadius.circular(99)),
                            child: Text(
                              _formatExamBadge(key, data),
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.6),
                            ),
                          ),
                          const SizedBox(height: 11),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F7),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${counts.done} / ${counts.total} sets done',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: subTextColor),
                              ),
                              const Spacer(),
                              Text(
                                '${counts.total} SETS ›',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            Text(
              'Exams aur sets live content se auto-update hote hain — naya set add hote hi resumable yahi dikhega, bina app update ke.',
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

  Widget _nextHero(BuildContext context, Map<String, dynamic> candidate) {
    final String examKey = candidate['examKey'] as String;
    final int done = candidate['done'] as int;
    final int total = candidate['total'] as int;
    final bool inProgress = candidate['inProgress'] == true;
    final examTitle = _formatExamTitle(examKey, _liveData[examKey]);

    return InkWell(
      onTap: () => _launch(context, candidate['title'] as String, candidate['path'] as String),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF172554), Color(0xFF1E40AF), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E40AF).withOpacity(0.32),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(99)),
              child: Text(
                inProgress ? '✦ SET BEECH ME RUKA HAI' : '✦ NEXT SET READY HAI',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF451A03), letterSpacing: 0.8),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              candidate['title'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900, height: 1.25),
            ),
            const SizedBox(height: 4),
            Text(
              inProgress
                  ? 'Ye set aadha attempt hua hai — wahi se resume karo!'
                  : 'Yahi se apni practice aage badhao — $examTitle ka agla set.',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  '$examTitle • $done / $total sets complete',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    inProgress ? 'Resume Karo →' : 'Set Start Karo →',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF451A03)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
