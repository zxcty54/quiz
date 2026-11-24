import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/science_story_model.dart';
import '../services/community_safety_service.dart';
import '../services/science_story_service.dart';

/// Label and colour for a story's `status`, shared by the home teaser and the
/// reader. Showing it is deliberate: an unsolved, disputed or disproven claim
/// must never look like an established fact.
class ScienceStoryStatusStyle {
  const ScienceStoryStatusStyle(this.label, this.color);

  final String label;
  final Color color;

  static ScienceStoryStatusStyle of(ScienceStoryStatus kind) {
    switch (kind) {
      case ScienceStoryStatus.proven:
        return const ScienceStoryStatusStyle('Proven', Color(0xFF16A34A));
      case ScienceStoryStatus.unsolved:
        return const ScienceStoryStatusStyle('Abhi unsolved', Color(0xFFF59E0B));
      case ScienceStoryStatus.divided:
        return const ScienceStoryStatusStyle(
          'Scientists divided',
          Color(0xFF0EA5E9),
        );
      case ScienceStoryStatus.disproven:
        return const ScienceStoryStatusStyle('Disproven', Color(0xFFDC2626));
      case ScienceStoryStatus.underReview:
        return const ScienceStoryStatusStyle(
          'Claim under review',
          Color(0xFFF59E0B),
        );
      case ScienceStoryStatus.notEstablished:
        return const ScienceStoryStatusStyle(
          'Established nahi',
          Color(0xFF94A3B8),
        );
      case ScienceStoryStatus.other:
        return const ScienceStoryStatusStyle('Info', Color(0xFF94A3B8));
    }
  }

  /// Teaser badge: only shown when the claim is not simply settled.
  static ScienceStoryStatusStyle? teaserBadge(ScienceStory story) {
    final kind = story.statusKind;
    if (story.status.isEmpty ||
        kind == ScienceStoryStatus.proven ||
        kind == ScienceStoryStatus.other) {
      return null;
    }
    return of(kind);
  }
}

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthName(int month) =>
    (month >= 1 && month <= 12) ? _monthNames[month - 1] : 'Month $month';

String _monthShort(int month) =>
    (month >= 1 && month <= 12) ? _monthNames[month - 1].substring(0, 3) : '$month';

/// Everything the list screen needs for one load: the month being read plus
/// which months this build actually has.
class _StoriesLoad {
  const _StoriesLoad(this.month, this.bundled);

  static const _StoriesLoad empty =
      _StoriesLoad(ScienceStoryMonth.empty, <int>[]);

  final ScienceStoryMonth month;
  final List<int> bundled;
}

/// The whole bundled month, one row per day.
class ScienceStoriesScreen extends StatefulWidget {
  final int month;
  final bool isDarkMode;

  const ScienceStoriesScreen({
    super.key,
    required this.month,
    required this.isDarkMode,
  });

  @override
  State<ScienceStoriesScreen> createState() => _ScienceStoriesScreenState();
}

class _ScienceStoriesScreenState extends State<ScienceStoriesScreen> {
  late int _month;
  late Future<_StoriesLoad> _future;

  @override
  void initState() {
    super.initState();
    _month = widget.month;
    _future = _load(_month);
  }

  Future<_StoriesLoad> _load(int month) async {
    final bundled = await ScienceStoryService.bundledMonths();
    final data = await ScienceStoryService.loadMonth(month);
    return _StoriesLoad(data, bundled);
  }

