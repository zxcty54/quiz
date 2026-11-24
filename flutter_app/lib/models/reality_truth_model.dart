/// Models for the "Reality Truth" collection: everyday applied science and
/// consumer awareness, 800 topics across 4 pillars.
///
/// The content lives in the public `zxcty54/content_base` repository under
/// `reality_truth/`. Two shapes are modelled here:
///
/// * [RealityCard] - the compact, bundled card index that ships inside the app
///   (`assets/data/reality_truth_cards.json`). It carries only the curiosity
///   fields (title, hook, the common belief and one myth/reality pair), so the
///   home widget works offline and the app does not grow by 3 MB.
/// * [RealityTopic] - the full topic, fetched from the repository when the user
///   actually opens one.
library;

/// One zone inside a pillar, with how many topics it holds.
class RealityZone {
  const RealityZone({required this.name, required this.count, this.image = ''});

  factory RealityZone.fromJson(Map<String, dynamic> json) {
    return RealityZone(
      name: _asStr(json['name']),
      count: _asInt(json['count']),
      image: _asStr(json['image']),
    );
  }

  final String name;
  final int count;

  /// Repository-relative path of the zone's picture, empty when it has none.
  final String image;
}

/// A pillar (🍳 Food & Kitchen Science, 🪙 Material & Market Scams, …).
///
/// `id` is the pillar id written inside the pillar's own JSON file, which is
/// the one used for matching. `declaredId` is what `subjects.json` calls it;
/// the two disagree for the pharma pillar, so both are kept and matching never
/// relies on the declared value alone.
class RealityPillar {
  const RealityPillar({
    required this.id,
    required this.declaredId,
    required this.short,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colorValue,
    required this.fileName,
    required this.jsonFile,
    required this.topicCount,
    required this.zones,
    this.image = '',
  });

  factory RealityPillar.fromJson(Map<String, dynamic> json) {
    final zones = _asList(json['zones']).map(RealityZone.fromJson).toList();
    return RealityPillar(
      id: _asStr(json['id']),
      declaredId: _asStr(json['declaredId']),
      short: _asStr(json['short']),
      title: _asStr(json['title']),
      subtitle: _asStr(json['subtitle']),
      icon: _asStr(json['icon']).isEmpty ? '🔍' : _asStr(json['icon']),
      colorValue: _asColor(json['color'], 0xFF0F766E),
      fileName: _asStr(json['fileName']),
      jsonFile: _asStr(json['jsonFile']),
      topicCount: _asInt(json['topicCount']),
      zones: zones,
      image: _asStr(json['image']),
    );
  }

  final String id;
  final String declaredId;
  final String short;
  final String title;
  final String subtitle;
  final String icon;
  final int colorValue;
  final String fileName;
  final String jsonFile;
  final int topicCount;
  final List<RealityZone> zones;

  /// Repository-relative path of the pillar's picture, empty when it has none.
  final String image;

  /// True when this pillar's topics can be fetched from the content repository.
  bool get isRemote => fileName.isNotEmpty;

  /// The declared zone list carries the images, so a zone name is looked up
  /// here even though the zones shown to the user are counted from the cards.
  String zoneImage(String zoneName) {
    if (zoneName.isEmpty) return '';
    for (final zone in zones) {
      if (zone.name == zoneName) return zone.image;
    }
    return '';
  }

  /// Matches a card's short pillar key, tolerating either id spelling.
  bool matches(String key) {
    if (key.isEmpty) return false;
    return key == short || key == id || key == declaredId;
  }
}

/// One topic as the bundled card index knows it: enough for a curiosity card,
/// not enough for the full reader.
class RealityCard {
  const RealityCard({
    required this.id,
    required this.pillar,
    required this.zone,
    required this.title,
    required this.hook,
    required this.illusion,
    required this.myth,
    required this.reality,
  });

