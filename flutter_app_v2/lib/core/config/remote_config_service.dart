import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:mocktester_v2/features/ai/data/ai_explainer_service.dart';
import 'package:mocktester_v2/core/network/json_fetcher.dart';
import 'package:mocktester_v2/core/network/local_cache.dart';

/// Everything the home shell needs to render, in one immutable bundle.
class RemoteConfigBundle {
  const RemoteConfigBundle({
    required this.appConfig,
    required this.homeData,
    required this.subjectMapping,
    required this.sectionalData,
  });

  final Map<String, dynamic> appConfig;
  final Map<String, dynamic> homeData;
  final Map<String, dynamic> subjectMapping;
  final Map<String, dynamic> sectionalData;
}

/// Loads, caches and refreshes the four remote JSON files that drive the app.
///
/// v1 spread this across `home_screen` (5 methods), `sectional_tab` and
/// `revision_tab`, each with its own mirror list, cache key and error handling.
class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  static const String appConfigFile = 'app_config.json';
  static const String homeDataFile = 'home_data.json';
  static const String sectionalDataFile = 'sectional_data.json';
  static const String subjectMappingFile = 'subject_mapping.json';

  Future<Map<String, dynamic>> _assetJson(String assetPath) async {
    try {
      final String raw = await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecodeCompat(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('RemoteConfigService: asset $assetPath failed: $e');
    }
    return <String, dynamic>{};
  }

  /// Cache-first load so the UI paints instantly on cold start; the bundled
  /// asset is only used when the device has no cache yet.
  Future<RemoteConfigBundle> loadLocal() async {
    Map<String, dynamic> appConfig =
        await LocalCache.readMap(LocalCache.appConfig) ??
            await _assetJson('assets/data/app_config.json');
    if (appConfig.isEmpty) {
      appConfig = await _assetJson('assets/data/app_config.json');
    }
    AiExplainerService.updateModelFromConfig(appConfig);

    final Map<String, dynamic> homeData =
        await LocalCache.readMap(LocalCache.homeData) ??
            await _assetJson('assets/data/home_data.json');

    final Map<String, dynamic> subjectMapping =
        await LocalCache.readMap(LocalCache.subjectMapping) ??
            await LocalCache.readMap(LocalCache.legacySubjectMapping) ??
            await _assetJson('assets/data/subject_mapping.json');

    final Map<String, dynamic> sectionalData =
        await LocalCache.readMap(LocalCache.sectionalData) ??
            await LocalCache.readMap(LocalCache.legacySectionalData) ??
            await _assetJson('assets/data/sectional_data.json');

    return RemoteConfigBundle(
      appConfig: appConfig,
      homeData: homeData,
      subjectMapping: subjectMapping,
      sectionalData: sectionalData,
    );
  }

  /// Fetches `app_config.json` (AI routing, banners, launch roadmap).
  Future<Map<String, dynamic>?> refreshAppConfig() async {
    final dynamic data = await JsonFetcher.instance.fetchRobust(appConfigFile);
    if (data is! Map) return null;
    final Map<String, dynamic> config = Map<String, dynamic>.from(data);
    AiExplainerService.updateModelFromConfig(config);
    await LocalCache.saveJson(LocalCache.appConfig, config);
    return config;
  }

  Future<Map<String, dynamic>?> refreshSectionalData() async {
    final dynamic data =
        await JsonFetcher.instance.fetchRobust(sectionalDataFile);
    if (data is! Map) return null;
    final Map<String, dynamic> map = Map<String, dynamic>.from(data);
    await LocalCache.saveJson(LocalCache.sectionalData, map);
    await LocalCache.saveJson(LocalCache.legacySectionalData, map);
    return map;
  }

  Future<Map<String, dynamic>?> refreshSubjectMapping() async {
    final dynamic data =
        await JsonFetcher.instance.fetchRobust(subjectMappingFile);
    if (data is! Map) return null;
    final Map<String, dynamic> map = Map<String, dynamic>.from(data);
    await LocalCache.saveJson(LocalCache.subjectMapping, map);
    await LocalCache.saveJson(LocalCache.legacySubjectMapping, map);
    return map;
  }

  /// Refreshes every config file in parallel — used on resume / pull-to-refresh.
  Future<void> refreshAll() async {
    await Future.wait<void>(<Future<void>>[
      refreshAppConfig().then((_) {}),
      refreshSectionalData().then((_) {}),
      refreshSubjectMapping().then((_) {}),
    ]);
  }

  /// Wipes the cache and re-downloads everything ("Instant Force Update").
  Future<void> purgeAndRefresh() async {
    await LocalCache.purgeRemoteConfig();
    await refreshAll();
  }
}

/// `jsonDecode` with a BOM / markdown-fence tolerant pre-pass.
/// Shared with [JsonFetcher] so every remote file is parsed the same way.
dynamic jsonDecodeCompat(String raw) {
  String body = raw.trim();
  if (body.startsWith('\uFEFF')) body = body.substring(1).trim();
  body = body.replaceAll('```json', '').replaceAll('```', '').trim();
  return jsonDecode(body);
}
