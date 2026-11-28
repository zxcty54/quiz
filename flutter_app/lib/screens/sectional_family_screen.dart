import 'package:flutter/material.dart';

import 'sectional_exam_screen.dart';

/// sectional_mock ke folder tree ka ek node. Content_base me jitne folder aur
/// sub-folder hain, app me utne hi level bante hain — koi depth hardcoded nahi:
///
///   sectional_mock/bpsc/aedo/aptitude/set1.json
///     -> BPSC card -> AEO -> APTITUDE -> Set 1..5
///   sectional_mock/bihar_si/set1.json
///     -> BIHAR SI card -> seedha Set 1..5
class SectionalFolder {
  /// "sectional_mock/" ke baad ka poora path, jaise "bpsc/aedo/aptitude".
  final String path;
  final String name;
  final String badge;
  final String icon;
  final Color color;

  /// Naam JSON se aaya hai (folders map ya sub_exam) — tab hi set screen par
  /// yahi naam dikhta hai, warna section ka apna title.
  final bool nameFromJson;

  /// Isi folder me padi set files (leaf level).
  final List<SectionalExamGroup> groups;

  /// Sub-folders.
  final List<SectionalFolder> children;

  const SectionalFolder({
    required this.path,
    required this.name,
    required this.badge,
    required this.icon,
    required this.color,
    required this.nameFromJson,
    required this.groups,
    required this.children,
  });

  bool get isLeaf => children.isEmpty;

  int get ownSets => groups.fold<int>(0, (int s, SectionalExamGroup g) => s + g.setNums.length);

  int get totalSets => ownSets + children.fold<int>(0, (int s, SectionalFolder c) => s + c.totalSets);

  /// Kitne level neeche tak kitni section files hain.
  int get sectionCount => groups.length + children.fold<int>(0, (int s, SectionalFolder c) => s + c.sectionCount);

  List<SectionalExamGroup> get allGroups => <SectionalExamGroup>[
        ...groups,
        for (final SectionalFolder c in children) ...c.allGroups,
      ];
}

/// Ek folder ka andar: sub-folder tiles, aur agar isi folder me set files hon
/// to unka tile bhi. Sabse neeche wala level sets ki list kholta hai.
class SectionalFolderScreen extends StatefulWidget {
  final SectionalFolder folder;
  final String crumb;
  final bool isDarkMode;
  final Future<Map<String, Map<String, dynamic>>> Function() progressLoader;
  final Function(BuildContext, String, String) onLaunchCbtMock;
  final void Function(String setTitle, String notice) onShowUpcoming;

  const SectionalFolderScreen({
    super.key,
    required this.folder,
    required this.crumb,
    required this.isDarkMode,
    required this.progressLoader,
    required this.onLaunchCbtMock,
    required this.onShowUpcoming,
  });

  @override
  State<SectionalFolderScreen> createState() => _SectionalFolderScreenState();
}

class _SectionalFolderScreenState extends State<SectionalFolderScreen> {
  Map<String, Map<String, dynamic>> _progress = <String, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final Map<String, Map<String, dynamic>> data = await widget.progressLoader();
    if (!mounted) return;
    setState(() => _progress = withLegacyProgressAliases(data, widget.folder.allGroups));
  }

  int _doneIn(List<SectionalExamGroup> groups) {
    int done = 0;
    for (final SectionalExamGroup g in groups) {
      for (final int n in g.setNums) {
        if (_progress[g.launchTitle(n)]?['status'] == 'COMPLETED') done++;
      }
    }
    return done;
  }

  void _open(SectionalFolder node) {
    if (node.children.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SectionalExamScreen(
            examTitle: (node.nameFromJson || node.groups.length != 1) ? node.name : node.groups.first.uiTitle,
            badge: node.badge,
            icon: node.icon,
            color: node.color,
            isDarkMode: widget.isDarkMode,
            groups: node.allGroups,
            progressLoader: widget.progressLoader,
            onLaunchCbtMock: widget.onLaunchCbtMock,
            onShowUpcoming: widget.onShowUpcoming,
          ),
        ),
      ).then((_) => _reload());
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalFolderScreen(
          folder: node,
          crumb: widget.folder.name,
          isDarkMode: widget.isDarkMode,
          progressLoader: widget.progressLoader,
          onLaunchCbtMock: widget.onLaunchCbtMock,
          onShowUpcoming: widget.onShowUpcoming,
        ),
      ),
    ).then((_) => _reload());
  }

  void _openOwnSets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalExamScreen(
          examTitle: widget.folder.groups.length == 1 ? widget.folder.groups.first.uiTitle : widget.folder.name,
          badge: widget.folder.badge,
          icon: widget.folder.icon,
          color: widget.folder.color,
          isDarkMode: widget.isDarkMode,
          groups: widget.folder.groups,
          progressLoader: widget.progressLoader,
          onLaunchCbtMock: widget.onLaunchCbtMock,
          onShowUpcoming: widget.onShowUpcoming,
        ),
      ),
    ).then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color bg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FF);
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7);
    final SectionalFolder f = widget.folder;
    final int total = f.totalSets;
    final int done = _doneIn(f.allGroups);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          f.name,
          style: TextStyle(color: textColor, fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF1F7)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color.lerp(f.color, Colors.black, 0.25)!, f.color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(color: f.color.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Center(child: Text(f.icon, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            f.name,
                            style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900, height: 1.2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.crumb} • ${f.badge}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$done / $total sets done • ${f.sectionCount} sections',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (f.groups.isNotEmpty && f.children.isNotEmpty)
            _tile(
              name: f.groups.length == 1 ? f.groups.first.uiTitle : '${f.name} SETS',
              badge: '${f.ownSets} SETS',
              icon: '📄',
              color: f.color,
              sections: f.groups.length,
              sets: f.ownSets,
              done: _doneIn(f.groups),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardBg: cardBg,
              borderColor: borderColor,
              onTap: _openOwnSets,
            ),
          for (final SectionalFolder c in f.children)
            _tile(
              name: c.name,
              badge: c.badge,
              icon: c.icon,
              color: c.color,
              sections: c.sectionCount,
              sets: c.totalSets,
              done: _doneIn(c.allGroups),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardBg: cardBg,
              borderColor: borderColor,
              onTap: () => _open(c),
            ),
        ],
      ),
    );
  }

  Widget _tile({
    required String name,
    required String badge,
    required String icon,
    required Color color,
    required int sections,
    required int sets,
    required int done,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardBg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final double pct = sets == 0 ? 0 : done / sets;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
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
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.25 : 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$sections sections • $badge',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: subTextColor),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: subTextColor, size: 20),
                  ],
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
                  children: <Widget>[
                    Text(
                      '$done / $sets sets done',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: subTextColor),
                    ),
                    const Spacer(),
                    Text(
                      '$sets SETS ›',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