  factory RealityCard.fromJson(Map<String, dynamic> json) {
    return RealityCard(
      id: _asStr(json['id']),
      pillar: _asStr(json['pillar']),
      zone: _asStr(json['zone']),
      title: _asStr(json['title']),
      hook: _asStr(json['hook']),
      illusion: _asStr(json['illusion']),
      myth: _asStr(json['myth']),
      reality: _asStr(json['reality']),
    );
  }

  final String id;
  final String pillar;
  final String zone;
  final String title;
  final String hook;
  final String illusion;
  final String myth;
  final String reality;

  /// A card without a title cannot be shown as a teaser.
  bool get isUsable => title.isNotEmpty;

  /// The reveal half of the card: only offered when there is something to say.
  bool get hasReveal => reality.isNotEmpty || myth.isNotEmpty;
}

/// A technical term plus its plain-language meaning.
class RealityDecoded {
  const RealityDecoded({required this.term, required this.plain});

  factory RealityDecoded.fromJson(Map<String, dynamic> json) {
    return RealityDecoded(
      term: _asStr(json['term']),
      plain: _asStr(json['aam_bhasha_mein']),
    );
  }

  final String term;
  final String plain;

  bool get isEmpty => term.isEmpty && plain.isEmpty;
}

/// A myth and the reality that replaces it.
class RealityMyth {
  const RealityMyth({required this.myth, required this.reality});

  factory RealityMyth.fromJson(Map<String, dynamic> json) {
    return RealityMyth(
      myth: _asStr(json['myth']),
      reality: _asStr(json['reality']),
    );
  }

  final String myth;
  final String reality;

  bool get isEmpty => myth.isEmpty && reality.isEmpty;
}

/// Regulator, safe limit and risk category for the topic.
class RealityStandards {
  const RealityStandards({
    required this.regulator,
    required this.safeLimit,
    required this.riskCategory,
  });

  factory RealityStandards.fromJson(Map<String, dynamic> json) {
    return RealityStandards(
      regulator: _asStr(json['regulator']),
      safeLimit: _asStr(json['safe_limit']),
      riskCategory: _asStr(json['risk_category']),
    );
  }

  final String regulator;
  final String safeLimit;
  final String riskCategory;

  bool get isEmpty =>
      regulator.isEmpty && safeLimit.isEmpty && riskCategory.isEmpty;
}

/// Immediate versus long-term effect, on the body or the pocket.
class RealityImpact {
  const RealityImpact({required this.instant, required this.longTerm});

  factory RealityImpact.fromJson(Map<String, dynamic> json) {
    return RealityImpact(
      instant: _asStr(json['turant_asar']),
      longTerm: _asStr(json['lambe_samay_ka_asar']),
    );
  }

  final String instant;
  final String longTerm;

  bool get isEmpty => instant.isEmpty && longTerm.isEmpty;
}

/// The full topic, exactly as the content repository stores it.
class RealityTopic {
  const RealityTopic({
    required this.id,
    required this.zone,
    required this.title,
    required this.hook,
    required this.illusion,
    required this.decoded,
    required this.deepExplanation,
    required this.examples,
    required this.standards,
    required this.impact,
    required this.homeChecks,
    required this.myths,
    required this.sources,
  });

  factory RealityTopic.fromJson(Map<String, dynamic> json) {
    return RealityTopic(
      id: _asStr(json['id']),
      zone: _asStr(json['zone']),
      title: _asStr(json['title']),
      hook: _asStr(json['short_hook']),
      illusion: _asStr(json['the_illusion']),
      decoded: _asList(json['chemical_or_term_decoded'])
          .map(RealityDecoded.fromJson)
          .where((item) => !item.isEmpty)
          .toList(),
      deepExplanation: _asStr(json['deep_explanation']),
      examples: _asStrList(json['real_life_examples']),
      standards: RealityStandards.fromJson(_asMap(json['standards_and_limits'])),
      impact: RealityImpact.fromJson(_asMap(json['impact_on_body_or_pocket'])),
      homeChecks: _asStrList(json['ghar_pe_kaise_check_karein']),
      myths: _asList(json['common_myths'])
          .map(RealityMyth.fromJson)
          .where((item) => !item.isEmpty)
          .toList(),
      // Sources are plain titles in this collection, not links.
      sources: _asStrList(json['sources']),
    );
  }

