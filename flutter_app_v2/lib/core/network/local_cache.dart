import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed JSON cache.
///
/// v1 scattered raw `prefs.setString('persistent_...', jsonEncode(x))` calls
/// (and matching decode logic with slightly different error handling) all over
/// the screens. All remote-config caching now uses these helpers, keeping the
/// **same preference keys** so existing installs keep their cached data.
class LocalCache {
  LocalCache._();

  /// Keys used by the app. Kept identical to v1 on purpose.
  static const String appConfig = 'persistent_app_config_json';
  static const String sectionalData = 'persistent_sectional_data_json';
  static const String subjectMapping = 'persistent_subject_mapping_json';
  static const String homeData = 'persistent_home_data_json';
  static const String biharEvents = 'cached_bihar_events_json';

  /// Legacy v1 alias that [HomeShellScreen] used to purge.
  static const String legacySubjectMapping = 'cached_subject_mapping_json';
  static const String legacySectionalData = 'cached_sectional_data_json';

  static Future<void> saveJson(String key, Object? value) async {
    if (value == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
    } catch (e) {
      debugPrint('LocalCache.saveJson($key) failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> readMap(String key) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('LocalCache.readMap($key) failed: $e');
    }
    return null;
  }

  static Future<List<dynamic>?> readList(String key) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (e) {
      debugPrint('LocalCache.readList($key) failed: $e');
    }
    return null;
  }

  static Future<void> remove(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Purges every cached remote config — used by the "Instant Force Update"
  /// action in the app bar.
  static Future<void> purgeRemoteConfig() async {
    for (final String key in <String>[
      legacySubjectMapping,
      legacySectionalData,
      subjectMapping,
      sectionalData,
      appConfig,
      homeData,
    ]) {
      await remove(key);
    }
  }
}
