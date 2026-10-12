import 'package:mocktester_v2/core/config/app_endpoints.dart';

/// URL builders for the *content delivery* hosts.
///
/// v1 hardcoded the raw GitHub / jsDelivr / githack hosts inside ten different
/// widgets, so changing a mirror meant grepping the whole repo (and half of
/// those widgets quietly kept a stale host). Every host now lives here, which
/// is what lets `test/architecture_test.dart` assert that no feature file ever
/// introduces a new CDN without anyone noticing.
///
/// Widgets that already parse JSON with `JsonFetcher` do not need this class —
/// they pass a repo-relative path and the fetcher handles mirroring. Use these
/// builders only when a widget needs a concrete URL (custom headers, its own
/// failover order, cache-busting timestamp, …).
class ContentSources {
  ContentSources._();

  static const String _raw = 'https://raw.githubusercontent.com';
  static const String _jsdelivr = 'https://cdn.jsdelivr.net';
  static const String _fastly = 'https://fastly.jsdelivr.net';
  static const String _githack = 'https://raw.githack.com';

  /// `?t=<millis>` cache-buster, or an empty string when [ts] is null.
  static String _stamp(int? ts) => ts == null ? '' : '?t=$ts';

  // ------------------------------------------------------------- quiz repo ---
  /// jsDelivr base for this app's own repository (legacy question loader).
  static String get quizCdnBase =>
      '$_jsdelivr/gh/${AppEndpoints.quizRepo}@${AppEndpoints.branch}/';

  /// Raw file from the quiz repo, e.g. `current_affair/august_2026.json`.
  static String rawQuiz(String path, {int? ts}) =>
      '$_raw/${AppEndpoints.quizRepo}/${AppEndpoints.branch}/$path${_stamp(ts)}';

  // ---------------------------------------------------------- content repo ---
  /// Raw file from the content repo.
  static String rawContent(String path, {int? ts}) =>
      '$_raw/${AppEndpoints.contentRepo}/${AppEndpoints.branch}/$path${_stamp(ts)}';

  /// [rawContent] through the explicit `refs/heads/<branch>` form — the exact
  /// URL the Bihar-events widget has always shipped with.
  static String rawContentRefs(String path, {int? ts}) =>
      '$_raw/${AppEndpoints.contentRepo}/refs/heads/'
      '${AppEndpoints.branch}/$path${_stamp(ts)}';

  /// jsDelivr mirror of a content file; [fastly] selects the Fastly edge.
  static String contentCdn(String path, {int? ts, bool fastly = false}) {
    final String host = fastly ? _fastly : _jsdelivr;
    return '$host/gh/${AppEndpoints.contentRepo}@'
        '${AppEndpoints.branch}/$path${_stamp(ts)}';
  }

  /// githack mirror of a content file.
  static String contentGithack(String path, {int? ts}) =>
      '$_githack/${AppEndpoints.contentRepo}/${AppEndpoints.branch}/'
      '$path${_stamp(ts)}';
}