  final String id;
  final String zone;
  final String title;
  final String hook;
  final String illusion;
  final List<RealityDecoded> decoded;
  final String deepExplanation;
  final List<String> examples;
  final RealityStandards standards;
  final RealityImpact impact;
  final List<String> homeChecks;
  final List<RealityMyth> myths;
  final List<String> sources;

  bool get isEmpty => title.isEmpty && deepExplanation.isEmpty;

  /// `deep_explanation` is written as paragraphs separated by blank lines.
  List<String> get paragraphs => deepExplanation
      .split(RegExp(r'\n\s*\n'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

/// The bundled card index: project metadata, pillars and every card.
class RealityLibrary {
  const RealityLibrary({
    required this.projectTitle,
    required this.tagline,
    required this.languageStyle,
    required this.totalTopics,
    required this.sourceVersion,
    required this.pillars,
    required this.cards,
    required this.schedule,
    required this.scheduleIndex,
  });

  static const RealityLibrary empty = RealityLibrary(
    projectTitle: '',
    tagline: '',
    languageStyle: '',
    totalTopics: 0,
    sourceVersion: 0,
    pillars: <RealityPillar>[],
    cards: <RealityCard>[],
    schedule: <String>[],
    scheduleIndex: <String, int>{},
  );

  factory RealityLibrary.fromJson(Map<String, dynamic> json) {
    final cards = _asList(json['cards'])
        .map(RealityCard.fromJson)
        .where((card) => card.isUsable)
        .toList();

    // The schedule is the order topics unlock in, one per day. Ids that do not
    // match a card are dropped, and `gatingValid` fails open below if that
    // leaves the schedule short - a data bug must never lock the library shut.
    final known = <String>{for (final card in cards) card.id};
    final schedule = _asStrList(json['schedule']).where(known.contains).toList();
    final scheduleIndex = <String, int>{};
    for (var day = 0; day < schedule.length; day++) {
      final id = schedule[day];
      if (!scheduleIndex.containsKey(id)) scheduleIndex[id] = day;
    }

    return RealityLibrary(
      projectTitle: _asStr(json['project_title']),
      tagline: _asStr(json['project_tagline']),
      languageStyle: _asStr(json['language_style']),
      totalTopics: _asInt(json['total_topics']),
      sourceVersion: _asInt(json['source_version']),
      pillars: _asList(json['pillars']).map(RealityPillar.fromJson).toList(),
      cards: cards,
      schedule: schedule,
      scheduleIndex: scheduleIndex,
    );
  }

  final String projectTitle;
  final String tagline;
  final String languageStyle;
  final int totalTopics;
  final int sourceVersion;
  final List<RealityPillar> pillars;
  final List<RealityCard> cards;

  /// Card ids in unlock order: index 0 is day one, index 1 is day two, and so
  /// on. Round-robins the pillars and, inside a pillar, its zones.
  final List<String> schedule;
  final Map<String, int> scheduleIndex;

  bool get isEmpty => cards.isEmpty;

  /// The picture for a card: its zone's, falling back to the pillar's. Empty
  /// when neither exists, which callers treat as "render no image".
  String imageFor(RealityCard card) {
    final pillar = pillarFor(card.pillar);
    if (pillar == null) return '';
    final zone = pillar.zoneImage(card.zone);
    return zone.isNotEmpty ? zone : pillar.image;
  }

  /// How many days the collection takes to hand out completely.
  int get totalDays => schedule.isEmpty ? cards.length : schedule.length;

  /// Day-gating is only enforced when the schedule covers every card exactly
  /// once. Anything else fails open, so nobody loses access to paid-for
  /// content because of a malformed index.
  bool get gatingValid => cards.isNotEmpty && schedule.length == cards.length;

  int get pillarCount => pillars.length;

  RealityPillar? pillarFor(String key) {
    for (final pillar in pillars) {
      if (pillar.matches(key)) return pillar;
    }
    return null;
  }

  /// 0-based position of a card in the unlock schedule, or -1 when absent.
  int dayIndexOf(String cardId) => scheduleIndex[cardId] ?? -1;

  RealityCard? cardById(String id) {
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  /// The topic a 1-based day number unlocks, cycling once the schedule ends.
  RealityCard? cardAtDay(int dayNumber) {
    if (schedule.isEmpty) return null;
    var index = dayNumber - 1;
    if (index < 0) index = 0;
    return cardById(schedule[index % schedule.length]);
  }

  List<RealityCard> cardsForPillar(String key) =>
      cards.where((card) => card.pillar == key).toList();

  List<RealityCard> cardsForZone(String pillarKey, String zone) => cards
      .where((card) => card.pillar == pillarKey && card.zone == zone)
      .toList();

  /// Zone names actually used by the cards, with their counts. Used instead of
  /// the declared list because the pharma pillar declares overlapping zone
  /// names from two merged batches.
  List<RealityZone> zonesForPillar(String key) {
    final counts = <String, int>{};
    for (final card in cardsForPillar(key)) {
      if (card.zone.isEmpty) continue;
      counts[card.zone] = (counts[card.zone] ?? 0) + 1;
    }
    final images = <String, String>{
      for (final zone in pillarFor(key)?.zones ?? const <RealityZone>[])
        zone.name: zone.image,
    };
    final zones = counts.entries
        .map(
          (entry) => RealityZone(
            name: entry.key,
            count: entry.value,
            image: images[entry.key] ?? '',
          ),
        )
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return zones;
  }
}

/// Where one device has reached in its one-topic-a-day walk through the
/// collection.
///
/// The point of the pace is that the library cannot be binge-read: a device
/// that opens the app every day still needs 800 days to see everything, and a
/// device that skips a week simply finds seven topics waiting, not seven days
/// of content it can rush through in one sitting.
class RealityJourney {
  const RealityJourney({
    required this.library,
    required this.startDate,
    required this.dayNumber,
    required this.unlockedCount,
  });

  final RealityLibrary library;

  /// Day one for this device, as a local calendar date.
  final DateTime startDate;

  /// 1-based: which day of the journey today is.
  final int dayNumber;

  /// How many topics are open right now. Never exceeds [totalDays].
  final int unlockedCount;

  int get totalDays => library.totalDays;

  /// The topic unlocked today - the newest one, and the one the home widget
  /// teases.
  RealityCard? get todaysCard => library.cardAtDay(dayNumber);

  bool get isComplete => unlockedCount >= totalDays;

  /// How much of the collection is open, from 0.0 to 1.0.
  double get progress {
    if (totalDays <= 0) return 0;
    final ratio = unlockedCount / totalDays;
    if (ratio <= 0) return 0;
    if (ratio >= 1) return 1;
    return ratio;
  }

  bool isUnlocked(RealityCard card) {
    if (!library.gatingValid) return true;
    final index = library.dayIndexOf(card.id);
    return index >= 0 && index < unlockedCount;
  }

  /// The 1-based day a card opens on. Returns 0 when it has no scheduled day.
  int dayFor(RealityCard card) {
    final index = library.dayIndexOf(card.id);
    return index < 0 ? 0 : index + 1;
  }
}

String _asStr(Object? value) => value?.toString().trim() ?? '';

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

/// Reads a colour written the way Flutter spells it ("0xFF059669") or as hex.
int _asColor(Object? value, int fallback) {
  var text = _asStr(value).toLowerCase().replaceFirst('#', '');
  if (text.isEmpty) return fallback;
  text = text.replaceFirst('0x', '');
  if (text.length == 6) text = 'ff$text';
  final parsed = int.tryParse(text, radix: 16);
  return parsed == null ? fallback : parsed;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is List) return value.whereType<Map>().map(_asMap).toList();
  return <Map<String, dynamic>>[];
}

/// A list that may hold plain strings (examples, checks, sources).
List<String> _asStrList(Object? value) {
  if (value is! List) return <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}
