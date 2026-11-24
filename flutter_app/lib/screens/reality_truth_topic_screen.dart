import 'package:flutter/material.dart';

import '../models/reality_truth_model.dart';
import '../services/community_safety_service.dart';
import '../services/reality_truth_service.dart';

/// The full judgement behind one Reality Truth topic.
///
/// The screen is never blank. The bundled card fields (belief, myth, reality)
/// render immediately; the full topic - decoded terms, deep explanation,
/// standards and limits, home checks, sources - streams in from the content
/// repository and replaces them. If it cannot be reached, the bundled half
/// stays on screen and says so instead of pretending to be complete.
class RealityTruthTopicScreen extends StatefulWidget {
  final RealityCard card;
  final RealityPillar pillar;
  final bool isDarkMode;

  const RealityTruthTopicScreen({
    super.key,
    required this.card,
    required this.pillar,
    required this.isDarkMode,
  });

  @override
  State<RealityTruthTopicScreen> createState() =>
      _RealityTruthTopicScreenState();
}

class _RealityTruthTopicScreenState extends State<RealityTruthTopicScreen> {
  late Future<RealityTopic?> _future;

  @override
  void initState() {
    super.initState();
    _future = RealityTruthService.fetchTopic(widget.card, widget.pillar);
  }

  Future<void> _reportMistake(BuildContext context) async {
    final reporter = await CommunitySafetyService.currentReporterHandle();
    if (!context.mounted) return;

    await CommunitySafetyService.promptAndQueueModerationReport(
      context,
      reporterHandle: reporter,
      // Reuses the existing content-error target type, so no database change is
      // needed; `source` tells the moderation queue where the report came from.
      targetType: 'question_error',
      targetId: 'reality_truth:${widget.card.id}',
      source: 'reality_truth',
      contentExcerpt: widget.card.title,
      successMessage: 'Dhanyavaad. Ye topic review ke liye bhej diya gaya.',
    );
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
    final Color accent = Color(widget.pillar.colorValue);
    final RealityCard card = widget.card;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: text,
        title: Text(
          '${widget.pillar.icon}  ${widget.pillar.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<RealityTopic?>(
        future: _future,
        builder: (context, snapshot) {
          final bool loading = snapshot.connectionState != ConnectionState.done;
          final RealityTopic? topic = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
            children: <Widget>[
              _header(card, accent),
              if (loading) _loadingRow(accent),
              if (!loading && topic == null) _offlineNotice(accent, sub),
              if (topic != null) ..._topicSections(topic, cardBg, border, text, sub, accent),
              if (topic == null) ..._cardSections(card, cardBg, border, text, sub, accent),
              const SizedBox(height: 16),
              _disclaimer(accent, sub),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: () => _reportMistake(context),
                  icon: const Text('🚩', style: TextStyle(fontSize: 12)),
                  label: const Text(
                    'Is topic mein galti report karein',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(foregroundColor: sub),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(RealityCard card, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.45), accent),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (card.zone.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                card.zone,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
            ),
          const SizedBox(height: 9),
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.3,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          if (card.hook.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              card.hook,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.93),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingRow(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 0),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Poori jaanch load ho rahi hai…',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineNotice(Color accent, Color sub) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        'Poora topic abhi load nahi ho paya (internet chahiye). Neeche bundled '
        'summary hai - dobara kholne par poori jaanch aa jaayegi.',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          height: 1.45,
          color: sub,
        ),
      ),
    );
  }

  /// What the bundled card already knows, shown when the full topic is missing.
  List<Widget> _cardSections(
    RealityCard card,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    Color accent,
  ) {
    final widgets = <Widget>[];
    if (card.illusion.isNotEmpty) {
      widgets.add(
        _block(
          icon: '🎭',
          title: 'Log yahi maante hain',
          body: card.illusion,
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
        ),
      );
    }
    if (card.myth.isNotEmpty || card.reality.isNotEmpty) {
      widgets.add(
        _mythCard(
          RealityMyth(myth: card.myth, reality: card.reality),
          cardBg,
          border,
          text,
          sub,
        ),
      );
    }
    return widgets;
  }

  List<Widget> _topicSections(
    RealityTopic topic,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    Color accent,
  ) {
    final widgets = <Widget>[];

    if (topic.illusion.isNotEmpty) {
      widgets.add(
        _block(
          icon: '🎭',
          title: 'Log yahi maante hain',
          body: topic.illusion,
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
        ),
      );
    }

    if (topic.decoded.isNotEmpty) {
      widgets.add(
        _section(
          icon: '🔤',
          title: 'Mushkil shabd, aasaan matlab',
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
          children: <Widget>[
            for (final item in topic.decoded) ...<Widget>[
              Text(
                item.term,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.plain,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                  color: text,
                ),
              ),
              if (item != topic.decoded.last) _divider(border),
            ],
          ],
        ),
      );
    }

