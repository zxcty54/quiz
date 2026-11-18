import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/science_story_model.dart';

/// One month of stories plus where it actually came from.
///
/// `usedFallback` is true when the requested month is not bundled yet and the
/// library served month 01 instead. The UI says so out loud rather than
/// pretending the stories belong to the current month.
class ScienceStoryMonth {
  const ScienceStoryMonth({
    required this.requestedMonth,
    required this.month,
    required this.collection,
    required this.language,
    required this.stories,
  });

  static const ScienceStoryMonth empty = ScienceStoryMonth(
    requestedMonth: 0,
    month: 0,
    collection: '',
    language: '',
    stories: <ScienceStory>[],
  );

  final int requestedMonth;
  final int month;
  final String collection;
  final String language;
  final List<ScienceStory> stories;

  bool get usedFallback => month != requestedMonth;
  bool get isEmpty => stories.isEmpty;
}

/// The story chosen for one calendar day, with the month it came from.
class ScienceStoryPick {
  const ScienceStoryPick({
    required this.story,
    required this.month,
    required this.usedFallback,
  });

  final ScienceStory story;
  final int month;
  final bool usedFallback;
}

/// Reads the bundled "365 Din" collection from `assets/data/`.
///
/// The library is offline by design: every month is a JSON asset, so the home
/// card works on the first launch with no network at all. A month that has not
/// been bundled yet falls back to month 01, and because month 01 covers days
/// 1-31 the card always has something to show. Adding month 02 later is just a
/// new asset file - `assets/data/` is already declared in pubspec.yaml.
class ScienceStoryService {
  ScienceStoryService._();

  static const String assetFolder = 'assets/data';

  /// The month that is always bundled and therefore always available.
  static const int fallbackMonth = 1;

  static final Map<int, ScienceStoryMonth> _cache = <int, ScienceStoryMonth>{};

  static String assetForMonth(int month) =>
      '$assetFolder/science_stories_month_${month.toString().padLeft(2, '0')}.json';

  /// Stories for [month], falling back to [fallbackMonth] when that month is
  /// not part of the build yet. Results are cached per requested month.
  static Future<ScienceStoryMonth> loadMonth(int month) async {
    final cached = _cache[month];
    if (cached != null) return cached;

    final requested = await _read(assetForMonth(month), month);
    if (!requested.isEmpty) {
      _cache[month] = requested;
      return requested;
    }
    if (month == fallbackMonth) {
      _cache[month] = ScienceStoryMonth.empty;
      return ScienceStoryMonth.empty;
    }

    final fallback = await _read(assetForMonth(fallbackMonth), fallbackMonth);
    final result = fallback.isEmpty
        ? ScienceStoryMonth.empty
        : ScienceStoryMonth(
            requestedMonth: month,
            month: fallback.month,
            collection: fallback.collection,
            language: fallback.language,
            stories: fallback.stories,
          );
    _cache[month] = result;
    return result;
  }

  /// The story for [date]. Falls back to a rotating pick when the month file
  /// has no entry for that exact day, so the card never renders empty.
  static Future<ScienceStoryPick?> pickForDate(DateTime date) async {
    final month = await loadMonth(date.month);
    final usable = month.stories.where((story) => story.isUsable).toList();
    if (usable.isEmpty) return null;

    ScienceStory? match;
    for (final story in usable) {
      if (story.day == date.day) {
        match = story;
        break;
      }
    }
    final chosen = match ?? usable[(date.day - 1) % usable.length];

    return ScienceStoryPick(
      story: chosen,
      month: month.month,
      usedFallback: month.usedFallback,
    );
  }

  static Future<ScienceStoryMonth> _read(String asset, int month) async {
    try {
      final raw = await rootBundle.loadString(asset);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        debugPrint('Science stories: $asset is not a JSON object');
        return ScienceStoryMonth.empty;
      }

      final topics = decoded['topics'];
      final stories = topics is List
          ? topics
              .whereType<Map>()
              .map((item) => ScienceStory.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ))
              .where((story) => story.isUsable)
              .toList()
          : <ScienceStory>[];

      return ScienceStoryMonth(
        requestedMonth: month,
        month: month,
        collection: (decoded['collection'] ?? '').toString().trim(),
        language: (decoded['language'] ?? '').toString().trim(),
        stories: stories,
      );
    } catch (error) {
      // Expected for a month that is not bundled yet; not an error state.
      debugPrint('Science stories: $asset unavailable ($error)');
      return ScienceStoryMonth.empty;
    }
  }
}
