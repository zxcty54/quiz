import 'package:flutter/material.dart';

import '../models/reality_truth_model.dart';
import '../services/reality_truth_service.dart';
import 'reality_truth_topic_screen.dart';

/// The "Reality Truth" hub: 4 pillars, their zones and all 800 topics.
///
/// Everything is listed, but only what the journey has handed out so far is
/// open. The pace is one topic a day (see [RealityJourney]), so the collection
/// cannot be read in one sitting: later topics stay visible behind a lock with
/// the day they open on, which is deliberate - seeing what is coming is what
/// brings someone back tomorrow.
///
/// Pillars and zones render from the bundled card index, so this screen is
/// instant and works offline. Only opening a topic reaches the network.
class RealityTruthHubScreen extends StatefulWidget {
  final bool isDarkMode;

  const RealityTruthHubScreen({super.key, required this.isDarkMode});

  @override
  State<RealityTruthHubScreen> createState() => _RealityTruthHubScreenState();
}

class _RealityTruthHubScreenState extends State<RealityTruthHubScreen> {
  late Future<RealityJourney> _future;

  @override
  void initState() {
    super.initState();
    _future = RealityTruthService.journey();
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
          'Reality Truth',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<RealityJourney>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final journey = snapshot.data;
          if (journey == null || journey.library.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Reality Truth content is waqt load nahi ho paya. App update '
                  'ke baad dobara try karein.',
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

          final library = journey.library;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: <Widget>[
              _intro(journey, text, sub),
              const SizedBox(height: 14),
              for (final pillar in library.pillars)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _pillarCard(
                    journey,
                    pillar,
                    cardBg,
                    border,
                    text,
                    sub,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Roz ek naya topic khulta hai, isliye poora collection ek baithak '
                'mein padha nahi ja sakta. Jo abhi band hai wo apne din apne aap '
                'khul jaayega. Topic kholne par poori jaanch internet se aati '
                'hai aur device par cache ho jaati hai, isliye baad mein offline '
                'bhi khulti hai. Ye section general awareness ke liye hai - kisi '
                'bimari, dawai ya investment ka faisla lene se pehle expert se '
                'salah zaroor lein.',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: sub,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _intro(RealityJourney journey, Color text, Color sub) {
    final total = journey.totalDays;
    final library = journey.library;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0F766E), Color(0xFF1E3A8A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            library.projectTitle.isEmpty ? 'Reality Truth' : library.projectTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: Colors.white,
            ),
          ),
          if (library.tagline.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              library.tagline,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              Text(
                total > 0 ? 'DIN ${journey.dayNumber} / $total' : 'DIN ${journey.dayNumber}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  journey.isComplete
                      ? 'Sab topics khul chuke hain'
                      : '${journey.unlockedCount} khule  •  roz 1 naya',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: journey.progress,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${library.pillarCount} pillars  •  Simple Hinglish',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillarCard(
    RealityJourney journey,
    RealityPillar pillar,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
  ) {
    final Color accent = Color(pillar.colorValue);
    final cards = journey.library.cardsForPillar(pillar.short);
    final opened = cards.where(journey.isUnlocked).length;
    final zoneCount = journey.library.zonesForPillar(pillar.short).length;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RealityPillarScreen(
                journey: journey,
                pillar: pillar,
                isDarkMode: widget.isDarkMode,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(pillar.icon, style: const TextStyle(fontSize: 21)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pillar.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: text,
                      ),
                    ),
                    if (pillar.subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        pillar.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: sub,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: <Widget>[
                        _chip(
                          opened >= cards.length && cards.isNotEmpty
                              ? '$opened topics khule'
                              : '$opened / ${cards.length} khule',
                          accent,
                        ),
                        const SizedBox(width: 6),
                        _chip('$zoneCount zones', accent),
                        const Spacer(),
                        Text(
                          '→',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: accent,
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
      ),
    );
  }

  Widget _chip(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }
}

/// One pillar: its zones, each with its topics, in the order they unlock.
///
/// Zones are counted from the cards themselves rather than from the declared
/// list, because the personal-care pillar declares overlapping zone names left
/// over from two merged content batches.
class RealityPillarScreen extends StatelessWidget {
  final RealityJourney journey;
  final RealityPillar pillar;
  final bool isDarkMode;

  const RealityPillarScreen({
    super.key,
    required this.journey,
    required this.pillar,
    required this.isDarkMode,
  });

  void _explainLock(BuildContext context, int day) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          day > 0
              ? 'Ye topic din $day par khulega. Roz ek naya topic aata hai.'
              : 'Ye topic abhi khula nahi hai. Roz ek naya topic aata hai.',
        ),
      ),
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
    final Color accent = Color(pillar.colorValue);
    final library = journey.library;

    final rows = <_Row>[];
    for (final zone in library.zonesForPillar(pillar.short)) {
      final cards = library.cardsForZone(pillar.short, zone.name)
        // By unlock day, so what is already open sits above what is coming and
        // the rest reads as a queue rather than a wall of locks.
        ..sort((a, b) => journey.dayFor(a).compareTo(journey.dayFor(b)));
      rows.add(
        _Row(
          zone: zone,
          zoneOpened: cards.where(journey.isUnlocked).length,
          zoneTotal: cards.length,
        ),
      );
      for (final card in cards) {
        final day = journey.dayFor(card);
        rows.add(
          _Row(
            card: card,
            day: day,
            unlocked: journey.isUnlocked(card),
            isToday: day == journey.dayNumber,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: text,
        title: Text(
          '${pillar.icon}  ${pillar.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      body: rows.isEmpty
          ? Center(
              child: Text(
                'Is pillar mein abhi koi topic nahi mila.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: sub,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row.isZone) {
                  return _zoneHeader(row, accent, text, sub);
                }
                return _topicRow(context, row, cardBg, border, text, sub, accent);
              },
            ),
    );
  }

  Widget _zoneHeader(_Row row, Color accent, Color text, Color sub) {
    final zone = row.zone;
    final name = zone == null ? '' : zone.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 15,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.1,
                color: text,
              ),
            ),
          ),
          Text(
            '${row.zoneOpened} / ${row.zoneTotal}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicRow(
    BuildContext context,
    _Row row,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    Color accent,
  ) {
    final card = row.card;
    if (card == null) return const SizedBox.shrink();
    final bool open = row.unlocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: open
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RealityTruthTopicScreen(
                        card: card,
                        pillar: pillar,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  );
                }
              : () => _explainLock(context, row.day),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: open ? border : accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: <Widget>[
                if (!open) ...<Widget>[
                  Text('🔒', style: TextStyle(fontSize: 12, color: sub)),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          // Locked titles stay readable but visibly dimmer, so
                          // the list does not turn into a wall of grey.
                          color: open
                              ? text
                              : text.withValues(alpha: isDarkMode ? 0.5 : 0.45),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        open
                            ? (row.isToday
                                  ? 'Aaj khula hai  •  ${card.hook}'
                                  : card.hook)
                            : 'Din ${row.day} par khulega',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: open ? FontWeight.w600 : FontWeight.w800,
                          color: open ? sub : accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (row.isToday && open)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'AAJ',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (row.isToday && open) const SizedBox(width: 6),
                Text(
                  open ? '→' : '🔒',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: open ? accent : sub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Either a zone header or a topic row, flattened into one lazily built list.
class _Row {
  const _Row({
    this.zone,
    this.zoneOpened = 0,
    this.zoneTotal = 0,
    this.card,
    this.day = 0,
    this.unlocked = true,
    this.isToday = false,
  });

  final RealityZone? zone;
  final int zoneOpened;
  final int zoneTotal;

  final RealityCard? card;
  final int day;
  final bool unlocked;
  final bool isToday;

  bool get isZone => zone != null;
}
