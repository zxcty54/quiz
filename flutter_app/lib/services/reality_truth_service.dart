import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reality_truth_model.dart';

/// The bundled card index plus the full topics behind it.
///
/// Split by design. The card index (800 topics, curiosity fields only, ~230 KB
/// compressed) ships inside the app so the home widget and the hub work on a
/// first launch with no network at all. The full topic - decoded terms, deep
/// explanation, standards, home checks, myths, sources - is fetched from the
/// public `zxcty54/content_base` repository only when someone opens one, and
/// cached on the device.
///
/// This is the same delivery path the app already uses for `app_config.json`,
/// `subject_mapping.json` and `sectional_data.json`: the Cloudflare content
/// proxy first, then public CDN mirrors of the repository.
class RealityTruthService {
  RealityTruthService._();

  static const String cardsAsset = 'assets/data/reality_truth_cards.json';
  static const String contentRepo = 'zxcty54/content_base';
  static const String contentFolder = 'reality_truth';
  static const String contentProxyBase =
      'https://content-proxy.nitesh-skyhigh.workers.dev';
  static const String contentAppKey = 'mt_4bd7ba22c736af380d9d3905';

  /// A pillar file is roughly 800 KB, so it gets more room than the small
  /// config files the app fetches elsewhere.
  static const Duration fetchTimeout = Duration(seconds: 14);

  /// How long a downloaded pillar is trusted before it is fetched again.
  static const int cacheDays = 7;

  /// Fixed epoch for the daily rotation, so the pick changes once a day and
  /// walks through all 800 cards before repeating - over two years of content.
  static final DateTime _rotationEpoch = DateTime(2020);

  static RealityLibrary? _library;
  static final Map<String, RealityTopic> _topicCache = <String, RealityTopic>{};
  static final Map<String, List<Map<String, dynamic>>> _pillarCache =
      <String, List<Map<String, dynamic>>>{};

  /// The bundled card index. Cached for the life of the process.
  static Future<RealityLibrary> loadLibrary() async {
    final cached = _library;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(cardsAsset);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        debugPrint('Reality Truth: $cardsAsset is not a JSON object');
        _library = RealityLibrary.empty;
        return RealityLibrary.empty;
      }
      final library = RealityLibrary.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      _library = library;
      return library;
    } catch (error) {
      debugPrint('Reality Truth: could not read $cardsAsset ($error)');
      _library = RealityLibrary.empty;
      return RealityLibrary.empty;
    }
  }

  /// Today's card. Deterministic, so every device shows the same topic on the
  /// same day and the widget never renders empty while content exists.
  static Future<RealityCard?> pickForDate(DateTime date) async {
    final library = await loadLibrary();
    if (library.cards.isEmpty) return null;

    final cards = library.cards;
    var days = date.difference(_rotationEpoch).inDays;
    if (days < 0) days = 0;
    return cards[days % cards.length];
  }

  /// Mirrors tried in order, cheapest and most reliable first.
  static List<String> mirrorsFor(String fileName) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return <String>[
      '$contentProxyBase/$contentFolder/$fileName',
      'https://raw.githack.com/$contentRepo/main/$contentFolder/$fileName',
      'https://cdn.statically.io/gh/$contentRepo/main/$contentFolder/$fileName',
      'https://fastly.jsdelivr.net/gh/$contentRepo@main/$contentFolder/$fileName?t=$stamp',
      'https://cdn.jsdelivr.net/gh/$contentRepo@main/$contentFolder/$fileName?t=$stamp',
      'https://raw.githubusercontent.com/$contentRepo/refs/heads/main/$contentFolder/$fileName',
    ];
  }

  /// The full topic for a card, or null when it could not be reached. Callers
  /// fall back to the bundled card fields, so the screen is never blank.
  static Future<RealityTopic?> fetchTopic(
    RealityCard card,
    RealityPillar pillar,
  ) async {
    final hit = _topicCache[card.id];
    if (hit != null) return hit;
    if (!pillar.isRemote) return null;

    final items = await _pillarItems(pillar.fileName);
    for (final item in items) {
      if (item['id']?.toString() == card.id) {
        final topic = RealityTopic.fromJson(item);
        _topicCache[card.id] = topic;
        return topic;
      }
    }
    debugPrint('Reality Truth: ${card.id} not found in ${pillar.fileName}');
    return null;
  }

  /// Topics of one pillar file: memory cache, then the on-device cache, then
  /// the mirrors. A stale on-device copy still beats an empty screen.
  static Future<List<Map<String, dynamic>>> _pillarItems(
    String fileName,
  ) async {
    final memory = _pillarCache[fileName];
    if (memory != null) return memory;

    final cacheKey = 'reality_truth_pillar_$fileName';
    final stampKey = '${cacheKey}_at';
    String? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getString(cacheKey);
      final storedAt = prefs.getInt(stampKey) ?? 0;
      if (stored != null && storedAt > 0) {
        final age = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(storedAt))
            .inDays;
        if (age < cacheDays) {
          final cached = _decodeTopics(stored);
          if (cached != null) {
            _pillarCache[fileName] = cached;
            return cached;
          }
        }
      }
    } catch (error) {
      debugPrint('Reality Truth: cache read failed for $fileName ($error)');
    }

    for (final url in mirrorsFor(fileName)) {
      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers: <String, String>{
                'Cache-Control': 'no-cache',
                'X-App-Key': contentAppKey,
              },
            )
            .timeout(fetchTimeout);
        if (response.statusCode != 200) continue;

        final body = utf8
            .decode(response.bodyBytes)
            .trim()
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final items = _decodeTopics(body);
        if (items == null || items.isEmpty) continue;

        _pillarCache[fileName] = items;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, body);
          await prefs.setInt(
            stampKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (error) {
          debugPrint('Reality Truth: cache write failed ($error)');
        }
        return items;
      } catch (error) {
        debugPrint('Reality Truth: $url failed ($error)');
      }
    }

    // Every mirror failed: an out-of-date local copy is still useful.
    if (stored != null) {
      final stale = _decodeTopics(stored);
      if (stale != null && stale.isNotEmpty) {
        _pillarCache[fileName] = stale;
        return stale;
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// Pulls the `topics` array out of a pillar file. Returns null when the body
  /// is not the expected shape, so the caller moves on to the next mirror.
  static List<Map<String, dynamic>>? _decodeTopics(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final topics = decoded['topics'];
      if (topics is! List) return null;
      return topics
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    } catch (error) {
      debugPrint('Reality Truth: unparsable pillar body ($error)');
      return null;
    }
  }
}