  /// Past and current months open freely. A month that has not started yet only
  /// says when it unlocks, so tomorrow's story stays worth coming back for.
  void _selectMonth(int month, bool locked) {
    if (month == _month) return;
    if (locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_monthName(month)} ki stories 1 ${_monthName(month)} ko khulengi.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _month = month;
      _future = _load(month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color border =
        isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7);
    final Color text = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color sub =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: text,
        title: const Text(
          'Science Stories',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<_StoriesLoad>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final load = snapshot.data ?? _StoriesLoad.empty;
          final month = load.month;
          if (month.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Is waqt stories load nahi ho payi. App update ke baad dobara '
                  'try karein.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sub,
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: <Widget>[
              _monthSelector(load.bundled, cardBg, border, text, sub),
              _header(month, cardBg, border, text, sub),
              const SizedBox(height: 14),
              for (final story in month.stories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _row(story, month, cardBg, border, text, sub, isDark),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Month switcher. Only months bundled in this build are listed; the ones
  /// that have not started yet carry a lock. Hidden while a single month ships.
  Widget _monthSelector(
    List<int> bundled,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
  ) {
    if (bundled.length < 2) return const SizedBox.shrink();

    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: bundled.length,
          separatorBuilder: (context, index) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final month = bundled[index];
            final locked = ScienceStoryService.isLocked(month, now);
            return _monthChip(
              label: locked ? '\u{1F512} ${_monthShort(month)}' : _monthShort(month),
              selected: month == _month,
              locked: locked,
              cardBg: cardBg,
              border: border,
              text: text,
              sub: sub,
              onTap: () => _selectMonth(month, locked),
            );
          },
        ),
      ),
    );
  }

  Widget _monthChip({
    required String label,
    required bool selected,
    required bool locked,
    required Color cardBg,
    required Color border,
    required Color text,
    required Color sub,
    required VoidCallback onTap,
  }) {
    const Color accent = Color(0xFF4338CA);
    return Material(
      color: selected ? accent : cardBg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? accent : border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : (locked ? sub : text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    ScienceStoryMonth month,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF4338CA), Color(0xFF7C3AED)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            month.collection.isEmpty
                ? '365 Din, 365 Science Stories'
                : month.collection,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${_monthName(month.month)}  •  ${month.stories.length} din  •  '
            '${month.language.isEmpty ? 'Easy Hinglish' : month.language}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          if (month.usedFallback) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Month ${month.requestedMonth} ka pack is build mein nahi hai, '
                'isliye month ${month.month} ki stories dikh rahi hain.',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.95),
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Har story ke saath sources aur reality check diya gaya hai.',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    ScienceStory story,
    ScienceStoryMonth month,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    bool isDark,
  ) {
    final ScienceStoryStatusStyle style =
        ScienceStoryStatusStyle.of(story.statusKind);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ScienceStoryDetailScreen(
                story: story,
                month: month.month,
                isDarkMode: isDark,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  '${story.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: style.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            story.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: sub,
                            ),
                          ),
                        ),
                        if (story.status.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: style.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              style.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: style.color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: sub.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full read for one day: scene, question, explanation, reality check and
/// the sources behind the claim.
class ScienceStoryDetailScreen extends StatelessWidget {
  final ScienceStory story;
  final int month;
  final bool isDarkMode;

  const ScienceStoryDetailScreen({
    super.key,
    required this.story,
    required this.month,
    required this.isDarkMode,
  });

  Future<void> _openSource(ScienceStorySource source) async {
    if (source.url.isEmpty) return;
    final uri = Uri.parse(source.url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('Science story: could not open ${source.url}');
      }
    } catch (error) {
      debugPrint('Science story: source link failed: $error');
    }
  }

  Future<void> _reportMistake(BuildContext context) async {
    final reporter = await CommunitySafetyService.currentReporterHandle();
    if (!context.mounted) return;

    await CommunitySafetyService.promptAndQueueModerationReport(
      context,
      reporterHandle: reporter,
      // Reuses the existing content-error target type, so no database change
      // is needed; `source` tells the moderation queue where it came from.
      targetType: 'question_error',
      targetId: 'science_story:m$month-d${story.day}',
      source: 'science_story',
      contentExcerpt: story.title,
      successMessage: 'Dhanyavaad. Ye story review ke liye bhej di gayi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = isDarkMode;
    final Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color border =
        isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7);
    final Color text = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color sub =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final ScienceStoryStatusStyle status =
        ScienceStoryStatusStyle.of(story.statusKind);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 190,
            backgroundColor: const Color(0xFF4338CA),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 46, right: 16, bottom: 14),
              title: Text(
                'Din ${story.day}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF4338CA),
                      Color(0xFF7C3AED),
                      Color(0xFFDB2777),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 62, 18, 44),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (story.category.isNotEmpty)
                      Text(
                        story.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      story.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                if (story.status.isNotEmpty)
                  _pill(status.label, status.color, isDark),
                // Some verdicts say more than a short label can carry
                // ("Strong evidence: unseen gravitating matter; particle
                // identity unresolved"), so the full text is shown too rather
                // than flattened to "Info".
                if (_hasStatusDetail(story)) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    story.status,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
                if (story.hook.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    story.hook,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                ],
                if (story.realLifeScene.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  _block(
                    icon: '🌏',
                    title: 'Real life scene',
                    body: story.realLifeScene,
                    cardBg: cardBg,
                    border: border,
                    text: text,
                    sub: sub,
                  ),
                ],
                if (story.centralQuestion.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4338CA).withValues(alpha: isDark ? 0.22 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4338CA).withValues(alpha: isDark ? 0.45 : 0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '❓ CENTRAL SAWAAL',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          story.centralQuestion,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.45,
                            color: isDark ? Colors.white : const Color(0xFF312E81),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                for (final section in story.explanation) ...<Widget>[
                  const SizedBox(height: 14),
                  _block(
                    icon: '📖',
                    title: section.heading,
                    body: section.text,
                    cardBg: cardBg,
                    border: border,
                    text: text,
                    sub: sub,
                  ),
                ],
                if (story.realWorldConnection.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _block(
                    icon: '🔗',
                    title: 'Real world connection',
                    body: story.realWorldConnection,
                    cardBg: cardBg,
                    border: border,
                    text: text,
                    sub: sub,
                  ),
                ],
                if (story.realityCheck != null &&
                    !story.realityCheck!.isEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  const Text(
                    'REALITY CHECK',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (story.realityCheck!.established.isNotEmpty)
                    _checkRow(
                      icon: Icons.verified_rounded,
                      label: 'Jo sabit hai',
                      body: story.realityCheck!.established,
                      color: const Color(0xFF16A34A),
                      isDark: isDark,
                    ),
                  if (story.realityCheck!.misconception.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _checkRow(
                      icon: Icons.cancel_rounded,
                      label: 'Aam galat samajh',
                      body: story.realityCheck!.misconception,
                      color: const Color(0xFFDC2626),
                      isDark: isDark,
                    ),
                  ],
                ],
                if (story.sources.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  const Text(
                    'SOURCES',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final source in story.sources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: source.url.isEmpty
                              ? null
                              : () => _openSource(source),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.menu_book_rounded,
                                  size: 17,
                                  color: Color(0xFF4338CA),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    source.title.isEmpty
                                        ? source.url
                                        : source.title,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: text,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 14,
                                  color: sub.withValues(alpha: 0.8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _reportMistake(context),
                    icon: const Icon(Icons.flag_outlined, size: 15),
                    label: const Text('Is story mein galti report karein'),
                    style: TextButton.styleFrom(
                      foregroundColor: sub,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// True when the raw `status` text adds detail beyond the short label.
  bool _hasStatusDetail(ScienceStory story) {
    if (story.status.isEmpty) return false;
    if (story.statusKind == ScienceStoryStatus.other) return true;
    return story.status.contains(':') || story.status.contains(';');
  }

  Widget _pill(String label, Color color, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.24 : 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block({
    required String icon,
    required String title,
    required String body,
    required Color cardBg,
    required Color border,
    required Color text,
    required Color sub,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: text,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.62,
              color: sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkRow({
    required IconData icon,
    required String label,
    required String body,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
