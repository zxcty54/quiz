import 'package:flutter/material.dart';

import '../models/reality_truth_model.dart';
import '../services/reality_truth_service.dart';
import 'reality_truth_topic_screen.dart';

/// The "Reality Truth" hub: 4 pillars, their zones and all 800 topics.
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
  late Future<RealityLibrary> _future;

  @override
  void initState() {
    super.initState();
    _future = RealityTruthService.loadLibrary();
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
      body: FutureBuilder<RealityLibrary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final library = snapshot.data ?? RealityLibrary.empty;
          if (library.isEmpty) {
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: <Widget>[
              _intro(library, text, sub),
              const SizedBox(height: 14),
              for (final pillar in library.pillars)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _pillarCard(
                    pillar,
                    library,
                    cardBg,
                    border,
                    text,
                    sub,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Topic kholne par poori jaanch internet se aati hai aur device '
                'par cache ho jaati hai, isliye baad mein offline bhi khulti '
                'hai. Ye section general awareness ke liye hai - kisi bimari, '
                'dawai ya investment ka faisla lene se pehle expert se salah '
                'zaroor lein.',
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

  Widget _intro(RealityLibrary library, Color text, Color sub) {
    final int total = library.cards.isEmpty
        ? library.totalTopics
        : library.cards.length;
    final String style = library.languageStyle.isEmpty
        ? 'Simple Hinglish'
        : library.languageStyle;
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
            library.projectTitle.isEmpty
                ? 'Reality Truth'
                : library.projectTitle,
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
          const SizedBox(height: 10),
          Text(
            '$total topics  •  ${library.pillarCount} pillars  •  $style',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillarCard(
    RealityPillar pillar,
    RealityLibrary library,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
  ) {
    final Color accent = Color(pillar.colorValue);
    final int count = library.cardsForPillar(pillar.short).length;
    final int zoneCount = library.zonesForPillar(pillar.short).length;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RealityPillarScreen(
                pillar: pillar,
                library: library,
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
                        _chip('$count topics', accent),
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

/// One pillar: its zones, each with its topics.
///
/// Zones are counted from the cards themselves rather than from the declared
/// list, because the personal-care pillar declares overlapping zone names left
/// over from two merged content batches.
class RealityPillarScreen extends StatelessWidget {
  final RealityPillar pillar;
  final RealityLibrary library;
  final bool isDarkMode;

  const RealityPillarScreen({
    super.key,
    required this.pillar,
    required this.library,
    required this.isDarkMode,
  });

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

    final items = <_PillarListItem>[];
    for (final zone in library.zonesForPillar(pillar.short)) {
      items.add(_PillarListItem(zone: zone));
      for (final card in library.cardsForZone(pillar.short, zone.name)) {
        items.add(_PillarListItem(card: card));
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
      body: items.isEmpty
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
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item.isZone) {
                  return _zoneHeader(item.zone!, accent, text, sub);
                }
                return _topicRow(
                  context,
                  item.card!,
                  cardBg,
                  border,
                  text,
                  sub,
                  accent,
                );
              },
            ),
    );
  }

  Widget _zoneHeader(
    RealityZone zone,
    Color accent,
    Color text,
    Color sub,
  ) {
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
              zone.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.1,
                color: text,
              ),
            ),
          ),
          Text(
            '${zone.count}',
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
    RealityCard card,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RealityTruthTopicScreen(
                  card: card,
                  pillar: pillar,
                  isDarkMode: isDarkMode,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: border),
            ),
            child: Row(
              children: <Widget>[
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
                          color: text,
                        ),
                      ),
                      if (card.hook.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          card.hook,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '→',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: accent,
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

/// Either a zone header or a topic row in one flat, lazily built list.
class _PillarListItem {
  const _PillarListItem({this.zone, this.card});

  final RealityZone? zone;
  final RealityCard? card;

  bool get isZone => zone != null;
}
