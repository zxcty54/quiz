import 'package:flutter/material.dart';

import 'sectional_exam_screen.dart';

/// Sectional hub ka level 2: ek exam family ke andar ke folder.
/// Jaise BPSC ke andar CCE aur AEO, ya BSSC ke andar CGL / INTER / LDC.
/// Naam, badge, icon aur rang sab sectional_data.json se aate hain.
class SectionalSubExam {
  final String id;
  final String name;
  final String badge;
  final String icon;
  final Color color;
  final List<SectionalExamGroup> groups;

  const SectionalSubExam({
    required this.id,
    required this.name,
    required this.badge,
    required this.icon,
    required this.color,
    required this.groups,
  });

  int get totalSets => groups.fold<int>(0, (int s, SectionalExamGroup g) => s + g.setNums.length);
}

/// Folder chunne wala screen: BPSC -> CCE / AEO -> sections.
class SectionalFamilyScreen extends StatefulWidget {
  final String familyTitle;
  final String familyBadge;
  final String familyIcon;
  final Color color;
  final bool isDarkMode;
  final List<SectionalSubExam> subs;
  final Future<Map<String, Map<String, dynamic>>> Function() progressLoader;
  final Function(BuildContext, String, String) onLaunchCbtMock;
  final void Function(String setTitle, String notice) onShowUpcoming;

  const SectionalFamilyScreen({
    super.key,
    required this.familyTitle,
    required this.familyBadge,
    required this.familyIcon,
    required this.color,
    required this.isDarkMode,
    required this.subs,
    required this.progressLoader,
    required this.onLaunchCbtMock,
    required this.onShowUpcoming,
  });

  @override
  State<SectionalFamilyScreen> createState() => _SectionalFamilyScreenState();
}

class _SectionalFamilyScreenState extends State<SectionalFamilyScreen> {
  Map<String, Map<String, dynamic>> _progress = <String, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final Map<String, Map<String, dynamic>> data = await widget.progressLoader();
    if (!mounted) return;
    setState(() {
      _progress = withLegacyProgressAliases(data, <SectionalExamGroup>[
        for (final SectionalSubExam s in widget.subs) ...s.groups,
      ]);
    });
  }

  int _doneOf(SectionalSubExam sub) {
    int done = 0;
    for (final SectionalExamGroup g in sub.groups) {
      for (final int n in g.setNums) {
        if (_progress[g.launchTitle(n)]?['status'] == 'COMPLETED') done++;
      }
    }
    return done;
  }

  int get _totalSets => widget.subs.fold<int>(0, (int s, SectionalSubExam e) => s + e.totalSets);

  int get _doneSets => widget.subs.fold<int>(0, (int s, SectionalSubExam e) => s + _doneOf(e));

  void _open(SectionalSubExam sub) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalExamScreen(
          examTitle: sub.name,
          badge: sub.badge,
          icon: sub.icon,
          color: sub.color,
          isDarkMode: widget.isDarkMode,
          groups: sub.groups,
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
    final int total = _totalSets;
    final int done = _doneSets;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.familyTitle,
          style: TextStyle(color: textColor, fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF1F7)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color.lerp(widget.color, Colors.black, 0.25)!, widget.color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(color: widget.color.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Center(child: Text(widget.familyIcon, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.familyTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900, height: 1.2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.subs.length} EXAMS • ${widget.familyBadge}',
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
                  '$done / $total sets done',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < widget.subs.length; i++)
            _subCard(widget.subs[i], isDark, textColor, subTextColor, cardBg, borderColor),
        ],
      ),
    );
  }

  Widget _subCard(
    SectionalSubExam sub,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardBg,
    Color borderColor,
  ) {
    final int total = sub.totalSets;
    final int done = _doneOf(sub);
    final double pct = total == 0 ? 0 : done / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: () => _open(sub),
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
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: sub.color.withValues(alpha: isDark ? 0.25 : 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(child: Text(sub.icon, style: const TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${sub.groups.length} sections • ${sub.badge}',
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
                    valueColor: AlwaysStoppedAnimation<Color>(sub.color),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$done / $total sets done',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: subTextColor),
                    ),
                    const Spacer(),
                    Text(
                      '$total SETS ›',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: sub.color),
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
