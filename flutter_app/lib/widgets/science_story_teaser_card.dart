import 'package:flutter/material.dart';

import '../models/science_story_model.dart';
import '../screens/science_stories_screen.dart';
import '../services/science_story_service.dart';

/// Compact home teaser for the bundled daily science story.
///
/// It shows only today's title and hook; the full read and the rest of the
/// month live behind [ScienceStoryDetailScreen] and [ScienceStoriesScreen].
/// The card renders nothing at all when the collection cannot be read, so a
/// missing asset never leaves an empty box on the home tab. While the asset is
/// still being read it shows a skeleton of the same shape, so the home feed
/// does not jump when the real card arrives.
class ScienceStoryTeaserCard extends StatefulWidget {
  final bool isDarkMode;

  const ScienceStoryTeaserCard({super.key, required this.isDarkMode});

  @override
  State<ScienceStoryTeaserCard> createState() => _ScienceStoryTeaserCardState();
}

class _ScienceStoryTeaserCardState extends State<ScienceStoryTeaserCard> {
  static const double _radius = 22;
  static const LinearGradient _surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF4338CA),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  ScienceStoryPick? _pick;
  int _dayCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    try {
      final month = await ScienceStoryService.loadMonth(now.month);
      final pick = await ScienceStoryService.pickForDate(now);
      if (!mounted) return;
      setState(() {
        _pick = pick;
        _dayCount = month.stories.length;
        _loading = false;
      });
    } catch (error) {
      // A broken or missing asset must never strand the skeleton on the home
      // tab: fall back to rendering nothing at all.
      debugPrint('Science story teaser: load failed: $error');
      if (!mounted) return;
      setState(() {
        _pick = null;
        _loading = false;
      });
    }
  }

  void _openStory(ScienceStoryPick pick) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScienceStoryDetailScreen(
          story: pick.story,
          month: pick.month,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  void _openMonth(ScienceStoryPick pick) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScienceStoriesScreen(
          month: pick.month,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  /// Rough reading time from the text the detail screen actually renders.
  /// Hinglish reads at about 900 characters a minute; the estimate is clamped
  /// so a stub story never claims "0 min" and a long one never claims an hour.
  static int _readMinutes(ScienceStory story) {
    final check = story.realityCheck;
    final int chars = story.hook.length +
        story.realLifeScene.length +
        story.centralQuestion.length +
        story.realWorldConnection.length +
        (check == null
            ? 0
            : check.established.length + check.misconception.length) +
        story.explanation
            .map((ScienceStorySection s) => s.heading.length + s.text.length)
            .fold<int>(0, (int a, int b) => a + b);
    final int minutes = (chars / 900).ceil();
    if (minutes < 1) return 1;
    if (minutes > 12) return 12;
    return minutes;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _TeaserSkeleton(isDarkMode: widget.isDarkMode, radius: _radius);
    }
    final pick = _pick;
    if (pick == null || !pick.story.isUsable) return const SizedBox.shrink();

    final ScienceStory story = pick.story;
    final ScienceStoryStatusStyle? badge =
        ScienceStoryStatusStyle.teaserBadge(story);
    final String meta = _metaLine(pick, story);
    final bool showMetaRow = meta.isNotEmpty || badge != null;
    final bool isDark = widget.isDarkMode;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: _surface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF6D28D9)
                .withValues(alpha: isDark ? 0.42 : 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: () => _openStory(pick),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Stack(
              children: <Widget>[
                const Positioned(
                  top: -48,
                  right: -34,
                  child: _Glow(size: 152, alpha: 0.20),
                ),
                const Positioned(
                  bottom: -64,
                  left: -42,
                  child: _Glow(size: 176, alpha: 0.12),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _header(story),
                      const SizedBox(height: 12),
                      Text(
                        story.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.26,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        story.hook,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.90),
                        ),
                      ),
                      if (showMetaRow) ...<Widget>[
                        const SizedBox(height: 11),
                        Row(
                          children: <Widget>[
                            if (meta.isNotEmpty)
                              Flexible(
                                child: Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                    color: Colors.white.withValues(alpha: 0.76),
                                  ),
                                ),
                              ),
                            if (badge != null) ...<Widget>[
                              if (meta.isNotEmpty) const SizedBox(width: 8),
                              _statusBadge(badge),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 13),
                      Row(
                        children: <Widget>[
                          _primaryCta(story.cta),
                          const Spacer(),
                          _monthCta(pick),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ScienceStory story) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: const Text('🔬', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'AAJ KI SCIENCE STORY',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                story.category.isEmpty ? 'Din ${story.day}' : story.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Text(
            'Din ${story.day}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// "March · 5 sections · ~3 min · 2 sources" - only the parts that exist.
  String _metaLine(ScienceStoryPick pick, ScienceStory story) {
    final List<String> parts = <String>[];
    if (pick.month >= 1 && pick.month <= _monthNames.length) {
      parts.add(_monthNames[pick.month - 1]);
    }
    if (story.explanation.isNotEmpty) {
      parts.add(
        story.explanation.length == 1
            ? '1 section'
            : '${story.explanation.length} sections',
      );
    }
    parts.add('~${_readMinutes(story)} min');
    if (story.sources.isNotEmpty) {
      parts.add(
        story.sources.length == 1
            ? '1 source'
            : '${story.sources.length} sources',
      );
    }
    return parts.join('  ·  ');
  }

  /// Colour-coded exactly like the chip on the detail screen, so an unsolved
  /// or disputed claim reads as unsettled before the story is even opened.
  Widget _statusBadge(ScienceStoryStatusStyle badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badge.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            badge.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryCta(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              label.isEmpty ? 'Puri kahani padhein' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4338CA),
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 13,
            color: Color(0xFF4338CA),
          ),
        ],
      ),
    );
  }

  Widget _monthCta(ScienceStoryPick pick) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openMonth(pick),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.calendar_month_rounded,
                size: 12,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              const SizedBox(width: 5),
              Text(
                _dayCount > 0 ? 'Saare $_dayCount din' : 'Saare din',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

/// Soft light bloom behind the card content. Painted only, never hit-tested.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: alpha),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same footprint as the real card, so the home feed does not jump when the
/// bundled month finishes loading. Purely decorative: no text, no taps.
class _TeaserSkeleton extends StatelessWidget {
  const _TeaserSkeleton({required this.isDarkMode, required this.radius});

  final bool isDarkMode;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Color base =
        isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final Color bar = isDarkMode
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFF0F172A).withValues(alpha: 0.07);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _block(36, 36, 12, bar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _bar(9, 0.42, bar),
                    const SizedBox(height: 6),
                    _bar(11, 0.26, bar),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _block(20, 46, 999, bar),
            ],
          ),
          const SizedBox(height: 14),
          _bar(16, 0.92, bar),
          const SizedBox(height: 8),
          _bar(16, 0.64, bar),
          const SizedBox(height: 10),
          _bar(11, 0.86, bar),
          const SizedBox(height: 6),
          _bar(11, 0.70, bar),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _block(34, 132, 999, bar),
              const Spacer(),
              _block(32, 96, 999, bar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(double height, double widthFactor, Color color) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }

  Widget _block(double height, double width, double radius, Color color) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
