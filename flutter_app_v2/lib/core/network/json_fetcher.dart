import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:mocktester_v2/core/config/app_endpoints.dart';

/// One resilient JSON loader for the whole app.
///
/// v1 had this logic copy-pasted in `home_screen`, `sectional_tab`,
/// `revision_tab`, `challenge_service`, `bpsc_rotation_service` and others —
/// each with slightly different mirror lists and error handling. Everything
/// now goes through [JsonFetcher].
///
/// Resolution order for a path:
///   1. `api.github.com/contents/...` (never edge-cached, freshest content)
///   2. raw.githack → jsDelivr (fastly) → statically → jsDelivr → raw.githubusercontent
class JsonFetcher {
  JsonFetcher._();

  static final JsonFetcher instance = JsonFetcher._();

  /// Strips any repository URL prefix and query string from a path, leaving a
  /// clean repo-relative path such as `static/history/ancient.json`.
  static String cleanPath(String path) {
    String clean = path.trim();
    for (final String prefix in AppEndpoints.knownPrefixes) {
      clean = clean.replaceAll(prefix, '');
    }
    if (clean.startsWith('/')) clean = clean.substring(1);
    if (clean.contains('?')) clean = clean.split('?').first;
    return clean;
  }

  /// Removes BOM, ```json fences and stray whitespace, then decodes.
  static dynamic _decode(String body) {
    String raw = body.trim();
    if (raw.startsWith('\uFEFF')) raw = raw.substring(1).trim();
    raw = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    if (raw.isEmpty ||
        raw.startsWith('<') ||
        raw.startsWith('<!DOCTYPE') ||
        raw.startsWith('404')) {
      return null;
    }
    return jsonDecode(raw);
  }

  static const Map<String, String> _rawApiHeaders = <String, String>{
    'Accept': 'application/vnd.github.v3.raw',
    'User-Agent': 'MockTesterApp-Flutter',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
  };

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Accept': 'application/json, text/plain, */*',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
  };

  /// Fetches JSON from [repo] (defaults to the content repository).
  ///
  /// Returns `null` when every mirror fails — callers then fall back to their
  /// local cache instead of showing an error screen.
  Future<dynamic> fetchRobust(
    String path, {
    String repo = AppEndpoints.contentRepo,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final String clean = cleanPath(path);
    if (clean.isEmpty) return null;
    final String encoded = Uri.encodeFull(clean);

    try {
      final http.Response apiRes = await http.get(
        Uri.parse(AppEndpoints.githubContentsApi(repo, encoded)),
        headers: _rawApiHeaders,
      ).timeout(timeout);

      if (apiRes.statusCode == 200) {
        final dynamic parsed = _decode(utf8.decode(apiRes.bodyBytes));
        if (parsed != null) return parsed;
      }
    } catch (e) {
      debugPrint('JsonFetcher api.github miss ($clean): $e');
    }

    for (final String url in AppEndpoints.mirrorUrls(repo, encoded)) {
      try {
        final http.Response res = await http
            .get(Uri.parse(url), headers: _jsonHeaders)
            .timeout(timeout);
        if (res.statusCode == 200) {
          final dynamic parsed = _decode(utf8.decode(res.bodyBytes));
          if (parsed != null) return parsed;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Fires the same request at every mirror in parallel and returns the first
  /// decoded payload. Useful for tiny config files where speed matters more
  /// than request count.
  Future<dynamic> fetchRacing(
    String path, {
    String repo = AppEndpoints.contentRepo,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final String clean = cleanPath(path);
    if (clean.isEmpty) return null;
    final String encoded = Uri.encodeFull(clean);
    final List<String> urls = <String>[
      AppEndpoints.githubContentsApi(repo, encoded),
      ...AppEndpoints.mirrorUrls(repo, encoded),
    ];

    final List<Future<dynamic>> attempts = urls.map((String url) async {
      final http.Response res = await http.get(Uri.parse(url)).timeout(timeout);
      if (res.statusCode != 200) return null;
      return _decode(utf8.decode(res.bodyBytes));
    }).toList();

    final List<dynamic> results = await Future.wait(attempts);
    for (final dynamic result in results) {
      if (result != null) return result;
    }
    return null;
  }

  /// Returns the **raw body** of the first mirror that answers, without
  /// decoding. Used by callers that must sanitise the text themselves
  /// (e.g. the learn-chat JSON, which occasionally arrives fenced).
  Future<String?> fetchRawText(
    String path, {
    String repo = AppEndpoints.contentRepo,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final String clean = cleanPath(path);
    if (clean.isEmpty) return null;
    final String encoded = Uri.encodeFull(clean);

    for (final String url in <String>[
      AppEndpoints.githubContentsApi(repo, encoded),
      ...AppEndpoints.mirrorUrls(repo, encoded),
    ]) {
      try {
        final http.Response res = await http
            .get(Uri.parse(url), headers: _jsonHeaders)
            .timeout(timeout);
        if (res.statusCode == 200) {
          final String body = utf8.decode(res.bodyBytes);
          if (body.trim().isNotEmpty) return body;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Fetches a JSON **list** and normalises the many shapes the remote files
  /// use (`[...]`, `{"questions": [...]}`, `{"data": [...]}`, `{"items": [...]}`).
  Future<List<dynamic>?> fetchList(
    String path, {
    String repo = AppEndpoints.contentRepo,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final dynamic data = await fetchRobust(path, repo: repo, timeout: timeout);
    return extractList(data);
  }

  /// Normalises a decoded payload into a list of maps.
  static List<dynamic>? extractList(dynamic data) {
    if (data == null) return null;
    if (data is List) return data;
    if (data is Map) {
      final dynamic raw = data['questions'] ?? data['data'] ?? data['items'];
      if (raw is List) return raw;
    }
    return null;
  }
}
