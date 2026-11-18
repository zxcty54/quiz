/// Parsing for the bundled "365 Din, 365 Science Stories" collection.
///
/// Each month ships as one JSON file in `assets/data/` holding a `topics` list
/// with a single entry per day. Every field is read defensively: the content
/// files are written and edited by hand, so a missing or renamed key has to
/// produce an empty value rather than a crash on someone's home screen.
library;

/// How settled the claim inside a story is.
///
/// The label is always shown to the reader so that an unsolved, disputed or
/// disproven claim is never mistaken for an established fact.
enum ScienceStoryStatus {
  proven,
  unsolved,
  divided,
  disproven,
  underReview,
  notEstablished,
  other,
}

/// One reference behind a story. Tapping it opens the publisher's own page.
class ScienceStorySource {
  const ScienceStorySource({required this.title, required this.url});

  final String title;
  final String url;

  factory ScienceStorySource.fromJson(Map<String, dynamic> json) {
    return ScienceStorySource(
      title: (json['title'] ?? '').toString().trim(),
      url: (json['url'] ?? '').toString().trim(),
    );
  }
}

/// One headed paragraph of the explanation. Stories carry two to four of these.
class ScienceStorySection {
  const ScienceStorySection({required this.heading, required this.text});

  final String heading;
  final String text;

  factory ScienceStorySection.fromJson(Map<String, dynamic> json) {
    return ScienceStorySection(
      heading: (json['heading'] ?? '').toString().trim(),
      text: (json['text'] ?? '').toString().trim(),
    );
  }
}

/// What is settled about the claim, and the wrong idea it replaces.
class ScienceStoryRealityCheck {
  const ScienceStoryRealityCheck({
    required this.established,
    required this.misconception,
  });

  final String established;
  final String misconception;

  bool get isEmpty => established.isEmpty && misconception.isEmpty;
}

/// A single day of the collection.
class ScienceStory {
  const ScienceStory({
    required this.day,
    required this.category,
    required this.title,
    required this.hook,
    required this.cta,
    required this.realLifeScene,
    required this.centralQuestion,
    required this.explanation,
    required this.realWorldConnection,
    required this.realityCheck,
    required this.status,
    required this.sources,
  });

  final int day;
  final String category;
  final String title;
  final String hook;
  final String cta;
  final String realLifeScene;
  final String centralQuestion;
  final List<ScienceStorySection> explanation;
  final String realWorldConnection;
  final ScienceStoryRealityCheck? realityCheck;
  final String status;
  final List<ScienceStorySource> sources;

  factory ScienceStory.fromJson(Map<String, dynamic> json) {
    final card = _asMap(json['card']);
    final detail = _asMap(json['detail']);
    final check = _asMap(detail['reality_check']);

    return ScienceStory(
      day: _asInt(json['day']),
      category: (json['category'] ?? '').toString().trim(),
      title: (card['title'] ?? '').toString().trim(),
      hook: (card['hook'] ?? '').toString().trim(),
      cta: (card['cta'] ?? '').toString().trim().isEmpty
          ? 'Puri kahani padhein'
          : (card['cta'] ?? '').toString().trim(),
      realLifeScene: (detail['real_life_scene'] ?? '').toString().trim(),
      centralQuestion: (detail['central_question'] ?? '').toString().trim(),
      explanation: _asList(detail['explanation'])
          .map(ScienceStorySection.fromJson)
          .toList(),
      realWorldConnection:
          (detail['real_world_connection'] ?? '').toString().trim(),
      realityCheck: check.isEmpty
          ? null
          : ScienceStoryRealityCheck(
              established: (check['established'] ?? '').toString().trim(),
              misconception: (check['misconception'] ?? '').toString().trim(),
            ),
      status: (detail['status'] ?? '').toString().trim(),
      sources: _asList(detail['sources'])
          .map(ScienceStorySource.fromJson)
          .toList(),
    );
  }

  /// A story with neither a title nor a hook cannot be shown anywhere.
  bool get isUsable => title.isNotEmpty || hook.isNotEmpty;

  /// `status` is free text in the content files ("Proven", "Still Unsolved",
  /// "Proven: sunlight travel time", …), so it is matched by keyword.
  /// "disproven" is tested first because it also contains "proven".
  ScienceStoryStatus get statusKind {
    final text = status.toLowerCase();
    if (text.isEmpty) return ScienceStoryStatus.other;
    if (text.contains('disproven')) return ScienceStoryStatus.disproven;
    if (text.contains('proven')) return ScienceStoryStatus.proven;
    if (text.contains('unsolved')) return ScienceStoryStatus.unsolved;
    if (text.contains('divided')) return ScienceStoryStatus.divided;
    if (text.contains('review')) return ScienceStoryStatus.underReview;
    if (text.contains('not established')) {
      return ScienceStoryStatus.notEstablished;
    }
    return ScienceStoryStatus.other;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asList(Object? value) {
    if (value is List) {
      return value.whereType<Map>().map(_asMap).toList();
    }
    return <Map<String, dynamic>>[];
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? 0;
  }
}
