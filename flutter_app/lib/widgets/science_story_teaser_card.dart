import 'package:flutter/material.dart';

import '../models/science_story_model.dart';
import '../screens/science_stories_screen.dart';
import '../services/science_story_service.dart';

/// Compact home teaser for the bundled daily science story.
///
/// It shows only today's title and hook; the full read and the rest of the
/// month live behind [ScienceStoryDetailScreen] and [ScienceStoriesScreen].
/// The card renders nothing at all when the collection cannot be read, so a
/// missing asset never leaves an empty box on the home tab.
class ScienceStoryTeaserCard extends StatefulWidget {
  final bool isDarkMode;

  const ScienceStoryTeaserCard({super.key, required this.isDarkMode});

  @override
  State<ScienceStoryTeaserCard> createState() => _ScienceStoryTeaserCardState();
}

class _ScienceStoryTeaserCardState extends State<ScienceStoryTeaserCard> {
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
    final month = await ScienceStoryService.loadMonth(now.month);
    final pick = await ScienceStoryService.pickForDate(now);
    if (!mounted) return;
    setState(() {
      _pick = pick;
      _dayCount = month.stories.length;
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final pick = _pick;
    if (_loading || pick == null) return const SizedBox.shrink();

    final ScienceStory story = pick.story;
    final ScienceStoryStatusStyle? badge =
        ScienceStoryStatusStyle.teaserBadge(story);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openStory(pick),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF4338CA),
                Color(0xFF7C3AED),
                Color(0xFFDB2777),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(11),
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
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            story.category.isEmpty
                                ? 'Din ${story.day}'
                                : story.category,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(99),
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
                ),
                const SizedBox(height: 12),
                Text(
                  story.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.28,
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
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                if (badge != null) ...<Widget>[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge.label,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Puri kahani padhein',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Color(0xFF4338CA),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _openMonth(pick),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _dayCount > 0 ? 'Saare $_dayCount din' : 'Saare din',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
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
