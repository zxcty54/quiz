import 'package:flutter/material.dart';

import '../models/reality_truth_model.dart';
import '../screens/reality_truth_hub_screen.dart';
import '../screens/reality_truth_topic_screen.dart';
import '../services/reality_truth_service.dart';

/// The daily "Reality Check" card on the home tab.
///
/// Built around one curiosity mechanic: it states the belief most people hold
/// (`the_illusion`) and keeps the answer behind a tap. The reveal shows the
/// myth and the reality that replaces it, and the full judgement - decoded
/// terms, standards and limits, how to check at home - sits one tap further in
/// [RealityTruthTopicScreen].
///
/// Everything it needs to render is bundled, so it works on a first launch with
/// no network. The pillar colour changes with the day's topic, so the card does
/// not look identical every day.
class RealityTruthTeaserCard extends StatefulWidget {
  final bool isDarkMode;

  const RealityTruthTeaserCard({super.key, required this.isDarkMode});

  @override
  State<RealityTruthTeaserCard> createState() => _RealityTruthTeaserCardState();
}

class _RealityTruthTeaserCardState extends State<RealityTruthTeaserCard> {
  late Future<_TeaserLoad> _future;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TeaserLoad> _load() async {
    final library = await RealityTruthService.loadLibrary();
    final card = await RealityTruthService.pickForDate(DateTime.now());
    return _TeaserLoad(library, card);
  }

  void _toggleReveal() {
    setState(() => _revealed = !_revealed);
  }

  void _openTopic(RealityCard card, RealityPillar pillar) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RealityTruthTopicScreen(
          card: card,
          pillar: pillar,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  void _openHub() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RealityTruthHubScreen(isDarkMode: widget.isDarkMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TeaserLoad>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final load = snapshot.data;
        final card = load?.card;
        if (card == null) return const SizedBox.shrink();

        final library = load?.library ?? RealityLibrary.empty;
        final pillar = library.pillarFor(card.pillar);
        final base = Color(pillar?.colorValue ?? 0xFF0F766E);
        final deep = Color.alphaBlend(
          Colors.black.withValues(alpha: 0.45),
          base,
        );
        final total = library.cards.isEmpty
            ? library.totalTopics
            : library.cards.length;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[base, deep],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: deep.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '${pillar?.icon ?? '🔍'}  AAJ KA REALITY CHECK',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const Spacer(),
                      if (card.zone.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            card.zone,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    card.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.28,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                  if (card.illusion.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'LOG YAHI MAANTE HAIN',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.illusion,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.42,
                              color: Colors.white.withValues(alpha: 0.97),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (card.hasReveal) ...<Widget>[
                    const SizedBox(height: 10),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _revealed
                          ? _revealBlock(card)
                          : _revealButton(base),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _primaryButton(
                          label: 'Poori jaanch padhein',
                          onTap: pillar == null
                              ? null
                              : () => _openTopic(card, pillar),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ghostButton(
                        label: total > 0 ? '$total topics' : 'Sab topics',
                        onTap: _openHub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _revealButton(Color base) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: _toggleReveal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('👁', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 7),
                Text(
                  'Sach dekho',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: base,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _revealBlock(RealityCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (card.myth.isNotEmpty)
          _revealRow(
            tag: '❌  MYTH',
            body: card.myth,
            alpha: 0.13,
          ),
        if (card.myth.isNotEmpty && card.reality.isNotEmpty)
          const SizedBox(height: 7),
        if (card.reality.isNotEmpty)
          _revealRow(
            tag: '✅  ASLI SACH',
            body: card.reality,
            alpha: 0.26,
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _toggleReveal,
            child: Text(
              'chhupao',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.75),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _revealRow({
    required String tag,
    required String body,
    required double alpha,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            tag,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.98),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                '→',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ghostButton({required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's card together with the library it came from, so the card can name
/// its pillar and colour itself without a second load.
class _TeaserLoad {
  const _TeaserLoad(this.library, this.card);

  final RealityLibrary library;
  final RealityCard? card;
}
