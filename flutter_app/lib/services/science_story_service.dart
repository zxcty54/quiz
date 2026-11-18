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
/// 1-31 the card always has something to show. Adding another month is just a
/// new asset file - `assets/data/` is already declared in pubspec.yaml.
///
/// Stories are numbered 1-365 straight through the year (month 02 starts at 32,
/// month 12 at 335). Each file's `coverage.start_day` is used to shift that
/// into a day of the month for display, while the original number is kept for
/// matching against the calendar - see [contentDayOfYear].
class ScienceStoryService {
  ScienceStoryService._();

  static const String assetFolder = 'assets/data';

  /// The month that is always bundled and therefore always available.
  static const int fallbackMonth = 1;

  /// The asset naming covers a full year, one file per month.
  static const int monthsInYear = 12;

  static final Map<int, ScienceStoryMonth> _cache = <int, ScienceStoryMonth>{};

  static List<int>? _bundledMonths;

  static String assetForMonth(int month) =>
      '$assetFolder/science_stories_month_${month.toString().padLeft(2, '0')}.json';

  /// Which months actually ship inside this build, probed once by reading each
  /// asset. A month that is not bundled comes back empty and is simply absent,
  /// so the UI never offers - or promises - a month the app does not have.
  static Future<List<int>> bundledMonths() async {
    final cached = _bundledMonths;
    if (cached != null) return cached;

    final found = <int>[];
    for (var month = 1; month <= monthsInYear; month++) {
      final probe = await _read(assetForMonth(month), month);
      if (!probe.isEmpty) found.add(month);
    }
    _bundledMonths = found;
    return found;
  }

  /// True while [month] has not started yet. The file may already be bundled,
  /// but the story stays locked so the daily card keeps its pull.
  static bool isLocked(int month, DateTime now) => month > now.month;

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

  /// The pack is a plain 365-day calendar, so a leap year has one day the
  /// content does not cover. 29 February repeats day 59 instead of opening
  /// 1 March early, and from 1 March the real day-of-year is shifted back by
  /// one to line up with the pack again.
  static int contentDayOfYear(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year)).inDays + 1;
    final leap =
        (date.year % 4 == 0 && date.year % 100 != 0) || date.year % 400 == 0;
    if (!leap || dayOfYear < 60) return dayOfYear;
    return dayOfYear == 60 ? 59 : dayOfYear - 1;
  }

  /// The story for [date]. Falls back to a rotating pick when the month file
  /// has no entry for that exact day, so the card never renders empty.
  static Future<ScienceStoryPick?> pickForDate(DateTime date) async {
    final month = await loadMonth(date.month);
    final usable = month.stories.where((story) => story.isUsable).toList();
    if (usable.isEmpty) return null;

    final int target = contentDayOfYear(date);
    ScienceStory? match;
    for (final story in usable) {
      if (story.yearDay == target) {
        match = story;
        break;
      }
    }
    final chosen = match ?? usable[(target - 1) % usable.length];

    return ScienceStoryPick(
      story: chosen,
      month: month.month,
      usedFallback: month.usedFallback,
    );
  }

  /// How far a month's numbering sits above the day of the month. Taken from
  /// `coverage.start_day` when that agrees with the actual day values, and from
  /// the lowest day otherwise, so a file with no coverage block still works.
  /// [decoded] stays `Object?` because `jsonDecode` promotes only to
  /// `Map<dynamic, dynamic>`, which is not assignable to a `Map<String, …>`
  /// parameter.
  static int _dayOffset(
    Object? decoded,
    List<Map<String, dynamic>> items,
  ) {
    final rawDays = items
        .map((item) => ScienceStory.rawDay(item['day']))
        .where((day) => day > 0)
        .toList();
    if (rawDays.isEmpty) return 0;

    final coverage = decoded is Map ? decoded['coverage'] : null;
    if (coverage is Map) {
      final start = coverage['start_day'];
      if (start is int && start > 1 && rawDays.every((day) => day >= start)) {
        return start - 1;
      }
    }
    var lowest = rawDays.first;
    for (final day in rawDays) {
      if (day < lowest) lowest = day;
    }
    return lowest > 1 ? lowest - 1 : 0;
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
      final items = topics is List
          ? topics
              .whereType<Map>()
              .map((item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)))
              .toList()
          : <Map<String, dynamic>>[];
      final dayOffset = _dayOffset(decoded, items);
      final stories = items
          .map((item) => ScienceStory.fromJson(item, dayOffset: dayOffset))
          .where((story) => story.isUsable)
          .toList();

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