    if (topic.paragraphs.isNotEmpty) {
      widgets.add(
        _section(
          icon: '📖',
          title: 'Asli kahani',
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
          children: <Widget>[
            for (final paragraph in topic.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  paragraph,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.62,
                    color: text,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (topic.examples.isNotEmpty) {
      widgets.add(
        _section(
          icon: '🌏',
          title: 'Real life examples',
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
          children: <Widget>[
            for (final example in topic.examples)
              _bullet(example, text, accent),
          ],
        ),
      );
    }

    if (!topic.standards.isEmpty) {
      widgets.add(
        _section(
          icon: '📏',
          title: 'Standards aur limits',
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
          children: <Widget>[
            if (topic.standards.regulator.isNotEmpty)
              _labelValue('Regulator', topic.standards.regulator, text, sub),
            if (topic.standards.safeLimit.isNotEmpty)
              _labelValue('Safe limit', topic.standards.safeLimit, text, sub),
            if (topic.standards.riskCategory.isNotEmpty)
              _labelValue(
                'Risk category',
                topic.standards.riskCategory,
                text,
                sub,
              ),
          ],
        ),
      );
    }

    if (!topic.impact.isEmpty) {
      widgets.add(
        _section(
          icon: '⚖️',
          title: 'Body ya pocket pe asar',
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
          children: <Widget>[
            if (topic.impact.instant.isNotEmpty)
              _labelValue('Turant asar', topic.impact.instant, text, sub),
            if (topic.impact.longTerm.isNotEmpty)
              _labelValue(
                'Lambe samay ka asar',
                topic.impact.longTerm,
                text,
                sub,
              ),
          ],
        ),
      );
    }

    if (topic.homeChecks.isNotEmpty) {
      widgets.add(
        _section(
          icon: '✅',
          title: 'Ghar pe kaise check karein',
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
          children: <Widget>[
            for (var index = 0; index < topic.homeChecks.length; index++)
              _numbered(
                index + 1,
                topic.homeChecks[index],
                text,
                accent,
              ),
          ],
        ),
      );
    }

    for (final myth in topic.myths) {
      widgets.add(_mythCard(myth, cardBg, border, text, sub));
    }

    if (topic.sources.isNotEmpty) {
      widgets.add(
        _section(
          icon: '📚',
          title: 'Sources',
          cardBg: cardBg,
          border: border,
          text: text,
          sub: sub,
          accent: accent,
          children: <Widget>[
            for (final source in topic.sources) _bullet(source, sub, accent),
            const SizedBox(height: 4),
            Text(
              'Is collection mein source ke naam diye gaye hain, links nahi.',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: sub,
              ),
            ),
          ],
        ),
      );
    }

    return widgets;
  }

  Widget _block({
    required String icon,
    required String title,
    required String body,
    required Color cardBg,
    required Color border,
    required Color text,
    required Color sub,
    required Color accent,
  }) {
    return _section(
      icon: icon,
      title: title,
      cardBg: cardBg,
      border: border,
      text: text,
      sub: sub,
      accent: accent,
      children: <Widget>[
        Text(
          body,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.55,
            color: text,
          ),
        ),
      ],
    );
  }

  Widget _section({
    required String icon,
    required String title,
    required Color cardBg,
    required Color border,
    required Color text,
    required Color sub,
    required Color accent,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: sub,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _mythCard(
    RealityMyth myth,
    Color cardBg,
    Color border,
    Color text,
    Color sub,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (myth.myth.isNotEmpty) ...<Widget>[
            Row(
              children: <Widget>[
                const Text('❌', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                const Text(
                  'MYTH',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              myth.myth,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: text,
              ),
            ),
          ],
          if (myth.reality.isNotEmpty) ...<Widget>[
            const SizedBox(height: 11),
            Row(
              children: <Widget>[
                const Text('✅', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                const Text(
                  'REALITY',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              myth.reality,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: text,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: sub,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String body, Color text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(
              body,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.55,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numbered(int index, String body, Color text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              body,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.55,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Color border) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: border,
    );
  }

  Widget _disclaimer(Color accent, Color sub) {
    final bool health = widget.pillar.short == 'pharma' ||
        widget.pillar.short == 'food';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        health
            ? 'Ye general awareness ke liye hai, medical advice nahi. Kisi bhi '
                  'bimari, dawai, dose ya jaanch ke baare mein faisla lene se '
                  'pehle doctor ya qualified expert se salah lein.'
            : 'Ye general awareness ke liye hai, professional advice nahi. Badi '
                  'kharidari, investment ya suraksha se jude faisle mein expert '
                  'se salah zaroor lein.',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: sub,
        ),
      ),
    );
  }
}
